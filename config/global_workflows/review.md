---
description: Read-only, multi-dimensional code review, bidirectional diff reconciliation, and static flow verification against git branches, diffs, or commits.
---

# Code Review, Bidirectional Reconciliation & Static Flow Verification Loop

Objective, comprehensive code review in **strict Read-Only mode** combining **Bidirectional Requirement-to-Diff Reconciliation**, **Static & Abstract Flow Verification** (zero-runtime required), **Blast Radius & Regressions Audit**, and multi-dimensional quality analysis (Security, Performance, Concurrency, Architecture, Compatibility).

---

## Core Directives

- **Strict Read-Only Guarantee:** ZERO unsolicited code edits, state-altering Git commands (`checkout`, `reset`, `merge`, `pull`), or package installations. Permitted: `git diff`, `git log`, `git show`, `git status`, and isolated in-memory verification runners (REPL/eval).
- **Clean Context & Unanchored Review:** Operate with an isolated, fresh context (ingesting only task specs, extracted diff, and repository rules). Discard conversational trial-and-error baggage, justifications, and intermediate rationalizations from implementation sessions to ensure an objective, adversarial audit.
- **Bidirectional Reconciliation:** Reconcile requirements to code diff two-ways:
  1. *Forward Audit (Coverage):* Ensure 100% of explicit/implicit requirements map to concrete diff logic.
  2. *Backward Audit (Scope Control):* Ensure 0% unrequested changes, dead code, or side-effect edits exist in the diff.
- **Static & Abstract Flow Proof:** Analytically verify data flows, boundary conditions, and failure propagation across all branching paths without requiring a full environment or UI spin-up.
- **Actionable Critique:** Every finding must cite exact file path, line numbers, risk explanation, and a concrete ````diff```` fix. Format all locations and cited symbols with clickable line-range links (`[Symbol / File](file:///path/to/file#L10-L25)`).
- **Documentation & Contract Synchronization:** Verify that any changes affecting public API shapes, data models, environment variables, database schemas, CLI flags, or architectural flows are accurately reflected in the project's documentation (`README.md`, OpenAPI specs, ADRs, setup runbooks, code docstrings).
- **Verified References Only (Rule I):** Every file path, line number, function name, and code snippet cited in the report MUST be sourced from actual `git diff`, `view_file`, or `grep_search` output. Never cite phantom locations or fabricate snippets from memory.
- **Bifurcated Delivery Protocol:** For uncommitted/staged working tree changes (`git diff HEAD`, `git diff --staged`), deliver the review directly in chat in the user's active language (**Rule A**) with ZERO disk artifacts. For committed targets (external branches, PRs, commit ranges), compile a formal **English** report in **`.local/review_report.md`** (**Rule E**) with a clickable link.

---

## Workflow Steps

### Step 1: Task Context & Diff Resolution

#### 1.1 Task Context Ingestion & Requirement Atomization
1. **Locate Task Context (Single or Multi-Phase):**
   - *Single Phase/Task:* Active prompt, issue ticket, `task.md`, specification file (`specs/*.md`), or `/investigate` phase spec (`01_<phase>.md`).
   - *Multi-Phase / Milestone Scope:* Ingest multiple phase specs simultaneously (e.g., `01_<phase>.md` + `02_<phase>.md` or `00_overview.md`) when reviewing cumulative batches.
2. **Context Guard (Mandatory Stop):**
   - If task goals, constraints, or acceptance criteria are missing or ambiguous and required for bidirectional reconciliation, **HALT** immediately.
   - Prompt user: *"Please provide the exact acceptance criteria / task requirements to enable bidirectional verification."*
3. **Requirement Atomization:**
   - Deconstruct ingested task(s) into an explicit, numbered list (namespaced by phase when multi-task):
     - Single task: `[REQ-1]`, `[REQ-2]`, `[REQ-N]`
     - Multi-task / Multi-phase: `[REQ-P1-1]`, `[REQ-P1-2]`, `[REQ-P2-1]`, `[REQ-GLOBAL-1]`
     - Cover: functional requirements, edge cases, zero/boundary states, and non-functional contracts (error schema, performance, idempotency, backward compatibility).

#### 1.2 Target Resolution & Multi-State Diff Extraction
1. **Target State Identification (Staged, Uncommitted, or Committed):**
   - *Working Tree Status Check:* Run `git status -s` to assess tracked, staged, and unstaged modifications.
   - *Working Tree Changes (Default for uncommitted tasks):* `git diff HEAD` (captures all uncommitted modifications in the working tree across active phases).
   - *Staged Changes (When staged manually by user):* `git diff --staged` (or `git diff --cached`) if the user has manually staged verified files.
   - *Cumulative Branch Diff (Full feature vs Base):* `git diff <base_branch>` (e.g., `git diff main` or `git diff develop`) capturing all committed + staged + working tree changes.
   - *Branch Comparison:* `git diff <base>...<target>` (e.g., `git diff main...feature`).
   - *Commit Range:* `git diff HEAD~N..HEAD` or `git diff <base_commit>..<target_commit>`.
2. **Diff & History Extraction:**
   - Modified files summary: `git diff --name-status <target_expression>` (e.g., `git diff --name-status --staged` or `git diff --name-status HEAD`).
   - Full unified diff: `git diff <target_expression>`.
   - Intent log (if committed): `git log -n 10 --oneline <base>..<target>`.
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
- **Queries & Data Access:** N+1 query patterns, missing database indexes, unbounded queries (missing `LIMIT`/pagination). Flag `OFFSET`/`SKIP` pagination on large or unbounded datasets; recommend keyset/cursor-based alternatives.
- **Contract Drift:** When entity/DTO schemas changed in diff, verify all downstream mapping layers, API return types, and client interfaces are updated accordingly.
- **Resource Leaks:** Proper disposal of streams, database connections, HTTP clients, and socket pools.
- **Cancellation & Async:** Proper propagation of `CancellationToken` / context deadlines, avoiding blocking async calls (`.Result`, `.Wait()`, synchronous sleep inside async methods).

#### 3.6 Architecture, SOLID & Code Quality
- **Surgical Scope:** Focused changes without accidental touches (**Rule D**).
- **Solution Integrity & Anti-Masking (Rule J):** Ensure zero symptom-masking conditional branches (`if/else`, `switch/case`, special-case flags) added to hide bugs. Changes must correct the root cause in the underlying data flow, domain model, or contract. Verify no stacked patches on a broken foundation.
- **Coupling & Cohesion:** Clear separation of concerns (domain logic decoupled from presentation and persistence layers).
- **Error Handling:** No swallowed exceptions (`catch (Exception) {}`), proper null guards, explicit domain results (`Result<T, E>`), accurate HTTP status codes and error models.
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
- **Coverage (Rule F):** New public methods, logical branches, and error paths covered by targeted unit tests.
- **Quality & Balance:** Meaningful assertions (no empty or assert-true-only tests), deterministic execution, zero flaky patterns, clean test state isolation. Flag brittle over-mocking that tests mock wiring instead of real behavior. Verify that unit coverage is balanced with targeted live entry-point verification.

#### 3.10 Dependencies, Supply Chain & CI/CD Audit
- **Supply Chain:** Compatible open-source licenses, active package maintenance, zero known CVEs.
- **Pinning:** Deterministic version constraints (no wildcard `*` or floating `latest`).
- **CI/CD Workflows:** (`.github/workflows/`, `azure-pipelines.yml`, `Dockerfile`) Ensure security gates, linters, or test suites are not bypassed, disabled, or over-permissioned.

#### 3.11 Documentation & Contract Drift Synchronization
- **Documentation Currency:** If public APIs, environment variables, configuration schemas, CLI commands, database migrations, or core domain workflows are modified, verify whether relevant documentation (`README.md`, docs, OpenAPI/Swagger specifications, ADRs, architecture diagrams, setup guides) has been updated in the diff or flagged if missing.
- **Docstring & API Comments Integrity:** Ensure code-level docstrings and parameter comments accurately reflect updated logic and edge cases without stale or obsolete explanations.

---

## Step 4: Report Generation & Verification Artifacts

Format the review report using the structure below. For **committed changes** (external branches, PRs, commit ranges), save the full technical report in **English** to **`.local/review_report.md`** (**Rule E**). For **uncommitted/staged changes** (local working tree), skip file creation to avoid cluttering the workspace. In both cases, deliver the complete, identically structured review directly in the dialogue in the user's active language (**Rule A**), keeping code identifiers, file paths, diff snippets, and symbols in **English** (**Rule E**).

### 1. Executive Summary & Verdict
- **Verdict:** 🟢 **APPROVED** / 🟡 **APPROVED WITH SUGGESTIONS** / 🔴 **REQUEST CHANGES**
- **High-Level Summary:** Core changes, architectural impact, and overall quality assessment.

### 2. Bidirectional Requirement-to-Diff Verification Table
| Requirement ID | Requirement Description | Implementation Location | Logic / Invariant Proof | Status |
| :--- | :--- | :--- | :--- | :--- |
| `[REQ-1]` | [Requirement text] | [`path/to/file.ext#L10-L25`](file:///path/to/file.ext#L10-L25) | [Traced data flow, boundary behavior proof] | **Verified** / **Gap** |
| `[REQ-2]` | [Requirement text] | [`path/to/file.ext#L10-L25`](file:///path/to/file.ext#L10-L25) | [Error handling / zero-state handled cleanly] | **Verified** / **Gap** |
| `[REQ-N]` | [Requirement text] | [`path/to/file.ext#L10-L25`](file:///path/to/file.ext#L10-L25) | [Non-functional / contract validation] | **Verified** / **Gap** |

### 3. Static Verification Checklist
- [x] **Scope Integrity:** 0 unrequested changes or side-effect edits in diff.
- [x] **Solution Integrity (Rule J):** 0 symptom-masking conditional branches or stacked band-aids hiding root-cause flaws.
- [x] **Blast Radius:** All upstream/downstream callers statically checked for regressions.
- [x] **Contract & Type Safety:** Downstream signatures and contracts preserved without breaks.
- [x] **Documentation Sync:** Project docs (README, API specs, ADRs, config templates) verified and synchronized with code changes.
- [x] **Invariant Proof:** All failure/edge branches analytically resolved without leaks or unhandled errors.
- [x] **Zero-Runtime Guarantee:** Core logic verified analytically without requiring full environment spin-up.

### 4. Categorized Findings & Actionable Fixes

#### 🔴 Critical Findings (Must Fix)
*Vulnerabilities, data corruption/loss, crashes, contract breakage, or missing requirement implementations.*
- **Location:** [`file_path#Llines`](file:///absolute/path/to/file.ext#L10-L25)
- **Category:** (Security | Invariant Broken | Concurrency | Contract Breakage | Requirement Gap | Breaking Spec Drift)
- **Problem & Impact:** Detailed technical explanation of the failure mode.
- **Actionable Fix:**
  ````diff
  - // buggy or vulnerable line(s)
  + // robust, secure line(s)
  ````

#### 🟡 Major Improvements (Should Fix)
*Performance bottlenecks, potential race conditions, missing edge guards, architectural coupling.*
- **Location:** [`file_path#Llines`](file:///absolute/path/to/file.ext#L10-L25)
- **Category:** (Performance | Resource Leak | Error Handling | Architecture | Documentation Drift / Stale Spec)
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

1. **Bifurcated Delivery Protocol:**
   - **Uncommitted / Staged Scope (Working Tree / Self-Review):** When reviewing uncommitted (`git diff HEAD`) or staged (`git diff --staged`) working tree changes, deliver the complete review directly in the dialogue in the user's active language (**Rule A**) with **zero file creation**.
   - **Committed Scope (Branch / PR / External Review):** When reviewing committed diffs (`<base>...<target>`, commit ranges, or external branches), compile the full technical report in **English** (**Rule E**) and save it to **`.local/review_report.md`** (ensuring `.local/` exists). Present the identical structured review in the dialogue in the user's active language (**Rule A**) with a clickable link to [`.local/review_report.md`](file:///path/to/.local/review_report.md).
   - **Code & Identifier Invariant:** Code identifiers, file paths, line ranges, diff snippets, and technical symbols remain strictly in **English** (**Rule E**) across both modes.
