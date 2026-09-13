---
description: Autonomous development, compilation, testing, visual document verification, and strategic review cycle across multi-stack projects (.NET, Java, JS/TS/Bun, Python, Rust, Go) for single phases or sequential batch queues (/implement all, /implement 01..03).
---

# Auto-Verify Dev Loop

Autonomous engineering cycle supporting both **Single-Phase Execution** and **Sequential Batch Queue Mode** (`all`, `queue`, `batch`, `01..03`, or conversational equivalents in active language): **Phase I (Tactical Verification)** + **Phase II (Strategic Review)**.

---

## Workflow Steps

### Step 1: Toolchain Detection & Task Alignment
1. **Stack & Toolchain Detection:**
   - **.NET:** `*.csproj`, `*.sln` -> `dotnet build`, `dotnet test --logger "console;verbosity=minimal"`
   - **Java:** Maven `pom.xml` -> `.\mvnw.cmd` / `./mvnw` `compile`/`test -q`; Gradle `build.gradle[.kts]` -> `.\gradlew.bat` / `./gradlew` `build`/`test -q`/`check`
   - **JS / TS (Bun/Node/PNPM/Yarn):** `package.json`, lockfiles -> inspect `scripts` (`typecheck`, `lint`, `test -- --bail` / `bun test --only-failures`, `build`)
   - **Python:** `pyproject.toml`, `uv.lock`, `requirements.txt` -> `pytest -q --tb=short`, `ruff check`, `mypy`/`pyright`
   - **Rust:** `Cargo.toml` -> `cargo check`, `cargo test -- -q`, `cargo clippy`
   - **Go:** `go.mod` -> `go build ./...`, `go test ./...`, `golangci-lint run`
   - **Greenfield:** Scaffold standard layout, dependency definitions, and initial configs.
   - **Monorepo:** (`nx`, `turbo`, `lerna`, `pnpm-workspace`) Scope build/test/lint commands to affected package.
   - **Conditional Baseline Sanity Check:** At the very start of a session or when working in an unfamiliar/unverified environment (only when necessary, do not repeat across consecutive phase runs), run a quick baseline build/test to ensure the repo is green prior to edits. If broken, warn user upfront.
2. **Task Ingestion & Execution Mode Resolution:**
   - **Mode Resolution (Single vs. Sequential Batch Queue):**
     - **Single Mode:** Triggered by `/implement <phase>` (e.g., `/implement 01_domain_models.md`, `/implement 01a`). Executes the specified phase and halts at Step 4.3 with the next phase handoff.
     - **Batch Queue Mode:** Triggered by single-command batch requests:
       - *Keywords:* `all`, `--all`, `queue`, `batch`, or semantic equivalents in user's active language (e.g., asking to run "all", "everything", "queue", or "all in sequence").
       - *Range syntax:* `<start>..<end>` (e.g. `/implement 01..04`, `/implement 01a..02b`).
       - *Delay Modifiers:* Defaults to a 30s decoupled turn boundary between phases (`schedule` watchdog); `--immediate` / `--no-delay` (or conversational: "without delay", "no delay", "immediately") overrides to instant chaining.
     - **Queue Resolution Protocol:**
       1. Ingest the Execution Matrix in `00_overview.md` (or task list in `task.md`).
       2. Filter pending phases (`[ ] Pending` or `[>] In Progress`). If a range is given, constrain execution to that range.
       3. Extract target phase specs in topological DAG order.
       4. Display Queue Initialization Banner in chat:
          ```markdown
          📋 [QUEUE INITIALIZED] Found N pending automated phase(s) in 00_overview.md:
          - [1/N] Phase 01: 01_domain_entities.md [CODE]
          - [2/N] Phase 02: 02_api_endpoints.md [CODE]
          ```
       5. Sequentially iterate through each phase using the isolated Phase Pipeline (Steps 1.3 -> Step 2 -> Step 3 -> Step 4).
   - **Input Formats:** Prompts, issues, standalone task files (`task.md`, `prompt.md`, `specs/*.md`), PDFs, or `/investigate` phase/sub-phase files (`01_<name>.md`, `01a_<name>.md`).
    - **Context & Conventions Ingestion:** Check `.agents/rules/repository-context.md` (if present) for non-obvious domain rules, conventions, and architectural guardrails.
    - **Skill Ingestion:** Check `00_overview.md`, task specifications, or stack requirements for recommended agent skills and activate them if available.
    - **Phase Contract & Ownership Ingestion (`OWNS:` & `Tier`):**
      - Inspect `OWNS: <globs>` in the phase spec to establish the primary write perimeter.
      - External modifications outside these globs are strictly constrained to surgical root wiring and cascading contract sync.
      - Inspect `Tier`: `judgment` mandates the complete Pre-Coding Dialectical Audit (Step 1.3); `mechanical` permits lightweight inline verification.
    - **Fast-Track (`/investigate` specs):** If prerequisites are met, **adopt Scope, Target Files, Context Snippets, and DoD directly as the approved plan**, review tactical invariants (Step 1.3), and proceed to Step 2.
    - **Standalone Complex / Greenfield:** Formulate `implementation_plan.md` (**Rule B**) with `RequestFeedback: true` and `UserFacing: true` in `ArtifactMetadata` (triggering the IDE's native "Proceed" button), incorporating the **Pre-Coding Dialectical Audit** (Step 1.3), and wait for explicit user approval (re-plan on feedback) before modifying code.
    - **Minor / Straightforward:** Proceed directly to Step 2.
3. **Pre-Coding Dialectical Audit Gate (`[DRAFT]` -> `[CRITIQUE]` -> `[ARBITRATION]` -> `[SYNTHESIS]`):**
   *Executes prior to writing or modifying code to prevent both implementation tunnel-vision and runaway over-engineering.*
   - **Activation Matrix (Rule B & Rule H Guard):**
     - *Trivial / Minor / Mechanical Tier (typos, mechanical renames/DTO additions):* **SKIP** or lightweight inline check.
     - *Fast-Track Phase (`/investigate` sub-phase with settled invariants):* **Lightweight / Inline** mental verification of target invariants before typing.
     - *Complex Standalone / Judgment Tier / Data Hotpath / Non-Trivial Business Logic:* **MANDATORY**. Document explicitly in `implementation_plan.md` or session reasoning before code changes.
   - **Dialectical Pipeline:**
     1. **`[DRAFT]` Initial Strategy:** The direct, baseline implementation path, flow of calls, and primary data structures.
     2. **`[CRITIQUE]` Adversarial Engineering Stress-Test:**
        Critique the draft rigorously through 5 non-obvious production lenses (reject superficial checks like basic null guards):
        - **L1 — Transactional Atomicity & Partial Failure:** If the operation fails midway (e.g. DB write commits, but queue publish / HTTP call / file I/O throws), does the system leave orphaned state or inconsistent entities? Is the mutation idempotent upon client retry?
        - **L2 — Concurrency & TOCTOU Hazards:** Can parallel requests read stale state between validation and mutation (Time-Of-Check to Time-Of-Use)? Are there lost updates, uncoordinated cache reads, or race conditions under load?
        - **L3 — Memory Pressure & Hotpath Footprint:** Is external data buffered entirely into RAM (`ReadAllBytes`, unbounded `ToList`) instead of streamed? Are there allocations inside tight loops, boxing, or regex ReDoS risks on untrusted input?
        - **L4 — Lifecycle, Timeouts & Cancellation:** Are asynchronous operations wired to `CancellationToken` / `AbortController`? Does the flow avoid sync-over-async (`.Result`, `.Wait()`), unmonitored fire-and-forget tasks, and leaky unclosed connections?
        - **L5 — Contract Drift & Backward Compatibility:** Does modifying DTOs or schema fields break in-flight queue messages, cached serialized JSON payloads, or downstream API consumers?
     3. **`[ARBITRATION]` Triage & Anti-Overengineering Guard:**
        Explicitly triage every critique point into two categories:
        - **`[ADOPT]`:** Concrete, plausible operational risks addressed cleanly (e.g., wrap in atomic transaction, enforce composite index, stream large payload, pass cancellation token).
        - **`[REJECT]`:** Unjustified, speculative complexity dismissed with technical rationale (e.g., *"Distributed Redis lock rejected — single-node service; DB row lock / transactional CTE suffices (KISS/YAGNI)"*).
     4. **`[SYNTHESIS]` Target Implementation Blueprint:** The finalized, hardened approach transitioned into Phase I coding.

---

### Step 2: Phase I — Tactical Development Loop (4-Pass Anti-Laziness Engineering Cycle)
Follow **Rule D (Surgical Edits & Anti-Laziness)**, **Rule E (English Code)**, **Rule F (Verification & Honest Oracles)**, **Rule J (Solution Integrity & Anti-Masking)**.

> **Ownership Perimeter & Scope Guard (`OWNS:`):**
> - **Internal Boundary Freedom:** Full authority to create new files (`[NEW]`), modify, or delete files matching the declared `OWNS:` globs.
> - **Permitted External Surgical Edits (Rule D):** Files outside `OWNS:` may ONLY be touched for:
>   1. *Root Wiring & Registrations:* Central service DI registration (`Program.cs`, `app.module.ts`), route tables, or sample env configs (`.env.example`).
>   2. *Contract & Signature Cascade:* Surgical caller/consumer updates directly broken by a contract, interface, or DTO change introduced in this phase to guarantee global compilation/tests remain green.
> - **Prohibited External Edits:** Unsolicited feature expansions, unsolicited refactoring, or logic redesign in foreign modules.
> - **Deviation Transparency:** Every modification outside `OWNS:` must be explicitly documented with rationale and clickable file links in `walkthrough.md`.

> **Ground-Truth Gate (Rule I):** Before writing code that depends on existing signatures, types, or patterns, verify the actual current state of target files — never code against assumptions from memory or stale context. If actual state diverges from the spec or plan, adapt the implementation approach to match reality and note the deviation in the walkthrough.

> **Iterative Loop Rule:** Continuously iterate through the tactical verification gates (Steps 2.0 – 2.5: *Detect/Fail -> Surgical Patch -> Re-verify*) across all four engineering passes until **100% of machine acceptance gates (`CHECK:` + `EXPECT:`), build checks, and full regression suites are green** before advancing to Phase II.

> **4-Pass Engineering Execution Structure:**
> Guide the iterative loop through four qualitative stages instead of stopping on the first rough green test:
> - **Pass 1 (Complete Deliverable):** Implement 100% of required logic, schemas, and tests. ZERO placeholders (`// TODO`, `/* implement later */`), zero stubbed mocks in production code, zero unhandled branches.
> - **Pass 2 (Senior / Expert Re-read & Anti-Cheapening):** Actively search for and replace "cheap" naive implementations (e.g., naive O(N^2) loops, un-buffered I/O, missing retry/timeout policies, loose typing, missing defensive guards).
> - **Pass 3 (Defect, Concurrency & Boundary Hunt):** Stress-test boundary conditions, cancellation tokens (`CancellationToken` / `AbortController`), race conditions, memory pressure, and cross-platform portability (Windows vs POSIX paths).
> - **Pass 4 (Low-Cost Polish & Oracle Sealing):** Run and seal all declared machine-checkable gates (`CHECK:` + `EXPECT:`). Verify exit code 0 and decisive output markers.

#### Tactical Verification Gates (Steps 2.0 – 2.5):
- **2.0 Dependency Installation Gate:** If new packages are needed, request user confirmation (**Rule C**) specifying name, version, and reason.
- **2.1 Build & Lint Gate:** Run compilation, typechecking, and linters. Fix all errors/warnings before proceeding.
- **2.2 Balanced Testing & Live Execution (Unit Coverage + Live Seam Check):**
  - *Targeted Unit Test Coverage (Rule F):* Proactively write fast, focused unit tests covering new public APIs, logical branches, domain logic, and error paths. Structure tests at public seams and pure logic; avoid brittle multi-layered mock chains that test implementation details.
  - *Fast Inner Loop & Output Scoping (Rule H):* Run targeted tests for minimal changes (`dotnet test --filter`, `pytest :: -q`, `npm test -t -- --bail`, `cargo test -- -q`). Always apply quiet or failure-focused flags to suppress passing markers and avoid context bloat while preserving failure traces. Run full module suites for broad changes. In **Batch Queue Mode**, quiet flags are MANDATORY across all phases to preserve context window longevity and prevent token exhaustion.
  - *Targeted Live Execution (Rule of One):* In addition to unit tests, execute at least **one linear real run** of the modified entry point (CLI command with realistic arguments, API request, or script) to verify runtime wiring, DI, configuration, and serialization without constructing heavy E2E test frameworks.
- **2.3 Machine Acceptance Gates Execution (`CHECK:` + `EXPECT:`):**
  - Execute every runnable oracle defined in the phase spec.
  - A gate passes ONLY when the process exits with code 0 AND the combined stdout/stderr matches `EXPECT:`.
  - **Honest Oracles Rule:** If a negative assertion is made, verify that it fails when the flaw is introduced (positive control). Fixed-output commands (`echo ok`) are strictly invalid.
- **2.4 Visual & Document Verification (Conditional — UI, PDF, DOCX, HTML, Images):**
  - Render output to PNG using Windows CLI (`pdftoppm`, LibreOffice headless CLI, Playwright) or Python fallback (`pymupdf`/`fitz`, `pdf2image`).
  - Visually inspect via multimodal vision (margins, alignment, typography, line wraps). Fix visual flaws iteratively.
- **2.5 Schema, State, Config & Full Regression Gate:**
   - Verify ORM migrations (EF Core, Flyway, Liquibase, Drizzle, Prisma, Alembic) and client bindings.
   - **Configuration & Env Sync (Rule D):** When introducing or altering environment variables or configuration keys, ensure `.env.example`, `appsettings.json` templates, and setup docs are strictly synchronized.
   - **Cross-Layer Contract Integrity:** When modifying Domain Entities or DTOs, verify cascading impact across mapping layers, API controller return types, OpenAPI schemas, and frontend client interfaces.
   - **Data Access Hotpath Audit:** Verify zero N+1 queries (no DB/API calls inside loops — use batch operations, projection queries, or eager includes). For new filtered queries or FK joins, ensure corresponding composite index migrations exist.
   - **Pagination Guard:** For datasets potentially exceeding 10K rows, enforce keyset/cursor-based pagination over OFFSET/SKIP.
   - Run full test suite and global build to ensure zero regressions in unaffected modules.
- **2.6 Scope Creep & Complexity Circuit Breaker:**
  - If during implementation a phase is discovered to contain hidden architectural obstacles, unmanageable blast radius, or requires splitting into sub-tasks, halt and suggest running `/investigate <phase>` to break it down into atomic sub-phases (`01a`, `01b`).

---

### Step 3: Phase II — Strategic Architectural Review
*Executes ONLY when Phase I is 100% green.*

1. **Bidirectional Diff Reconciliation (Forward & Backward Audit):**
   - *Forward Audit (Completeness):* 100% of the DoD, acceptance criteria, and edge cases are implemented.
   - *Backward Audit (Scope Control):* 0% unrequested edits, unsolicited refactorings, or side-effects in `git diff` (**Rule D**).
2. **Holistic Self-Audit:**
   - *SOLID & Cleanliness:* Production-ready, maintainable, no hacky workarounds.
   - *Security & Performance:* No leaks, concurrency hazards, unclosed handles, or bottlenecks.
3. **Oracle Integrity & Honest Failure Audit:**
   - Verify that all runnable gates passed genuinely and are capable of failing (no fixed-output emitters, no tautological assertions).
   - For negative assertions, ensure positive controls exist and were verified.
4. **Clean Context Review Gate (Subagents & `/review`):**
   - Self-audit is necessary for immediate bug catching, but prone to anchoring bias. For thorough security, contract, and multi-phase audits, delegate review to an isolated clean subagent or trigger a decoupled `/review` session passing only the task specs and uncommitted diff (`git diff HEAD` — capturing unstaged or manually staged changes).
5. **Revert vs. Patch (Rule J):**
   - *Minor issues:* Apply targeted patches and re-verify in Step 2.
   - *Fundamental architectural flaws / Dead-ends:* Perform a targeted self-revert of affected uncommitted files (via surgical code replacement or file-scoped `git checkout -- <file>`, preserving unrelated changes) and re-implement cleanly. Never stack hacks on a broken foundation (**Rule J: Revert Over Stack**).

---

### Step 4: Delivery & Artifacts
1. **Unstaged Working Tree Delivery (User Review Gate):**
   - After Phase I & II verification passes for a given phase/sub-phase, keep all verified modified and new files unstaged in the working tree.
   - NEVER run `git add` automatically. All staging and committing are strictly user-driven — always leave verified changes unstaged in the working tree for user inspection.
   - Unstaged working tree modifications remain cleanly trackable via `git status -s` and diff extraction (`git diff HEAD`, or `git diff --staged` if staged manually by the user) during subsequent Milestone/Final `[QA]` reviews.
2. **Pre-Report Audit Gate & Walkthrough Hygiene (`walkthrough.md`):**
   - **Mandatory Metric Remeasurement:** Re-measure test counts, coverage, and performance benchmarks directly from execution output—never echo numbers from prompts or memory.
   - **Contract Traceability Verification:** Verify that 100% of the active phase's deliverables and requirements in `00_overview.md` Contract Inventory are accounted for.
   - **Terminal Handoff Protocol:** If a gate or requirement is blocked or impossible within scope, mark `[ABANDONED] <gate-id>: <concrete reason>` and report `HANDOFF REQUIRED` instead of claiming full completion.
   - **Walkthrough Format:** Summary of changes, empirical verification proof (test logs / rendered visuals), and architectural notes. Format all referenced code symbols with clickable line-range links (`[Symbol](file:///path#L10-L25)`). For multi-step UI or visual diff progressions, utilize ````carousel```` blocks to condense vertical space. Verify `git status` to ensure zero leftover scratch/dump files in the workspace.
3. **Phase / Sub-Phase Tracking & Handoff:**
   - *When using `/investigate` tasks:* Mark phase/sub-phase acceptance criteria `[x]`, update `00_overview.md` status (for main phases `01` or sub-phases `01a`) from `[>] In Progress` to `[x] Completed`.
   - **Single-Phase Mode Handoff:**
     - If next phase/sub-phase (`[ ] Pending`) exists:
       - **Cross-Phase Drift Check:** verify that its prerequisites, target files, and interface contracts still match the actual implementation (which may have deviated from the original spec). If discrepancies exist, update the next phase spec to reflect reality.
       - **Automated Next Phase (`[CODE]`, `[DATA]`):** Provide clickable link and ready `/implement <next-phase>` command.
       - **Next Phase `[QA]` (Milestone / Final Review):** Clearly state the cumulative list of covered phases (e.g., `01`, `02`), provide clickable link and ready `/implement <next-qa-phase>` command (which executes cumulative oracle re-verification, doc sync, and triggers clean-context `/review`).
       - **Manual Next Phase (`[MANUAL/DEVOPS]`):** Present portal navigation guide, cloud checklist, and output variables, then prompt user to complete manual steps before proceeding to dependent code phases.
   - **Batch Queue Mode Pipeline Loop (Decoupled Turn Protocol & 30s Reactive Timer):**
      - After verifying current phase, emit a compact Phase Checkpoint Summary in chat:
        ```markdown
        ### ✅ [CHECKPOINT {i}/{N}] Phase {phase_id} Completed: {name}
        - Files: [Modified files with clickable links]
        - Verification: Build & tests 100% green (quiet mode)
        - Overview Status: [x] Completed in 00_overview.md
        ```
      - **Next Phase Barrier & Transition Guard:**
        - **Hard Phase Barrier & Immediate Stop:**
          - The moment a phase's acceptance gates are verified and marked `[x] Completed` in `00_overview.md`, calling ANY tool other than `schedule` (or read-only git status) is STRICTLY PROHIBITED.
          - You MUST emit the Phase Checkpoint Banner (`### ✅ [CHECKPOINT {i}/{N}] ...`), emit the Queue Countdown Banner, schedule the 30s timer, and CEASE ALL TOOL CALLS immediately to end the turn.
          - Chaining into the next phase within the same assistant turn without explicit `--immediate` / `--no-delay` flag is a critical protocol deviation.
        - **Manual / DevOps Barrier:** If the next item in the queue is `[MANUAL/DEVOPS]`:
          - **HALT queue immediately.**
          - Output portal navigation checklist, CLI instructions, and required output secrets.
          - Prompt user: *"Queue paused at Phase {X} due to manual cloud/DevOps prerequisites. Complete steps and resume with `/implement all` (or `/implement <phase>`)."*
          - Safely end turn (do not schedule a timer).
        - **Queue Exhaustion (Completion):** If all phases in the queue are completed and no pending/QA phases remain, emit a comprehensive queue completion report and safely end turn.
        - **Automated Next Phase Advance (`[CODE]`, `[DATA]` or `[QA]`):**
          - Perform **Cross-Phase Drift Check** on next phase spec.
          - **Immediate Mode Override:** If explicitly invoked with `--immediate`, `--no-delay`, or conversational equivalent in active language (e.g., "without delay", "no delay", "immediately"): advance directly to the next phase within the same turn.
          - **Default: 30s Decoupled Turn Boundary (Reactive Timer):**
            1. Emit Queue Countdown Banner in chat:
               ```markdown
               ⏳ [QUEUE TIMER: 30s] Phase {phase_id} complete. Advancing to Phase {next_phase_id} ({next_name}) in 30 seconds...
               - Review changes, git diff, or test output in the IDE.
               - Run immediately: `/implement {next_phase_spec}`
               - Type any prompt to pause/adjust, or wait for automated wake-up.
               ```
            2. Schedule one-shot 30-second watchdog timer:
               - For code/data phases:
                 `schedule(DurationSeconds="30", Prompt="[BATCH QUEUE {i+1}/{N}] /implement: Execute workflow /implement for phase: {next_phase_spec}. View workflow /implement file (see path in <workflows>) and follow all Tactical Loop passes and DoD oracles.", TimerCondition="any")`
               - For final QA phase:
                 `schedule(DurationSeconds="30", Prompt="[BATCH QUEUE FINAL] /implement: Execute workflow /implement for phase: {next_phase_spec}. View workflow /implement file (see path in <workflows>), follow Step 4 cumulative QA verification, re-verify all covered phase DoD oracles, sync documentation, and trigger clean-context /review.", TimerCondition="any")`
            3. **MANDATORY TURN END:** Cease tool calling immediately and end turn. This flushes the complete phase output and checkpoint to the user's chat UI as a clean, isolated message.
          - **Reactive Turn Wakeup (On Timer Expiry or User Prompt):**
            - The timer notification wakes up the agent in a **fresh, independent assistant turn**. The agent immediately views the `/implement` workflow file (resolving its path from `<workflows>` in system instructions, or local workspace copy if present) to execute the target phase specification under full Auto-Verify discipline.
            - Announce phase start banner:
              ```markdown
              ### 🚀 [QUEUE STEP {i+1}/{N}] Advancing to Phase: {next_phase_id}_{name}.md
              ```
            - If target phase is `[QA]`: consult and execute `{next_phase_spec}` under Step 4: execute **Cumulative Oracle Re-verification** (re-running all runnable acceptance gates across all completed phases to prove zero regressions), run full regression test suite, sync affected project documentation (`README.md`, ADRs, API specs), and trigger clean-context `/review`.
            - If target phase is `[CODE]`/`[DATA]`: re-enter Steps 1.3 -> 2 -> 3 for the specified phase.
   - *Standalone tasks:* Mark completed items in `task.md` or present a clean walkthrough summary.
4. **User Summary:** Concise summary in user's conversational language (**Rule A**).
5. **Context Hygiene Gate:** If 5+ phases/sub-phases have been completed and verified in the current session, proactively suggest `/checkpoint` to preserve progress before context degradation impacts quality.

---

## Circuit Breaker
- **Progress-Driven Persistence:** Continue iterations as long as measurable progress is made (failing test count steadily decreasing, narrowing defect blast radius).
- **Stagnation Stop & Queue Halt:** If an error, failing test, or defect persists after **3–4 iterations without progress** (flapping tests, circular errors, zero defect reduction):
  - In Single Mode: halt immediately, summarize root blocker, reproduction steps, attempted fixes, and request user guidance.
  - In Batch Queue Mode: **HALT the entire queue immediately**. Do not attempt subsequent phases. Report RCA, failing test output, and exact defect location, then request user guidance.
