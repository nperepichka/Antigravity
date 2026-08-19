---
description: Read-only, multi-dimensional code review, bidirectional diff reconciliation, and static flow verification against git branches, diffs, or commits.
---

# Code Review, Bidirectional Reconciliation & Static Flow Verification Loop

Objective, comprehensive code review in **strict Read-Only mode** combining **Bidirectional Requirement-to-Diff Reconciliation**, **Static & Abstract Flow Verification** (zero-runtime required), **Blast Radius & Regressions Audit**, and multi-dimensional quality analysis (Security, Performance, Concurrency, Architecture, Compatibility).

---

## Core Directives

- **Strict Read-Only Guarantee:** ZERO unsolicited code edits, state-altering Git commands (`checkout`, `reset`, `merge`, `pull`), or package installations. Permitted: `git diff`, `git log`, `git show`, `git status`, and isolated in-memory verification runners (REPL/eval).
- **Bidirectional Reconciliation:** Reconcile requirements to code diff two-ways:
  1. *Forward Audit (Coverage):* Ensure 100% of explicit/implicit requirements map to concrete diff logic.
  2. *Backward Audit (Scope Control):* Ensure 0% unrequested changes, dead code, or side-effect edits exist in the diff.
- **Static & Abstract Flow Proof:** Analytically verify data flows, boundary conditions, and failure propagation across all branching paths without requiring a full environment or UI spin-up.
- **Actionable Critique:** Every finding must cite exact file path, line numbers, risk explanation, and a concrete ````diff```` fix.

---

## Workflow Steps

### Step 1: Task Context & Diff Resolution

#### 1.1 Task Context Ingestion & Requirement Atomization
1. **Locate Task Context:** Parse active prompt, issue tracker ticket, `task.md`, specification files (`specs/*.md`), or `/investigate` phase specs (`01_<phase>.md`).
2. **Context Guard (Mandatory Stop):**
   - If task goals, constraints, or acceptance criteria are missing or ambiguous and required for bidirectional reconciliation, **HALT** immediately.
   - Prompt user: *"Please provide the exact acceptance criteria / task requirements to enable bidirectional verification."*
3. **Requirement Atomization:**
   - Deconstruct task into an explicit, numbered list:
     - `[REQ-1]`: Primary functional requirement
     - `[REQ-2]`: Specific edge case, boundary state, or constraint
     - `[REQ-N]`: Non-functional / contract requirement (e.g., error schema, performance, idempotency, backward compatibility)

#### 1.2 Target Resolution & Diff Extraction
1. **Target Identification:**
   - *Branch Comparison:* `git diff <base>...<target>` (e.g., `git diff main...feature`)
   - *Commit Range:* `git diff HEAD~N..HEAD`
   - *Working Tree (Default):* `git diff HEAD`
2. **Diff & History Extraction:**
   - Modified files summary: `git diff --name-status <base>...<target>`
   - Full unified diff: `git diff <base>...<target>`
   - Intent log: `git log -n 10 --oneline <base>..<target>`
3. **Context Deep-Dive:** Inspect surrounding source code using range-limited `view_file` to evaluate caller context.
4. **Large Diff Triage (>1000 lines):** Prioritize: Security (auth/crypto/APIs) -> Data Models/Schema -> Business Logic -> Infrastructure/Config -> Tests -> Formatting/Renames.

---

### Step 2: Bidirectional Diff Reconciliation

Execute two-way alignment between atomized requirements and the extracted diff:

1. **Forward Audit (Completeness & Coverage):**
   - Verify every `[REQ-i]` maps directly to concrete, implemented logic in `git diff`.
   - Flag any requirement that is missing, partially implemented, or lacking corresponding logic.
2. **Backward Audit (Scope Control & Minimal Diff):**
   - Verify every chunk of code in `git diff` maps back to a specific `[REQ-i]`.
   - Flag and report unsolicited refactoring, unnecessary rewrites, orphaned helpers, dead code, or unintended side-effect edits (**Rule D**).

---

### Step 3: Multi-Dimensional Static & Flow Verification Matrix

Evaluate the diff against the complete multi-dimensional audit dimensions:

#### 3.1 Security & Vulnerability Analysis (OWASP)
- **Secrets & Credentials:** No committed API keys, certificates, private keys, or tokens.
- **Contextual Intent:** Distinguish test fixtures/mocks (e.g., `fake-key-123`, in-memory SQLite) from genuine leaks.
- **Injection Vectors:** SQL/NoSQL injection, OS command injection, XSS, SSRF, path traversal, XXE.
- **Auth & Access Control:** Proper role/permission guards, JWT/token validation, tenant isolation on all public and internal endpoints.
- **Input Validation & Cryptography:** Strict payload schema validation, strong hashing/ciphers, safe deserialization.

#### 3.2 Symbolic Data-Flow & Pipeline Mapping
*Trace without running full system or UI:*
- **Trace Entry to Exit:** Trace the complete data path through modified components, controllers/services, DTO mappings, and storage/network boundaries.
- **Schema & Contract Integrity:** Validate that input/output types remain strictly compliant across callers and downstream consumers without silent data truncation or breaking changes.

#### 3.3 Analytical Invariant & Edge-Path Proof
*Trace analytically across all branching paths:*
- **Zero & Boundary States:** Explicitly verify behavior on empty collections, `null`/`undefined`/`None`, `0`, negative numbers, maximum bounds, and empty string inputs.
- **Failure & Exception Propagation:** Confirm downstream errors, timeouts, or exceptions are caught, cleanly mapped, or safely bubbled up without leaking unhandled states, crashing processes, or hanging background threads/promises.
- **State Consistency & Resource Invariants:** Ensure critical system invariants (mutexes, transaction scopes, status enums, stream/file/socket handles) are guaranteed to reset, rollback, or close across both success and failure branches (`try-finally`, `using`, `defer`).
- **Concurrency & Race Invariants:** Audit shared mutable state, async boundaries, synchronization primitives, lock ordering (deadlock prevention), and ensure composite operations preserve atomicity.

#### 3.4 Blast Radius & Caller Dependency Audit
*Perform static dependency and reference analysis:*
- **Caller Analysis:** Find all references and callers of modified classes, functions, interfaces, and methods across the repository via `grep_search`.
- **Breaking Changes:** Verify that signature changes, default parameter modifications, or altered return types do not introduce compile errors or runtime regressions in unmodified files.

#### 3.5 Performance & Resource Management
- **Queries & Data Access:** N+1 query patterns, missing database indexes, unbounded queries (missing `LIMIT`/pagination).
- **Resource Leaks:** Proper disposal of streams, database connections, HTTP clients, and socket pools.
- **Cancellation & Async:** Proper propagation of `CancellationToken` / context deadlines, avoiding blocking async calls (`.Result`, `.Wait()`, synchronous sleep inside async methods).

#### 3.6 Architecture, SOLID & Code Quality
- **Surgical Scope:** Focused changes without accidental touches.
- **Coupling & Cohesion:** Clear separation of concerns (domain logic decoupled from presentation and persistence layers).
- **Error Handling:** No swallowed exceptions (`catch (Exception) {}`), proper null guards, accurate HTTP status codes and error models.
- **Type Strictness:** No loose types (`any`, `object`), unhandled nullable references, or unsafe type casts.

#### 3.7 Backward Compatibility & Schema Integrity
- **Contracts:** Non-breaking API DTOs and public interface contracts.
- **Database Migrations:** Non-blocking, idempotent, reversible migrations (`IF NOT EXISTS`, safe rollback paths).
- **Configuration & Environment:** Documented new variables with sensible defaults in sample configs (`.env.example`, `appsettings.json` templates).

#### 3.8 Isolated In-Memory Micro-Evaluation & Targeted Execution (When Applicable)
- **Isolated Pure Logic Micro-Evaluation:**
  - If mathematical calculations, complex regex, state machines, or algorithmic mappings changed: run a lightweight, self-contained in-memory snippet (via CLI / Node / Python / REPL) passing boundary fixtures to formally verify mathematical/logical correctness.
- **Targeted Single-Run Execution (When Tooling/Browser Available):**
  - If browser/CLI tools are available, synthesize exactly **one** linear execution path covering the modified code.
  - Execute targeted single-run verification without blind exploration, monitoring console errors and network status.

#### 3.9 Test Coverage & Quality
- **Coverage:** New public methods, logical branches, and error paths covered by tests.
- **Quality:** Meaningful assertions (no empty or assert-true-only tests), deterministic execution, zero flaky patterns, clean test state isolation.

#### 3.10 Dependencies, Supply Chain & CI/CD Audit
- **Supply Chain:** Compatible open-source licenses, active package maintenance, zero known CVEs.
- **Pinning:** Deterministic version constraints (no wildcard `*` or floating `latest`).
- **CI/CD Workflows:** (`.github/workflows/`, `azure-pipelines.yml`, `Dockerfile`) Ensure security gates, linters, or test suites are not bypassed, disabled, or over-permissioned.

---

## Step 4: Report Generation & Verification Artifacts

Format the review report as `Code Review Report: [Branch/Target]` (or write to `review_report.md` for large reviews):

### 1. Executive Summary & Verdict
- **Verdict:** 🟢 **APPROVED** / 🟡 **APPROVED WITH SUGGESTIONS** / 🔴 **REQUEST CHANGES**
- **High-Level Summary:** Core changes, architectural impact, and overall quality assessment.

### 2. Bidirectional Requirement-to-Diff Verification Table
| Requirement ID | Requirement Description | Implementation Location | Logic / Invariant Proof | Status |
| :--- | :--- | :--- | :--- | :--- |
| `[REQ-1]` | [Requirement text] | `path/to/file.ext:lines` | [Traced data flow, boundary behavior proof] | **Verified** / **Gap** |
| `[REQ-2]` | [Requirement text] | `path/to/file.ext:lines` | [Error handling / zero-state handled cleanly] | **Verified** / **Gap** |
| `[REQ-N]` | [Requirement text] | `path/to/file.ext:lines` | [Non-functional / contract validation] | **Verified** / **Gap** |

### 3. Static Verification Checklist
- [x] **Scope Integrity:** 0 unrequested changes or side-effect edits in diff.
- [x] **Blast Radius:** All upstream/downstream callers statically checked for regressions.
- [x] **Contract & Type Safety:** Downstream signatures and contracts preserved without breaks.
- [x] **Invariant Proof:** All failure/edge branches analytically resolved without leaks or unhandled errors.
- [x] **Zero-Runtime Guarantee:** Core logic verified analytically without requiring full environment spin-up.

### 4. Categorized Findings & Actionable Fixes

#### 🔴 Critical Findings (Must Fix)
*Vulnerabilities, data corruption/loss, crashes, contract breakage, or missing requirement implementations.*
- **Location:** `[file_path#Llines]`
- **Category:** (Security | Invariant Broken | Concurrency | Contract Breakage | Requirement Gap)
- **Problem & Impact:** Detailed technical explanation of the failure mode.
- **Actionable Fix:**
  ````diff
  - // buggy or vulnerable line(s)
  + // robust, secure line(s)
  ````

#### 🟡 Major Improvements (Should Fix)
*Performance bottlenecks, potential race conditions, missing edge guards, architectural coupling.*
- **Location:** `[file_path#Llines]`
- **Category:** (Performance | Resource Leak | Error Handling | Architecture)
- **Problem & Impact:** Technical explanation.
- **Actionable Fix:** Concrete ````diff```` block.

#### 🟢 Minor Observations (Nitpicks)
- Compact one-liner suggestions (naming clarity, docstrings, minor test assertions).

#### 💡 Positive Highlights
- Commendations on clean patterns, robust invariant guards, comprehensive tests, or elegant abstractions.

---

## Step 5: Failure Triage & Autonomous Remediation Protocol

When `/review` is invoked as part of an autonomous dev/QA loop (e.g. within `/implement` or `/investigate` QA phases):
1. **Self-Correction Loop:**
   - If an invariant proof fails, requirement coverage has gaps, or `🔴 Critical` findings exist, execute targeted surgical fixes.
   - Limit autonomous correction loops to a maximum of **2 iterations**.
2. **Circuit Breaker:**
   - If unresolved after 2 iterations, halt immediately, surface the exact blocker and conflicting invariant to the user, and request guidance.

---

## Step 6: Final Delivery

1. The technical review report MUST be in **English** (**Rule E**).
2. Present the findings to the user with a concise conversational summary in the user's language (**Rule A**).
3. If reviewing a large PR or branch, save the detailed report to `review_report.md` in the project root or artifacts directory and provide a clickable link.
