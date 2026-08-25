#!/usr/bin/env node
// Convert a .har file directly to OpenAPI 3.1 spec and HTML documentation.
//
// Usage:
//   node scripts/har-to-spec.mjs <file.har> [--out ./api-spec] [--title "My API"]

import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const discoverPath = path.join(__dirname, 'discover.mjs');

const args = process.argv.slice(2);
if (args.length === 0 || args.includes('-h') || args.includes('--help')) {
  console.log(`har-to-spec — Quick HAR to OpenAPI 3.1 converter

Usage:
  node scripts/har-to-spec.mjs <file.har> [options]

Examples:
  node scripts/har-to-spec.mjs dump.har
  node scripts/har-to-spec.mjs dump.har --out ./specs/my-api --title "Storefront API"
`);
  process.exit(0);
}

const harFile = args[0];
const extraArgs = args.slice(1);

const child = spawnSync('node', [discoverPath, '--har', harFile, ...extraArgs], {
  stdio: 'inherit',
});

process.exit(child.status || 0);
