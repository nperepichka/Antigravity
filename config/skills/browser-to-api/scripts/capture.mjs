#!/usr/bin/env node
/**
 * capture.mjs — 100% Local Chrome/Edge CDP Network Recorder.
 * 
 * Launches local Chrome or Edge with a remote debugging port, connects via CDP,
 * records all HTTP/HTTPS requests & responses, downloads response bodies in real-time,
 * and writes to .local/o11y/<run-id>/cdp/network/.
 * 
 * Requires: Node.js 18+ (Node 22+ native WebSocket) and Chrome or Edge installed.
 * No Browserbase, no external cloud, no API keys needed.
 */

import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { homedir, platform } from 'node:os';
import { ensureDir } from './lib/io.mjs';

const OUT_ROOT = path.resolve('.local', 'o11y');

function findBrowserBinary() {
  if (process.env.CHROME_BIN && fs.existsSync(process.env.CHROME_BIN)) {
    return process.env.CHROME_BIN;
  }
  const os = platform();
  if (os === 'win32') {
    const candidates = [
      'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
      'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
      path.join(homedir(), 'AppData\\Local\\Google\\Chrome\\Application\\chrome.exe'),
      'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
      'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
    ];
    for (const c of candidates) {
      if (fs.existsSync(c)) return c;
    }
  } else if (os === 'darwin') {
    const candidates = [
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
    ];
    for (const c of candidates) {
      if (fs.existsSync(c)) return c;
    }
  } else {
    const candidates = ['google-chrome', 'google-chrome-stable', 'chromium', 'chromium-browser', 'microsoft-edge'];
    return candidates[0];
  }
  throw new Error('Could not locate Google Chrome or Microsoft Edge. Set CHROME_BIN environment variable.');
}

async function getWsUrl(port, retries = 20) {
  for (let i = 0; i < retries; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${port}/json/list`);
      if (res.ok) {
        const pages = await res.json();
        const page = pages.find(p => p.type === 'page' && p.webSocketDebuggerUrl) || pages[0];
        if (page?.webSocketDebuggerUrl) return page.webSocketDebuggerUrl;
      }
    } catch {
      // Chrome starting up...
    }
    await new Promise(r => setTimeout(r, 500));
  }
  throw new Error(`Failed to connect to browser on port ${port}`);
}

async function startRecorder(runId, url, port = 9222, headless = false) {
  const runDir = path.join(OUT_ROOT, runId);
  const cdpDir = path.join(runDir, 'cdp', 'network');
  const bodiesDir = path.join(cdpDir, 'bodies');
  ensureDir(bodiesDir);

  const metaPath = path.join(runDir, 'meta.json');
  if (fs.existsSync(metaPath)) {
    const prev = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
    if (prev.status === 'recording') {
      console.log(`Run '${runId}' is already recording.`);
      return;
    }
  }

  const browserBin = findBrowserBinary();
  const profileDir = path.join(runDir, 'browser-profile');
  ensureDir(profileDir);

  console.log(`[capture] Launching browser: ${browserBin}`);
  console.log(`[capture] URL: ${url}`);
  console.log(`[capture] Debug port: ${port}`);
  console.log(`[capture] Run directory: ${runDir}`);

  const chromeArgs = [
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${profileDir}`,
    '--no-first-run',
    '--no-default-browser-check',
  ];
  if (headless) chromeArgs.push('--headless=new');
  chromeArgs.push(url);

  const browserProc = spawn(browserBin, chromeArgs, {
    detached: true,
    stdio: 'ignore',
  });
  browserProc.unref();

  const wsUrl = await getWsUrl(port);
  console.log(`[capture] Connected to CDP: ${wsUrl}`);

  // Create background daemon recorder process
  const daemonScript = path.join(runDir, '_daemon.mjs');
  const daemonCode = `
import fs from 'node:fs';
import path from 'node:path';

const cdpDir = ${JSON.stringify(cdpDir)};
const bodiesDir = ${JSON.stringify(bodiesDir)};
const wsUrl = ${JSON.stringify(wsUrl)};

const reqStream = fs.createWriteStream(path.join(cdpDir, 'requests.jsonl'), { flags: 'a' });
const respStream = fs.createWriteStream(path.join(cdpDir, 'responses.jsonl'), { flags: 'a' });

const ws = new WebSocket(wsUrl);
let idCounter = 1;
const pendingBodyRequests = new Map();

ws.onopen = () => {
  ws.send(JSON.stringify({ id: idCounter++, method: 'Network.enable', params: { maxTotalBufferSize: 20000000, maxResourceBufferSize: 10000000 } }));
  ws.send(JSON.stringify({ id: idCounter++, method: 'Page.enable' }));
};

ws.onmessage = (event) => {
  try {
    const msg = JSON.parse(event.data);
    if (msg.method === 'Network.requestWillBeSent') {
      reqStream.write(JSON.stringify({ method: msg.method, params: msg.params, ts: Date.now() }) + '\\n');
      const reqId = msg.params.requestId;
      const postData = msg.params.request?.postData;
      if (postData) {
        const bodySub = path.join(bodiesDir, String(reqId));
        fs.mkdirSync(bodySub, { recursive: true });
        fs.writeFileSync(path.join(bodySub, 'request.json'), JSON.stringify({ id: reqId, body: postData }), 'utf8');
      }
    } else if (msg.method === 'Network.responseReceived') {
      respStream.write(JSON.stringify({ method: msg.method, params: msg.params, ts: Date.now() }) + '\\n');
    } else if (msg.method === 'Network.loadingFinished') {
      const reqId = msg.params.requestId;
      const callId = idCounter++;
      pendingBodyRequests.set(callId, reqId);
      ws.send(JSON.stringify({ id: callId, method: 'Network.getResponseBody', params: { requestId: reqId } }));
    } else if (msg.id && pendingBodyRequests.has(msg.id)) {
      const reqId = pendingBodyRequests.get(msg.id);
      pendingBodyRequests.delete(msg.id);
      if (msg.result?.body) {
        const bodySub = path.join(bodiesDir, String(reqId));
        fs.mkdirSync(bodySub, { recursive: true });
        let bodyText = msg.result.body;
        if (msg.result.base64Encoded) {
          try { bodyText = Buffer.from(bodyText, 'base64').toString('utf8'); } catch {}
        }
        fs.writeFileSync(path.join(bodySub, 'response.json'), JSON.stringify({ id: reqId, body: bodyText }), 'utf8');
      }
    }
  } catch (err) {}
};
`;
  fs.writeFileSync(daemonScript, daemonCode, 'utf8');

  const daemonProc = spawn(process.execPath, [daemonScript], {
    detached: true,
    stdio: 'ignore',
  });
  daemonProc.unref();

  const meta = {
    run: runId,
    url,
    port,
    chromePid: browserProc.pid,
    daemonPid: daemonProc.pid,
    status: 'recording',
    startedAt: new Date().toISOString(),
  };
  fs.writeFileSync(metaPath, JSON.stringify(meta, null, 2), 'utf8');

  console.log(`\n✓ Recording started for run: '${runId}'`);
  console.log(`Drive your application in the opened Chrome window.`);
  console.log(`When finished, stop capture and generate the API spec with:`);
  console.log(`  node scripts/capture.mjs stop ${runId}`);
  console.log(`  node scripts/discover.mjs --run ${runId}\n`);
}

function stopRecorder(runId) {
  const runDir = path.join(OUT_ROOT, runId);
  const metaPath = path.join(runDir, 'meta.json');
  if (!fs.existsSync(metaPath)) {
    console.error(`Error: No run metadata found for '${runId}' at ${metaPath}`);
    process.exit(1);
  }

  const meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
  if (meta.daemonPid) {
    try { process.kill(meta.daemonPid); } catch { /* ignore */ }
  }
  if (meta.chromePid) {
    try { process.kill(meta.chromePid); } catch { /* ignore */ }
  }

  meta.status = 'stopped';
  meta.stoppedAt = new Date().toISOString();
  fs.writeFileSync(metaPath, JSON.stringify(meta, null, 2), 'utf8');

  console.log(`✓ Recording stopped for run: '${runId}'`);
  console.log(`To generate OpenAPI spec now, run:`);
  console.log(`  node scripts/discover.mjs --run ${runId}`);
}

function statusRecorder(runId) {
  const runDir = path.join(OUT_ROOT, runId);
  const metaPath = path.join(runDir, 'meta.json');
  if (!fs.existsSync(metaPath)) {
    console.log(`Run '${runId}' not found.`);
    return;
  }
  const meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
  const reqFile = path.join(runDir, 'cdp', 'network', 'requests.jsonl');
  const respFile = path.join(runDir, 'cdp', 'network', 'responses.jsonl');
  const reqCount = fs.existsSync(reqFile) ? fs.readFileSync(reqFile, 'utf8').split('\n').filter(Boolean).length : 0;
  const respCount = fs.existsSync(respFile) ? fs.readFileSync(respFile, 'utf8').split('\n').filter(Boolean).length : 0;

  console.log(`Run: ${meta.run}`);
  console.log(`Status: ${meta.status}`);
  console.log(`Started: ${meta.startedAt}`);
  console.log(`Requests captured: ${reqCount}`);
  console.log(`Responses captured: ${respCount}`);
}

function main() {
  const args = process.argv.slice(2);
  const command = args[0];

  if (!command || command === '-h' || command === '--help') {
    console.log(`capture.mjs — Local Chrome/Edge CDP Traffic Recorder

Commands:
  start <run-id> --url <url> [--port 9222] [--headless]
  stop  <run-id>
  status <run-id>

Examples:
  node scripts/capture.mjs start my-session --url https://app.example.com
  node scripts/capture.mjs status my-session
  node scripts/capture.mjs stop my-session
  node scripts/discover.mjs --run my-session
`);
    process.exit(0);
  }

  const runId = args[1];
  if (!runId) {
    console.error('Error: missing <run-id>');
    process.exit(1);
  }

  if (command === 'start') {
    let url = 'about:blank';
    let port = 9222;
    let headless = false;
    for (let i = 2; i < args.length; i++) {
      if (args[i] === '--url' && args[i + 1]) url = args[++i];
      if (args[i] === '--port' && args[i + 1]) port = parseInt(args[++i], 10);
      if (args[i] === '--headless') headless = true;
    }
    startRecorder(runId, url, port, headless).catch(err => {
      console.error('[capture] Error:', err.message);
      process.exit(1);
    });
  } else if (command === 'stop') {
    stopRecorder(runId);
  } else if (command === 'status') {
    statusRecorder(runId);
  } else {
    console.error(`Unknown command: ${command}`);
    process.exit(1);
  }
}

main();
