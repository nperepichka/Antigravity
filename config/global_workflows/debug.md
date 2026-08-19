---
description: Autonomous root cause analysis (RCA), incident diagnosis, minimal failing reproduction test generation, and surgical bug fixing across multi-stack projects.
---

# Root Cause Analysis (RCA) & Debug Loop

Autonomous hypothesis-driven debugging loop for deterministic defect reproduction, diagnosis, and surgical repair.

---

## Core Directives
- **Red-Before-Green Rule:** NEVER patch code based on guesswork. Write/identify a deterministic failing test or reproduction script FIRST before modifying production logic.
- **Surgical Fix:** Fix only root cause per **Rule D**. No unsolicited refactoring or cosmetic sweeps.
- **Safety Boundaries:** Adhere to **Rule C** (no unauthorized package installs or destructive commands).

---

## Workflow Steps

### Step 1: Incident Ingestion & Target Isolation
1. **Signal Capture:** Extract exception type, error message, stack trace, HTTP codes, failing payloads, flaky test names, and environmental triggers (OS, timezone, concurrency).
2. **Target Isolation:** Map stack trace/symptoms to specific files, classes, methods, and entry points via `grep_search` and targeted file viewing.

---

### Step 2: Deterministic Reproduction Gate (Red Phase)
*Must complete before modifying ANY production code:*
1. **Isolated Repro Test & State Isolation:** Add a targeted unit/integration test reproducing the exact failure (or minimal repro script). Ensure strict state isolation (rollback transactions, in-memory DB, reset mocks/env in `tearDown`) to prevent flaky test pollution.
2. **Execute & Confirm Failure:** Run using fast targeted runners:
   - `.NET:` `dotnet test --filter ...`
   - `Python:` `pytest path/to/test.py::test_func`
   - `JS/TS:` `npm test -- path/to/test.ts -t "repro"`
   - `Rust:` `cargo test repro`
   Confirm test fails with the **exact reported error/assertion**.
3. **Isolated In-Memory Micro-Evaluation (Pure Logic):** If the defect resides in pure algorithmic logic, complex regex, parsers, or mathematical state transitions, run a lightweight in-memory snippet (via Node / Python / REPL / CLI) passing boundary fixtures for instant verification without spinning up heavy infrastructure.
4. **Circuit Guard:** If defect cannot be reproduced, do NOT attempt blind fixes. Check race conditions, async deadlocks, missing env vars, or DB state. Request clarifying logs from user.

---

### Step 3: Root Cause Analysis (RCA)
1. **Flow Tracing & Invariant Audit:** Trace execution from input to failure point (`Controller -> Service -> Domain -> DB / Client`). Analytically audit:
   - *Zero & Boundary States:* `null`/`undefined`/`None`, `0`, empty collections, max bounds, empty strings.
   - *Failure & Async Propagation:* Swallowed exceptions, unhandled Promise rejections, hanging threads, missing timeouts.
   - *State & Resource Consistency:* Unclosed stream/socket handles, uncommitted/unrolled transactions, race conditions on shared state.
2. **Hypothesis Validation:** Formulate 1–2 precise hypotheses for *why* the defect occurs. Verify against the failing repro test and code ranges.

---

### Step 4: Surgical Fix & Verification (Green Phase)
1. **Minimal Patch:** Apply the minimal robust fix directly resolving the root cause. Avoid symptom-masking workarounds.
2. **Fast Inner Loop:** Re-run reproduction test until **100% green**.
3. **Full Regression Gate:** Run full project build, typecheck, lint, and test suite. Resolve any breakages until the entire suite is green.

---

### Step 5: Blast-Radius & Documentation
1. **Blast-Radius & Caller Regression Scan:**
   - *Anti-Pattern Scan:* Use `grep_search` to find identical anti-patterns or missing guards elsewhere in the codebase. Apply surgical fixes if sharing the exact root cause.
   - *Downstream Caller Audit:* Statically verify all callers/references of modified functions or types to ensure the fix introduces zero contract breakages or regressions in unaffected modules.
2. **Artifact Documentation (`walkthrough.md`):**
   - **Symptom & Root Cause:** Concise explanation of defect mechanics.
   - **Reproduction Evidence:** Test case or script created.
   - **Solution Summary:** Fix details with key code references.
   - **Verification Proof:** Passing test run output.
3. **User Summary:** Deliver concise summary in user's conversational language (**Rule A**).

---

## Circuit Breaker
If the bug cannot be reproduced or fixed after **4–5 iterations**, halt immediately. Summarize evaluated hypotheses, repro logs, and root blockers, then request user guidance.
