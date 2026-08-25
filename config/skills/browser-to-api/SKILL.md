---
name: browser-to-api
description: Turn observed HTTP/HTTPS browser traffic (.har files or local Chrome/Edge CDP sessions) into an OpenAPI 3.1 specification, interactive HTML explorer, and JavaScript client SDK. 100% offline, zero cloud dependencies. Use when the user wants to reverse-engineer undocumented APIs, generate OpenAPI specs from browser sessions or HAR files, or extract JSON schemas from network traffic.
compatibility: "Requires Node 18+ (uses Node standard library only, 0 npm dependencies). Works with Google Chrome or Microsoft Edge for live CDP sessions, or standard .har export files from any browser."
license: MIT
---

# Browser to API

Automated, offline API discovery and OpenAPI 3.1 specification generator.
Consumes observed HTTP/HTTPS traffic (either from `.har` files exported from DevTools or recorded live from a local Chrome/Edge session), infers JSON schemas, normalizes URL path parameters (`/users/123` → `/users/{id}`, UUIDs, slug heuristics), and emits:

1. **OpenAPI 3.1 Spec** (`openapi.yaml` & `openapi.json`)
2. **Interactive HTML Explorer** (`index.html`) — searchable, dark-mode dashboard with request cards, schema previews, curl commands, and confidence badges.
3. **Callable JavaScript Client SDK** (`client.mjs`) — ready-to-run ESM module with generated helper functions.
4. **Coverage & Confidence Report** (`report.md` & `confidence.json`)

---

## When to Use

- Reverse-engineering an undocumented third-party or internal web API.
- Creating an OpenAPI 3.1 / Swagger documentation for an existing web app from real traffic.
- Converting a browser `.har` export into structured API schemas and endpoints.
- Generating a mock server or client SDK from recorded browser flows.

---

## 3 Flexible Workflows

### Method 1: Instant Conversion from `.har` Export (Fastest)

1. Open DevTools in any browser (Chrome, Edge, Firefox, Safari) ➔ **Network** tab.
2. Interact with the website / web application.
3. Right-click the network list ➔ **"Save all as HAR with content"** (e.g. `session.har`).
4. Generate the OpenAPI spec:

```bash
node scripts/discover.mjs --har session.har --out ./api-spec
# Or using the shorthand:
node scripts/har-to-spec.mjs session.har --out ./api-spec
```

5. Open `./api-spec/index.html` in your browser.

---

### Method 2: Live Local Chrome / Edge Session Recording

Record traffic in real-time using a local browser window via Chrome DevTools Protocol (CDP):

```bash
# 1. Start recording (opens Chrome/Edge window with target URL)
node scripts/capture.mjs start my-run --url https://app.example.com

# 2. Drive the workflows in the opened browser window (login, click items, submit forms)
# Check status at any time:
node scripts/capture.mjs status my-run

# 3. Stop recording when finished
node scripts/capture.mjs stop my-run

# 4. Generate the OpenAPI specification
node scripts/discover.mjs --run my-run
# Spec generated under: .local/o11y/my-run/api-spec/
```

---

### Method 3: Playwright / Puppeteer / Automated Scraper

If you have a Playwright or Puppeteer script, save the HAR output or CDP network logs, then run `discover.mjs`:

```javascript
// Playwright example
const context = await browser.newContext({ recordHar: { path: './playwright-traffic.har' } });
// ... execute test steps ...
await context.close();
```

Then generate the spec:
```bash
node scripts/discover.mjs --har ./playwright-traffic.har --out ./api-spec
```

---

## Deliverables Generated in Output Directory

| File | Description |
|---|---|
| `index.html` | Self-contained, interactive HTML explorer. Search operations, inspect headers/payloads, copy curl/fetch snippets. |
| `openapi.yaml` | Valid OpenAPI 3.1.0 specification in YAML format. |
| `openapi.json` | Valid OpenAPI 3.1.0 specification in JSON format. |
| `client.mjs` | Ready-to-import ES module providing typed-like async functions for all discovered endpoints. |
| `report.md` | Markdown report summarizing endpoints, coverage, inferred formats, and redaction counts. |
| `confidence.json` | Machine-readable confidence metrics and sample counts for each endpoint. |

---

## CLI Options Reference (`discover.mjs`)

| Option | Default | Description |
|---|---|---|
| `--har <file.har>` | — | Path to input `.har` file |
| `--run <dir>` | — | Path or ID of local CDP capture run (`.local/o11y/<run>`) |
| `--out <dir>` | `<run>/api-spec` | Destination folder for generated specification and reports |
| `--format <fmt>` | `both` | Output format: `yaml`, `json`, or `both` |
| `--title <string>` | Hostname | Title for the generated API specification |
| `--origins <list>` | All | Filter to specific domain origins (e.g. `api.example.com,auth.example.com`) |
| `--include <regex>` | — | Include URLs matching regex pattern (repeatable) |
| `--exclude <regex>` | — | Exclude URLs matching regex pattern (repeatable) |
| `--min-samples <n>` | `1` | Minimum observations required to include endpoint |
| `--redact <list>` | — | Comma-separated field names to redact in samples |
| `--stage <name>` | All | Run specific stage only (`load`, `filter`, `normalize`, `infer`, `emit`) |
