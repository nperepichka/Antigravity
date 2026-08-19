---
name: rpa-capture
description: Record a human driving a real browser workflow, then mine the capture for stable selectors, field inventories and submitted state — the loop for building robust web automation, tests, or RPA scripts. Use when asked to "capture the <site> <flow> at <url>", "record this browser session and extract selectors", or when building reliable Playwright / CDP automation for complex web forms.
---

# rpa-capture — record a browser workflow, then mine it for selectors

One tool for the loop used to build reliable browser automations: **open a fresh Chrome instance → do the workflow by hand → mine the captured DOM & Network traffic for stable selectors.**

Replaces ad-hoc manual DevTools inspection with an automated, reproducible capture surface.

- Driver: `scripts/capture.ts`.
- Output: everything lands under **`.local/o11y/<run>/`** (gitignored). **Never delete these folders** — each represents a real session and ground truth for mining.
- Sibling skill: **`mine-recording`** (for video recordings where you cannot drive the live app yourself).

---

## Prerequisites (100% Local)

- **Google Chrome** installed (override executable path with `CHROME_BIN` if needed).
- **Runtime**: `bun` or `npx tsx` / Node.js.
- **Port**: Default debug port `9222`.

---

## The Capture Loop

```bash
# 1. Start — opens a Chrome window at the URL and records DOM/a11y/network in the background.
#    Use a unique run id (e.g. login-flow-1). --fresh wipes profile for cold login.
bun scripts/capture.ts start <run> --url https://app.example.com/login [--fresh] [--port 9222]

# 2. Drive the workflow by hand in the Chrome window.
#    Pause ~2-3s on each screen so the sampler captures a clean DOM. Linger on dropdowns/modals.
bun scripts/capture.ts status <run>      # check counts (dom/screenshots/requests)

# 3. Stop when done (terminates Chrome & sampler, preserves the session folder).
bun scripts/capture.ts stop <run>
```

---

## Mining Selectors & Network Traffic

After stopping (or during a live session):

```bash
bun scripts/capture.ts timeline <run>            # distinct screens visited, in order
bun scripts/capture.ts ls <run> [--url SUBSTR]   # all DOM dumps with URLs and byte sizes
bun scripts/capture.ts find <run> "<pattern>"    # grep DOM dumps for text, label, or selector
bun scripts/capture.ts fields <run> [--url SUBSTR] # extract form controls, options, and buttons
bun scripts/capture.ts posts <run> [--url SUBSTR]  # decode submitted form POST payloads
```

### 1. Selecting the Right Hooks
When viewing the captured `.html` DOM files under `.local/o11y/<run>/dom/`:
- **Prefer stable hooks:** `id`, `name`, `data-test-id` / `data-*`, `aria-label`, `formcontrolname`, clear button text.
- **Avoid unstable hooks:** Hashed CSS classes, dynamic GUID ids, auto-generated overlay indices.
- **Check the a11y tree:** Each tick writes an accessibility-tree snapshot (`<run>/a11y/<ts>.txt`) — this provides role and name representations that remain durable across frontend redesigns.

---

## Structure vs. State: `fields` vs `posts`

| You want | Command | Source |
|---|---|---|
| Control names, dropdown options, radio groups, buttons | `fields <run> --url <substr>` | The DOM dump (`outerHTML`) |
| Real values and states submitted to the backend | `posts <run> --url <substr>` | The CDP Network log |

**Why both matter:**
- The **DOM dump** carries markup (all `<option>` elements, radio buttons, form controls). However, it does not reliably reflect client-side JavaScript property mutations (`.value`, `.checked`).
- The **CDP Network log (`posts`)** captures the exact encoded payload received by the server upon submission. This is the absolute authority on submitted form state.

---

## Deliverables from a Capture Session

1. **Fixtures** (`rpa/__fixtures__/` or `tests/__fixtures__/`): DOM snapshots that tests run against.
2. **Vocabulary & Traps** (`references/vocab/<system>.md`): Option lists, required field quirks, and trap values (where UI labels differ from submitted values).
3. **Automated Script / Test**: The Playwright, CDP, or automation script implementing the flow.
