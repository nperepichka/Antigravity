// File-IO helpers shared across the pipeline. Node stdlib only.

import fs from 'node:fs';
import path from 'node:path';

export function ensureDir(p) {
  fs.mkdirSync(p, { recursive: true });
}

export function readJsonl(p) {
  if (!fs.existsSync(p)) return [];
  const out = [];
  for (const line of fs.readFileSync(p, 'utf8').split('\n')) {
    if (!line) continue;
    try { out.push(JSON.parse(line)); } catch { /* skip malformed */ }
  }
  return out;
}

export function writeJsonl(p, items) {
  ensureDir(path.dirname(p));
  const body = items.length ? items.map(o => JSON.stringify(o)).join('\n') + '\n' : '';
  fs.writeFileSync(p, body, 'utf8');
}

export function readJson(p, fallback = null) {
  if (!fs.existsSync(p)) return fallback;
  try {
    return JSON.parse(fs.readFileSync(p, 'utf8'));
  } catch {
    return fallback;
  }
}

export function writeJson(p, obj) {
  ensureDir(path.dirname(p));
  fs.writeFileSync(p, JSON.stringify(obj, null, 2) + '\n', 'utf8');
}

export function readText(p, fallback = '') {
  if (!fs.existsSync(p)) return fallback;
  return fs.readFileSync(p, 'utf8');
}

export function writeText(p, s) {
  ensureDir(path.dirname(p));
  fs.writeFileSync(p, s, 'utf8');
}

export function intermediatePath(outDir, name) {
  return path.join(outDir, 'intermediate', name);
}

export function samplePath(outDir, method, hash) {
  return path.join(outDir, 'samples', `${method.toLowerCase()}_${hash}.json`);
}

export function resolveRun(runArg) {
  if (!runArg) return null;
  const p = path.resolve(runArg);
  if (fs.existsSync(p)) return p;
  const candidate1 = path.resolve('.local', 'o11y', runArg);
  if (fs.existsSync(candidate1)) return candidate1;
  const candidate2 = path.resolve('.o11y', runArg);
  if (fs.existsSync(candidate2)) return candidate2;
  return p;
}
