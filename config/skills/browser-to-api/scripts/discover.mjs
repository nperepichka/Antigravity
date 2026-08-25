#!/usr/bin/env node
// Top-level dispatcher: load → filter → normalize → infer → emit.
//
// Usage:
//   node scripts/discover.mjs --run .local/o11y/<run-id> [flags]
//   node scripts/discover.mjs --har ./traffic.har [flags]

import path from 'node:path';
import fs from 'node:fs';
import { resolveRun, ensureDir } from './lib/io.mjs';
import { load, loadHar } from './load.mjs';
import { filter } from './filter.mjs';
import { normalize } from './normalize.mjs';
import { infer } from './infer.mjs';
import { emit } from './emit.mjs';

function parseArgs(argv) {
  const opts = {
    run: null, har: null, out: null, bodies: null,
    include: [], exclude: [], origins: [],
    format: 'both', title: null, redact: [],
    minSamples: 1, stage: null,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => argv[++i];
    switch (a) {
      case '--run': opts.run = next(); break;
      case '--har': opts.har = next(); break;
      case '--out': opts.out = next(); break;
      case '--bodies': opts.bodies = next(); break;
      case '--include': opts.include.push(next()); break;
      case '--exclude': opts.exclude.push(next()); break;
      case '--origins': opts.origins = next().split(',').map(s => s.trim()).filter(Boolean); break;
      case '--format': opts.format = next(); break;
      case '--title': opts.title = next(); break;
      case '--redact': opts.redact = next().split(',').map(s => s.trim()).filter(Boolean); break;
      case '--min-samples': opts.minSamples = parseInt(next(), 10); break;
      case '--stage': opts.stage = next(); break;
      case '-h': case '--help':
        printHelp(); process.exit(0);
      default:
        // Check if positional argument is a .har file or run directory
        if (!opts.run && !opts.har) {
          if (a.endsWith('.har')) opts.har = a;
          else opts.run = a;
          break;
        }
        console.error(`unknown arg: ${a}`);
        printHelp(); process.exit(2);
    }
  }
  return opts;
}

function printHelp() {
  console.log(`browser-to-api — Discover OpenAPI 3.1 specs from browser traffic (100% local, no Browserbase needed)

Usage:
  node scripts/discover.mjs --run <path-or-run-id> [options]
  node scripts/discover.mjs --har <path-to-file.har> [options]

Options:
  --run <path>      Path to local CDP run directory (.local/o11y/<run-id>)
  --har <file>      Path to .har file exported from Chrome / Edge / Firefox / Playwright
  --out <dir>       Output directory (default: <run>/api-spec or ./api-spec)
  --bodies <path>   Explicit directory with captured request/response bodies
  --include <regex> Regex pattern for URLs to include (can be repeated)
  --exclude <regex> Regex pattern for URLs to exclude (can be repeated)
  --origins <list>  Comma-separated list of origins/hosts to include
  --format <fmt>    Output format: 'yaml', 'json', or 'both' (default: 'both')
  --title <string>  API title in generated OpenAPI spec
  --redact <list>   Comma-separated extra field/header names to redact
  --min-samples <n> Minimum observations required to include endpoint (default: 1)
  --stage <name>    Run only single stage: load | filter | normalize | infer | emit
`);
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (!opts.run && !opts.har) {
    printHelp();
    process.exit(2);
  }

  let runPath = null;
  let outDir = null;

  if (opts.har) {
    const harResolved = path.resolve(opts.har);
    if (!fs.existsSync(harResolved)) {
      console.error(`Error: HAR file not found: ${opts.har}`);
      process.exit(1);
    }
    runPath = harResolved;
    outDir = opts.out ? path.resolve(opts.out) : path.join(path.dirname(harResolved), 'api-spec');
  } else {
    runPath = resolveRun(opts.run);
    if (!fs.existsSync(runPath)) {
      console.error(`Error: Run directory not found: ${opts.run}`);
      process.exit(1);
    }
    outDir = opts.out ? path.resolve(opts.out) : path.join(runPath, 'api-spec');
  }

  ensureDir(outDir);

  const stages = opts.stage ? [opts.stage] : ['load', 'filter', 'normalize', 'infer', 'emit'];

  for (const stage of stages) {
    const t0 = Date.now();
    let stats;
    switch (stage) {
      case 'load':
        stats = opts.har ? loadHar(runPath, outDir) : load(runPath, outDir, { bodies: opts.bodies });
        break;
      case 'filter':
        stats = filter(outDir, { include: opts.include, exclude: opts.exclude, origins: opts.origins });
        break;
      case 'normalize':
        stats = normalize(outDir);
        break;
      case 'infer':
        stats = infer(outDir, { redact: opts.redact });
        break;
      case 'emit':
        stats = emit(outDir, { minSamples: opts.minSamples, format: opts.format, title: opts.title });
        break;
      default:
        console.error(`unknown stage: ${stage}`);
        process.exit(2);
    }
    const ms = Date.now() - t0;
    console.log(`[${stage}] ${ms}ms ${JSON.stringify(stats)}`);
  }

  console.log(`\nOpenAPI spec generated at: ${outDir}`);
  for (const f of ['index.html', 'client.mjs', 'report.md', 'openapi.yaml', 'openapi.json', 'confidence.json']) {
    const p = path.join(outDir, f);
    if (fs.existsSync(p)) console.log(`  - ${path.relative(process.cwd(), p)}`);
  }
}

main();
