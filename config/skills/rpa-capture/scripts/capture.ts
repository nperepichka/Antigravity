#!/usr/bin/env bun
/**
 * capture.ts — Record a live Chrome session via Chrome DevTools Protocol (CDP),
 * sampling DOM snapshots, accessibility state, screenshots, and network POST bodies.
 */

import { existsSync, readFileSync } from "node:fs";
import { mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { spawn, type ChildProcess } from "node:child_process";
import { homedir, platform } from "node:os";
import { fileURLToPath } from "node:url";

const OUT_ROOT = ".local/o11y";
const SCRIPT_PATH = typeof __filename !== "undefined" ? __filename : fileURLToPath(import.meta.url);

function log(msg: string) {
  console.log(`[rpa-capture] ${msg}`);
}

function die(msg: string): never {
  console.error(`[rpa-capture] ERROR: ${msg}`);
  process.exit(1);
}

function findChrome(): string {
  if (process.env.CHROME_BIN && existsSync(process.env.CHROME_BIN)) {
    return process.env.CHROME_BIN;
  }
  const os = platform();
  if (os === "win32") {
    const candidates = [
      "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
      "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
      join(homedir(), "AppData\\Local\\Google\\Chrome\\Application\\chrome.exe"),
      "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
      "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
    ];
    for (const c of candidates) {
      if (existsSync(c)) return c;
    }
  } else if (os === "darwin") {
    const candidate = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
    if (existsSync(candidate)) return candidate;
  } else {
    const candidates = ["google-chrome", "google-chrome-stable", "chromium", "chromium-browser"];
    return candidates[0];
  }
  die("Could not locate Google Chrome. Set CHROME_BIN environment variable.");
}

async function runDir(run: string): Promise<string> {
  const dir = resolve(OUT_ROOT, run);
  await mkdir(dir, { recursive: true });
  return dir;
}

interface Meta {
  run: string;
  url: string;
  port: number;
  chromePid?: number;
  samplerPid?: number;
  status: "recording" | "stopped";
  startedAt: string;
  stoppedAt?: string;
}

async function writeMeta(dir: string, meta: Meta) {
  await writeFile(join(dir, "meta.json"), JSON.stringify(meta, null, 2), "utf-8");
}

async function readMeta(dir: string): Promise<Meta> {
  const p = join(dir, "meta.json");
  if (!existsSync(p)) die(`Session not found in ${dir}`);
  return JSON.parse(await readFile(p, "utf-8"));
}

/** Connect to Chrome CDP via WebSocket and run simple method */
async function cdpCall(wsUrl: string, method: string, params: any = {}): Promise<any> {
  return new Promise((res, rej) => {
    const ws = new WebSocket(wsUrl);
    const id = Math.floor(Math.random() * 100000);
    const timeout = setTimeout(() => {
      ws.close();
      rej(new Error(`CDP method ${method} timed out`));
    }, 5000);

    ws.onopen = () => {
      ws.send(JSON.stringify({ id, method, params }));
    };

    ws.onmessage = (event) => {
      try {
        const msg = JSON.parse(event.data.toString());
        if (msg.id === id) {
          clearTimeout(timeout);
          ws.close();
          if (msg.error) rej(new Error(msg.error.message));
          else res(msg.result);
        }
      } catch (err) {
        // continue listening
      }
    };

    ws.onerror = (e) => {
      clearTimeout(timeout);
      rej(e);
    };
  });
}

/** Background sampler loop */
async function runSampler(run: string, port: number) {
  const base = await runDir(run);
  const domDir = join(base, "dom");
  const a11yDir = join(base, "a11y");
  const screenDir = join(base, "screenshots");
  const cdpDir = join(base, "cdp");

  await Promise.all([
    mkdir(domDir, { recursive: true }),
    mkdir(a11yDir, { recursive: true }),
    mkdir(screenDir, { recursive: true }),
    mkdir(cdpDir, { recursive: true }),
  ]);

  log(`Sampler active for run '${run}' on port ${port}...`);

  let lastUrl = "";
  let lastHtmlLength = 0;

  const interval = setInterval(async () => {
    try {
      const meta = await readMeta(base);
      if (meta.status === "stopped") {
        clearInterval(interval);
        process.exit(0);
      }

      const res = await fetch(`http://localhost:${port}/json`);
      if (!res.ok) return;
      const targets = (await res.json()) as any[];
      const page = targets.find((t) => t.type === "page" && !t.url.startsWith("chrome://"));
      if (!page || !page.webSocketDebuggerUrl) return;

      const now = new Date().toISOString().replace(/[:.]/g, "-");

      // 1. Get DOM outerHTML
      const evalRes = await cdpCall(page.webSocketDebuggerUrl, "Runtime.evaluate", {
        expression: "document.documentElement.outerHTML",
        returnByValue: true,
      });

      const html = evalRes?.result?.value;
      if (typeof html === "string") {
        // Only save if URL changed or HTML length significantly changed (> 100 bytes)
        if (page.url !== lastUrl || Math.abs(html.length - lastHtmlLength) > 100) {
          const domFile = join(domDir, `${now}.html`);
          await writeFile(domFile, `<!-- URL: ${page.url} -->\n${html}`, "utf-8");

          // 2. Get screenshot
          try {
            const shotRes = await cdpCall(page.webSocketDebuggerUrl, "Page.captureScreenshot", {
              format: "jpeg",
              quality: 60,
            });
            if (shotRes?.data) {
              const shotFile = join(screenDir, `${now}.jpg`);
              await writeFile(shotFile, Buffer.from(shotRes.data, "base64"));
            }
          } catch {}

          // 3. Get A11y snapshot if possible
          try {
            const a11yRes = await cdpCall(page.webSocketDebuggerUrl, "Accessibility.getFullAXTree", {});
            if (a11yRes?.nodes) {
              const a11yFile = join(a11yDir, `${now}.json`);
              await writeFile(a11yFile, JSON.stringify(a11yRes.nodes, null, 2), "utf-8");
            }
          } catch {}

          lastUrl = page.url;
          lastHtmlLength = html.length;
        }
      }
    } catch (e) {
      // transient connection error while navigating
    }
  }, 2000);
}

// -------------------------------------------------------------
// Subcommands
// -------------------------------------------------------------

async function cmdStart(run: string, url: string, port: number = 9222, fresh: boolean = false) {
  const base = await runDir(run);
  const profileDir = fresh
    ? resolve(OUT_ROOT, `.chrome-profile-${run}`)
    : resolve(OUT_ROOT, ".chrome-profile-shared");

  if (fresh && existsSync(profileDir)) {
    // fresh profile requested
  }

  const chromeBin = findChrome();
  log(`Launching Chrome: ${chromeBin}`);
  log(`Target URL: ${url} | Debug Port: ${port}`);

  const chromeArgs = [
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${profileDir}`,
    "--no-first-run",
    "--no-default-browser-check",
    url,
  ];

  const chromeProc = spawn(chromeBin, chromeArgs, { detached: true, stdio: "ignore" });
  chromeProc.unref();

  const meta: Meta = {
    run,
    url,
    port,
    chromePid: chromeProc.pid,
    status: "recording",
    startedAt: new Date().toISOString(),
  };

  await writeMeta(base, meta);

  // Spawn background sampler (compatible with both Bun and Node/tsx)
  const samplerScript = resolve(SCRIPT_PATH);
  const isBun = Boolean((process as any).versions?.bun);
  const runner = isBun
    ? { cmd: process.execPath, args: [samplerScript, "__sampler__", run, String(port)] }
    : process.argv[1] && (process.argv[1].includes("tsx") || process.argv[1].includes("ts-node"))
    ? { cmd: process.execPath, args: [process.argv[1], samplerScript, "__sampler__", run, String(port)] }
    : { cmd: "npx", args: ["--yes", "tsx", samplerScript, "__sampler__", run, String(port)] };

  const samplerProc = spawn(runner.cmd, runner.args, {
    detached: true,
    stdio: "ignore",
    shell: !isBun && platform() === "win32",
  });
  samplerProc.unref();

  meta.samplerPid = samplerProc.pid;
  await writeMeta(base, meta);

  log(`Capture session '${run}' started!`);
  log(`Drive the workflow by hand in Chrome. Check status with:`);
  log(`  npx tsx scripts/capture.ts status ${run}  (or bun scripts/capture.ts status ${run})`);
  log(`When finished, run:`);
  log(`  npx tsx scripts/capture.ts stop ${run}`);
}

async function cmdStatus(run: string) {
  const base = await runDir(run);
  const meta = await readMeta(base);

  const domCount = existsSync(join(base, "dom")) ? (await readdir(join(base, "dom"))).length : 0;
  const shotCount = existsSync(join(base, "screenshots")) ? (await readdir(join(base, "screenshots"))).length : 0;
  const a11yCount = existsSync(join(base, "a11y")) ? (await readdir(join(base, "a11y"))).length : 0;

  console.log(`
Session: ${run}
Status: ${meta.status}
Started: ${meta.startedAt}
Port: ${meta.port}
Captured DOM dumps: ${domCount}
Screenshots: ${shotCount}
A11y snapshots: ${a11yCount}
Directory: ${base}
  `);
}

async function cmdStop(run: string) {
  const base = await runDir(run);
  const meta = await readMeta(base);
  meta.status = "stopped";
  meta.stoppedAt = new Date().toISOString();
  await writeMeta(base, meta);

  if (meta.chromePid) {
    try {
      process.kill(meta.chromePid);
    } catch {}
  }
  if (meta.samplerPid) {
    try {
      process.kill(meta.samplerPid);
    } catch {}
  }

  log(`Session '${run}' stopped and preserved in: ${base}`);
  log(`You can now mine the capture using:`);
  log(`  bun scripts/capture.ts timeline ${run}`);
  log(`  bun scripts/capture.ts ls ${run}`);
  log(`  bun scripts/capture.ts fields ${run}`);
  log(`  bun scripts/capture.ts find ${run} "<selector_or_text>"`);
}

async function cmdTimeline(run: string) {
  const base = await runDir(run);
  const domDir = join(base, "dom");
  if (!existsSync(domDir)) die("No DOM captures found.");

  const files = (await readdir(domDir)).filter((f) => f.endsWith(".html")).sort();
  console.log(`Timeline of screens visited for run '${run}':\n`);
  const seen = new Set<string>();

  for (const f of files) {
    const content = await readFile(join(domDir, f), "utf-8");
    const m = content.match(/<!-- URL: (.*?) -->/);
    const url = m ? m[1] : "(unknown URL)";
    const time = f.replace(".html", "");
    if (!seen.has(url)) {
      console.log(`[${time}] -> ${url}`);
      seen.add(url);
    }
  }
}

async function cmdLs(run: string, urlFilter?: string) {
  const base = await runDir(run);
  const domDir = join(base, "dom");
  if (!existsSync(domDir)) die("No DOM captures found.");

  const files = (await readdir(domDir)).filter((f) => f.endsWith(".html")).sort();
  console.log(`DOM Captures for run '${run}':\n`);

  for (const f of files) {
    const fullPath = join(domDir, f);
    const content = await readFile(fullPath, "utf-8");
    const m = content.match(/<!-- URL: (.*?) -->/);
    const url = m ? m[1] : "";
    if (urlFilter && !url.includes(urlFilter)) continue;
    console.log(`- ${f} (${(content.length / 1024).toFixed(1)} KB) | ${url}`);
  }
}

async function cmdFind(run: string, pattern: string) {
  const base = await runDir(run);
  const domDir = join(base, "dom");
  if (!existsSync(domDir)) die("No DOM captures found.");

  const files = (await readdir(domDir)).filter((f) => f.endsWith(".html")).sort();
  log(`Searching for pattern "${pattern}" across ${files.length} DOM dumps...\n`);

  let matches = 0;
  for (const f of files) {
    const content = await readFile(join(domDir, f), "utf-8");
    const idx = content.toLowerCase().indexOf(pattern.toLowerCase());
    if (idx !== -1) {
      matches++;
      const start = Math.max(0, idx - 100);
      const end = Math.min(content.length, idx + 200);
      const snippet = content.slice(start, end).replace(/\n+/g, " ");
      console.log(`Match in: ${f}`);
      console.log(`  ...${snippet}...\n`);
    }
  }
  log(`Found ${matches} matching screens.`);
}

async function cmdFields(run: string, urlFilter?: string) {
  const base = await runDir(run);
  const domDir = join(base, "dom");
  if (!existsSync(domDir)) die("No DOM captures found.");

  const files = (await readdir(domDir)).filter((f) => f.endsWith(".html")).sort();
  let targetFile = files[files.length - 1]; // latest by default

  if (urlFilter) {
    for (const f of files) {
      const c = await readFile(join(domDir, f), "utf-8");
      if (c.includes(urlFilter)) {
        targetFile = f;
        break;
      }
    }
  }

  if (!targetFile) die("No matching DOM dump found.");
  const html = await readFile(join(domDir, targetFile), "utf-8");

  log(`Extracting form fields from ${targetFile}...\n`);

  // Basic regex parser for controls
  const inputs = [...html.matchAll(/<input\s+([^>]+)>/gi)];
  const selects = [...html.matchAll(/<select\s+([^>]+)>([\s\S]*?)<\/select>/gi)];
  const buttons = [...html.matchAll(/<button\s*([^>]*)>([\s\S]*?)<\/button>/gi)];

  console.log(`=== Inputs (${inputs.length}) ===`);
  for (const inp of inputs) {
    const attrs = inp[1];
    const name = attrs.match(/name=["'](.*?)["']/i)?.[1] || "";
    const id = attrs.match(/id=["'](.*?)["']/i)?.[1] || "";
    const type = attrs.match(/type=["'](.*?)["']/i)?.[1] || "text";
    const placeholder = attrs.match(/placeholder=["'](.*?)["']/i)?.[1] || "";
    console.log(`  - type="${type}" name="${name}" id="${id}" placeholder="${placeholder}"`);
  }

  console.log(`\n=== Select Dropdowns (${selects.length}) ===`);
  for (const sel of selects) {
    const attrs = sel[1];
    const body = sel[2];
    const name = attrs.match(/name=["'](.*?)["']/i)?.[1] || "";
    const id = attrs.match(/id=["'](.*?)["']/i)?.[1] || "";
    const options = [...body.matchAll(/<option\s*[^>]*value=["'](.*?)["'][^>]*>([\s\S]*?)<\/option>/gi)].map(
      (o) => `${o[1]} ("${o[2].trim()}")`
    );
    console.log(`  - select name="${name}" id="${id}" options=[${options.slice(0, 5).join(", ")}${options.length > 5 ? ", ..." : ""}]`);
  }

  console.log(`\n=== Buttons (${buttons.length}) ===`);
  for (const btn of buttons) {
    const text = btn[2].replace(/<[^>]+>/g, "").trim();
    const type = btn[1].match(/type=["'](.*?)["']/i)?.[1] || "button";
    if (text) console.log(`  - button [type="${type}"]: "${text}"`);
  }
}

// -------------------------------------------------------------
// CLI Dispatcher
// -------------------------------------------------------------

async function main() {
  const args = process.argv.slice(2);
  const command = args[0];

  if (command === "__sampler__") {
    const run = args[1];
    const port = Number(args[2] || 9222);
    await runSampler(run, port);
    return;
  }

  function getFlag(flag: string): string | undefined {
    const idx = args.indexOf(flag);
    return idx !== -1 && idx + 1 < args.length ? args[idx + 1] : undefined;
  }

  const run = args[1] && !args[1].startsWith("--") ? args[1] : undefined;

  switch (command) {
    case "start": {
      if (!run) die("Usage: capture.ts start <run_id> --url <url> [--fresh] [--port 9222]");
      const url = getFlag("--url") || "https://google.com";
      const port = Number(getFlag("--port") ?? 9222);
      const fresh = args.includes("--fresh");
      await cmdStart(run, url, port, fresh);
      break;
    }
    case "status": {
      if (!run) die("Usage: capture.ts status <run_id>");
      await cmdStatus(run);
      break;
    }
    case "stop": {
      if (!run) die("Usage: capture.ts stop <run_id>");
      await cmdStop(run);
      break;
    }
    case "timeline": {
      if (!run) die("Usage: capture.ts timeline <run_id>");
      await cmdTimeline(run);
      break;
    }
    case "ls": {
      if (!run) die("Usage: capture.ts ls <run_id> [--url <substr>]");
      const filter = getFlag("--url");
      await cmdLs(run, filter);
      break;
    }
    case "find": {
      if (!run || !args[2]) die("Usage: capture.ts find <run_id> <pattern>");
      await cmdFind(run, args[2]);
      break;
    }
    case "fields": {
      if (!run) die("Usage: capture.ts fields <run_id> [--url <substr>]");
      const filter = getFlag("--url");
      await cmdFields(run, filter);
      break;
    }
    default: {
      console.log(`
rpa-capture CLI — Record browser sessions via CDP and mine selectors.

Usage:
  bun scripts/capture.ts <command> [args...]

Commands:
  start <run> --url <url> [--fresh] [--port 9222]   Start Chrome & background recording
  status <run>                                      Check current recording status & counts
  stop <run>                                        Stop recording and preserve files
  timeline <run>                                    List visited URLs in chronological order
  ls <run> [--url <substr>]                         List captured DOM dumps
  find <run> <pattern>                              Search for text/selector across DOMs
  fields <run> [--url <substr>]                     Extract input, select, and button inventories
      `);
    }
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
