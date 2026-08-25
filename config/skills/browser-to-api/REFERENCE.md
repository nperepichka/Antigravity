# Browser to API — Reference

Technical reference for scripts, normalization heuristics, JSON Schema inference, and intermediate data models.

---

## Pipeline Architecture

The pipeline consists of 5 stages executed in order:

```
Input Source (.har or CDP logs)
   │
   ▼
1. load.mjs       → intermediate/paired.jsonl
   │
   ▼
2. filter.mjs     → intermediate/filtered.jsonl
   │
   ▼
3. normalize.mjs  → intermediate/endpoints.jsonl + endpoint-samples.jsonl
   │
   ▼
4. infer.mjs      → intermediate/endpoints.with-schemas.jsonl + samples/*.json
   │
   ▼
5. emit.mjs       → openapi.yaml, openapi.json, index.html, client.mjs, report.md
```

---

## Stage Details

### 1. `load.mjs`
- Reads either `.har` JSON or CDP log files (`requests.jsonl` + `responses.jsonl`).
- Pairs requests with corresponding responses by `requestId` (or HAR entry sequence).
- Filters out preflight `OPTIONS` requests, pure redirects (3xx), static image/font/CSS requests, and data URLs.
- Extracts `method`, `url`, `origin`, `path`, `query`, `status`, `reqHeaders`, `reqBody`, `respHeaders`, `respBody`.
- Emits `intermediate/paired.jsonl`.

### 2. `filter.mjs`
- Filters out tracking/analytics pixels (Segment, Mixpanel, Google Analytics, Datadog, Sentry, Hotjar, Facebook Pixel, etc.).
- Strips service worker and manifest files (`sw.js`, `manifest.json`, `robots.txt`, `favicon.ico`).
- Applies user-specified `--origins`, `--include`, and `--exclude` regex rules.
- Emits `intermediate/filtered.jsonl`.

### 3. `normalize.mjs`
- **Path Templating Heuristics**:
  - UUID v1–v5 (`[0-9a-f]{8}-...`) → `{id}` (`type: string, format: uuid`)
  - Numeric IDs (`^\d+$`) → `{id}` (`type: integer`)
  - Hex strings (8+ chars) → `{id}` (`type: string`)
  - Varying slugs across samples → `{slug}` (`type: string`)
- **Multiplexed Endpoint Decomposition**:
  - Automatically identifies GraphQL operations (`operationName` or `?opname=`) and JSON-RPC methods (`method`).
  - Separates them into distinct operations (e.g. `/graphql [GetUsers]`, `/graphql [CreatePost]`).
- **Query Parameter Aggregation**:
  - Determines if query params are `required: true` (if present in 100% of samples) or optional.
  - Infers types (`integer`, `number`, `boolean`, `string`).
- Emits `intermediate/endpoints.jsonl`.

### 4. `infer.mjs`
- **JSON Schema Inference**:
  - Recursively crawls request and response bodies.
  - Identifies types: `string`, `integer`, `number`, `boolean`, `object`, `array`, `null`.
  - Merges multiple observation schemas (unions types, marks fields `required` only if present in all observed samples).
  - Infers string formats: `date-time` (ISO 8601), `uuid`, `uri`, `email`.
  - Detects `enum` when distinct values <= 8 and sample count >= 5.
- **Data Redaction**:
  - Redacts sensitive headers (`Authorization`, `Cookie`, `X-API-Key`, etc.).
  - Redacts sensitive JSON keys (`password`, `token`, `secret`, `ssn`, `creditcard`).
  - Masks JWT tokens, emails, and phone numbers.
- Emits `intermediate/endpoints.with-schemas.jsonl` and `samples/*.json`.

### 5. `emit.mjs`
- Hoists repeated object schemas into `components.schemas` with readable generated names (e.g. `User`, `User_List`, `OrderRequest`).
- Generates valid OpenAPI 3.1.0 in YAML and JSON.
- Generates standalone, self-contained `index.html` report with interactive dark-mode operation viewer and curl generator.
- Generates `client.mjs` wrapper SDK.
- Emits `confidence.json` and `report.md`.
