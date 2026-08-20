---
description: Autonomous development, compilation, testing, visual document verification, and strategic review cycle across multi-stack projects (.NET, Java, JS/TS/Bun, Python, Rust, Go) for existing and greenfield repositories.
---

# Auto-Verify Dev Loop

Autonomous two-phase engineering cycle: **Phase I (Tactical Verification)** + **Phase II (Strategic Review)**.

---

## Workflow Steps

### Step 1: Toolchain Detection & Task Alignment
1. **Stack & Toolchain Detection:**
   - **.NET:** `*.csproj`, `*.sln` -> `dotnet build`, `dotnet test`
   - **Java:** Maven `pom.xml` -> `.\mvnw.cmd` / `./mvnw` `compile`/`test`; Gradle `build.gradle[.kts]` -> `.\gradlew.bat` / `./gradlew` `build`/`test`/`check`
   - **JS / TS (Bun/Node/PNPM/Yarn):** `package.json`, lockfiles -> inspect `scripts` (`typecheck`, `lint`, `test`, `build`)
   - **Python:** `pyproject.toml`, `uv.lock`, `requirements.txt` -> `pytest`, `ruff check`, `mypy`/`pyright`
   - **Rust:** `Cargo.toml` -> `cargo check`, `cargo test`, `cargo clippy`
   - **Go:** `go.mod` -> `go build ./...`, `go test ./...`, `golangci-lint run`
   - **Greenfield:** Scaffold standard layout, dependency definitions, and initial configs.
   - **Monorepo:** (`nx`, `turbo`, `lerna`, `pnpm-workspace`) Scope build/test/lint commands to affected package.
   - **Conditional Baseline Sanity Check:** At the very start of a session or when working in an unfamiliar/unverified environment (only when necessary, do not repeat across consecutive phase runs), run a quick baseline build/test to ensure the repo is green prior to edits. If broken, warn user upfront.
2. **Task Ingestion & Skill Alignment:**
   - **Input Formats:** Prompts, issues, standalone task files (`task.md`, `prompt.md`, `specs/*.md`), PDFs, or `/investigate` phase/sub-phase files (`01_<name>.md`, `01a_<name>.md`).
   - **Skill Ingestion:** Check `00_overview.md`, task specifications, or stack requirements for recommended agent skills and activate them if available.
   - **Fast-Track (`/investigate` specs):** If prerequisites are met, **adopt Scope, Target Files, Context Snippets, and DoD directly as the approved plan** and skip to Step 2.
   - **Standalone Complex / Greenfield:** Formulate `implementation_plan.md` (**Rule B**) and obtain explicit user approval.
   - **Minor / Straightforward:** Proceed directly to Step 2.

---

### Step 2: Phase I — Tactical Development Loop
Follow **Rule D (Surgical Edits)**, **Rule E (English Code)**, **Rule F (Verification)**. Strict **Scope Guard:** Never touch files listed under `Out of Scope`.

> **Ground-Truth Gate (Rule I):** Before writing code that depends on existing signatures, types, or patterns, verify the actual current state of target files — never code against assumptions from memory or stale context. If actual state diverges from the spec or plan, adapt the implementation approach to match reality and note the deviation in the walkthrough.

> **Iterative Loop Rule:** Iterate through steps 2.0 – 2.4 (*Detect/Fail -> Surgical Patch -> Re-verify*) until **all checks are 100% green** before moving to Phase II.

- **2.0 Dependency Installation Gate:** If new packages are needed, request user confirmation (**Rule C**) specifying name, version, and reason.
- **2.1 Build & Lint:** Run compilation, typechecking, and linters. Fix all errors/warnings before proceeding.
- **2.2 Automated Testing & Live Execution:**
  - *Fast Inner Loop:* Run targeted tests for minimal changes (`dotnet test --filter`, `pytest ::`, `npm test -t`, `cargo test`). Run full module suites for broad changes.
  - *Live Execution:* Execute entry points with realistic inputs. Run long-running servers as background tasks/daemons or via test runners with bounded timeouts.
- **2.3 Visual & Document Verification (Conditional — UI, PDF, DOCX, HTML, Images):**
  - Render output to PNG using Windows CLI (`pdftoppm`, LibreOffice headless CLI, Playwright) or Python fallback (`pymupdf`/`fitz`, `pdf2image`).
  - Visually inspect via multimodal vision (margins, alignment, typography, line wraps). Fix visual flaws iteratively.
- **2.4 Schema, State & Full Regression Gate:**
  - Verify ORM migrations (EF Core, Flyway, Liquibase, Drizzle, Prisma, Alembic) and client bindings.
  - Run full test suite and global build to ensure zero regressions in unaffected modules.
- **2.5 Scope Creep & Complexity Circuit Breaker:**
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
3. **Revert vs. Patch:**
   - *Minor issues:* Apply targeted patches and re-verify in Step 2.
   - *Fundamental architectural flaws:* Revert affected components and re-implement cleanly. Never stack hacks on a broken foundation.

---

### Step 4: Delivery & Artifacts
1. **Walkthrough & Hygiene (`walkthrough.md`):** Summary of changes, verification proof (test logs / rendered visuals), and architectural notes. Verify `git status` to ensure zero leftover scratch/dump files in the workspace.
2. **Phase / Sub-Phase Tracking & Handoff:**
   - *When using `/investigate` tasks:* Mark phase/sub-phase acceptance criteria `[x]`, update `00_overview.md` status (for main phases `01` or sub-phases `01a`) from `[>] In Progress` to `[x] Completed`. If next phase/sub-phase (`[ ] Pending`) exists, **cross-phase drift check:** verify that its prerequisites, target files, and interface contracts still match the actual implementation (which may have deviated from the original spec). If discrepancies exist, update the next phase spec to reflect reality before providing the handoff link and ready `/implement` command.
   - *Standalone tasks:* Mark completed items in `task.md` or present a clean walkthrough summary.
3. **User Summary:** Concise summary in user's conversational language (**Rule A**).
4. **Context Hygiene Gate:** If 5+ phases/sub-phases have been completed and verified in the current session, proactively suggest `/checkpoint` to preserve progress before context degradation impacts quality.

---

## Circuit Breaker
If an error, failing test, or rendering defect persists after **4–5 iterations**, halt immediately. Summarize root blocker, reproduction steps, and attempted fixes, then request user guidance.
