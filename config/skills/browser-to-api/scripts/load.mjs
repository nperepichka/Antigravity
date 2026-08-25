#!/usr/bin/env node
// Stage 1 — Load.
//
// Read browser trace (CDP JSONL or .HAR file), pair requests and responses,
// drop preflight (OPTIONS) + pure redirects + obvious non-API resource types,
// and write `intermediate/paired.jsonl`.
//
// Supports:
// 1. Local/captured CDP directories (<run>/cdp/network/{requests,responses}.jsonl)
// 2. Direct .HAR files (Chrome, Edge, Firefox, Playwright network logs)

import fs from 'node:fs';
import path from 'node:path';
import { readJsonl, writeJsonl, intermediatePath, ensureDir } from './lib/io.mjs';

const KEEP_TYPES = new Set(['XHR', 'Fetch', 'Document']);

function tryParseJson(s) {
  if (typeof s !== 'string') return s;
  try { return JSON.parse(s); } catch { return s; }
}

function looksApiUrl(url) {
  return /\/(api|graphql|rest|v\d+)\b/i.test(url) ||
         /\.(json|jsonl|ndjson)(\?|$)/i.test(url);
}

function urlPath(u) {
  try { return new URL(u).pathname; } catch { return u; }
}

function urlOrigin(u) {
  try { const x = new URL(u); return `${x.protocol}//${x.host}`; } catch { return null; }
}

function urlQuery(u) {
  try {
    const x = new URL(u);
    const out = {};
    for (const [k, v] of x.searchParams.entries()) {
      if (out[k] === undefined) out[k] = v;
    }
    return out;
  } catch { return {}; }
}

function headersArrayToObject(arr) {
  if (!Array.isArray(arr)) return arr || {};
  const out = {};
  for (const h of arr) {
    if (h && h.name) out[h.name.toLowerCase()] = h.value;
  }
  return out;
}

// Walk a bodies directory and return a Map keyed by the requestId.
function loadBodiesDir(bodiesDir) {
  const out = new Map();
  if (!bodiesDir || !fs.existsSync(bodiesDir)) return out;
  const entries = fs.readdirSync(bodiesDir, { withFileTypes: true });
  for (const e of entries) {
    if (!e.isDirectory()) continue;
    const subdir = path.join(bodiesDir, e.name);
    const reqPath = path.join(subdir, 'request.json');
    const respPath = path.join(subdir, 'response.json');
    if (!fs.existsSync(reqPath) && !fs.existsSync(respPath)) continue;
    let req = null, resp = null;
    try { if (fs.existsSync(reqPath)) req = JSON.parse(fs.readFileSync(reqPath, 'utf8')); } catch { /* ignore */ }
    try { if (fs.existsSync(respPath)) resp = JSON.parse(fs.readFileSync(respPath, 'utf8')); } catch { /* ignore */ }
    const id = req?.id || e.name;
    const reqBody = req?.body != null ? tryParseJson(req.body) : null;
    const respBody = resp?.body != null ? tryParseJson(resp.body) : null;
    out.set(String(id), { reqBody, respBody });
  }
  return out;
}

// Load from a standard .HAR file
export function loadHar(harPath, outDir) {
  const raw = fs.readFileSync(harPath, 'utf8');
  const data = JSON.parse(raw);
  const entries = data.log?.entries || [];

  const paired = [];
  let counter = 0;

  for (const entry of entries) {
    const req = entry.request;
    const resp = entry.response;
    if (!req || !req.url) continue;

    const method = req.method?.toUpperCase();
    const url = req.url;
    if (method === 'OPTIONS') continue;
    if (url.startsWith('data:') || url.startsWith('blob:')) continue;

    const mimeType = resp?.content?.mimeType || '';
    const resourceType = entry._resourceType ? (entry._resourceType.toUpperCase() === 'XHR' || entry._resourceType.toUpperCase() === 'FETCH' ? 'Fetch' : entry._resourceType) : (mimeType.includes('json') ? 'Fetch' : 'Other');

    if (!KEEP_TYPES.has(resourceType) && !looksApiUrl(url) && !mimeType.includes('json')) {
      continue;
    }

    const status = resp?.status ?? null;
    if (status && status >= 300 && status < 400) continue;

    const reqHeaders = headersArrayToObject(req.headers);
    const respHeaders = headersArrayToObject(resp?.headers);

    let reqBody = null;
    if (req.postData?.text) {
      reqBody = tryParseJson(req.postData.text);
    }

    let respBody = null;
    if (resp?.content?.text) {
      let text = resp.content.text;
      if (resp.content.encoding === 'base64') {
        try {
          text = Buffer.from(text, 'base64').toString('utf8');
        } catch { /* keep raw */ }
      }
      respBody = tryParseJson(text);
    }

    const contentType = respHeaders['content-type'] || mimeType || null;
    const ts = entry.startedDateTime ? Date.parse(entry.startedDateTime) : Date.now();

    paired.push({
      requestId: `har-${++counter}`,
      method,
      url,
      origin: urlOrigin(url),
      path: urlPath(url),
      query: urlQuery(url),
      status,
      type: resourceType,
      contentType,
      reqHeaders,
      reqBody,
      respHeaders,
      respBody,
      ts,
    });
  }

  ensureDir(path.join(outDir, 'intermediate'));
  writeJsonl(intermediatePath(outDir, 'paired.jsonl'), paired);
  return {
    source: 'har',
    count: paired.length,
    harEntries: entries.length,
    bodiesAttached: paired.filter(r => r.respBody != null).length,
  };
}

export function load(runPath, outDir, opts = {}) {
  // If runPath is directly a .har file or JSON file containing log.entries
  if (fs.existsSync(runPath) && fs.statSync(runPath).isFile()) {
    if (runPath.endsWith('.har') || runPath.endsWith('.json')) {
      return loadHar(runPath, outDir);
    }
  }

  const cdpDir = path.join(runPath, 'cdp', 'network');
  const requestsPath = path.join(cdpDir, 'requests.jsonl');
  const responsesPath = path.join(cdpDir, 'responses.jsonl');

  // If no CDP files, check if a har file exists in runPath
  if (!fs.existsSync(requestsPath)) {
    const harFile = path.join(runPath, 'traffic.har');
    if (fs.existsSync(harFile)) {
      return loadHar(harFile, outDir);
    }
    // Also check any .har in runPath
    const files = fs.readdirSync(runPath).filter(f => f.endsWith('.har'));
    if (files.length > 0) {
      return loadHar(path.join(runPath, files[0]), outDir);
    }
  }

  const requests  = readJsonl(requestsPath);
  const responses = readJsonl(responsesPath);

  let bodiesDir = opts.bodies || null;
  if (!bodiesDir) {
    const stashed = path.join(runPath, 'cdp', 'network', 'bodies');
    if (fs.existsSync(stashed)) bodiesDir = stashed;
    const directBodies = path.join(runPath, 'bodies');
    if (fs.existsSync(directBodies)) bodiesDir = directBodies;
  }
  const bodyMap = loadBodiesDir(bodiesDir);

  const respByReq = new Map();
  for (const ev of responses) {
    const rid = ev?.params?.requestId;
    if (rid) respByReq.set(rid, ev);
  }

  const paired = [];
  for (const ev of requests) {
    const p = ev?.params;
    if (!p?.request) continue;

    const method = p.request.method;
    const url = p.request.url;
    if (!url || !method) continue;
    if (method === 'OPTIONS') continue;
    if (url.startsWith('data:') || url.startsWith('blob:')) continue;

    const type = p.type || 'Other';
    if (!KEEP_TYPES.has(type) && !looksApiUrl(url)) continue;

    const respEv = respByReq.get(p.requestId);
    const resp = respEv?.params?.response;
    const status = resp?.status ?? null;
    if (status && status >= 300 && status < 400) {
      continue;
    }

    const contentType = resp?.headers
      ? Object.entries(resp.headers).find(([k]) => k.toLowerCase() === 'content-type')?.[1] ?? null
      : null;

    let reqBody = p.request.postData ? tryParseJson(p.request.postData) : null;
    let respBody = null;

    const captured = bodyMap.get(String(p.requestId));
    if (captured) {
      if (reqBody == null && captured.reqBody != null) reqBody = captured.reqBody;
      if (captured.respBody != null) respBody = captured.respBody;
    }

    paired.push({
      requestId: p.requestId,
      method,
      url,
      origin: urlOrigin(url),
      path: urlPath(url),
      query: urlQuery(url),
      status,
      type,
      contentType,
      reqHeaders: p.request.headers || {},
      reqBody,
      respHeaders: resp?.headers || {},
      respBody,
      ts: typeof p.wallTime === 'number' ? Math.round(p.wallTime * 1000) : (ev.ts || Date.now()),
    });
  }

  ensureDir(path.join(outDir, 'intermediate'));
  writeJsonl(intermediatePath(outDir, 'paired.jsonl'), paired);
  return {
    source: 'cdp',
    count: paired.length,
    requests: requests.length,
    responses: responses.length,
    bodiesAttached: paired.filter(r => r.respBody != null).length,
    bodiesDir,
  };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [run, out, bodies] = process.argv.slice(2);
  if (!run || !out) { console.error('usage: load.mjs <run-path|har-file> <out-dir> [bodies-dir]'); process.exit(2); }
  const stats = load(run, out, { bodies });
  console.log(`load (${stats.source}): ${stats.count} paired${stats.bodiesAttached ? `, ${stats.bodiesAttached} response bodies attached` : ''}`);
}
