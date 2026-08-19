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
2. **Task Ingestion & Planning Mode:**
   - **Input Formats:** Prompts, issues, task files (`task.md`, `prompt.md`, `specs/*.md`), PDFs, or `/investigate` phase files (`01_<name>.md`).
   - **Fast-Track (`/investigate` specs):** If prerequisites are met, **adopt Scope, Target Files, Context Snippets, and DoD directly as the approved plan** and skip to Step 2.
   - **Standard Complex / Greenfield:** Formulate `implementation_plan.md` (**Rule B**) and obtain user approval.
   - **Minor / Straightforward:** Proceed directly to Step 2.

---

### Step 2: Phase I — Tactical Development Loop
Follow **Rule D (Surgical Edits)**, **Rule E (English Code)**, **Rule F (Verification)**. Strict **Scope Guard:** Never touch files listed under `Out of Scope`.

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

---

### Step 3: Phase II — Strategic Architectural Review
*Executes ONLY when Phase I is 100% green.*

1. **Holistic Self-Audit:**
   - *Completeness:* All explicit/implicit requirements and edge cases handled?
   - *SOLID & Cleanliness:* Production-ready without hacky workarounds?
   - *Surgical Scope:* Minimal diff respected; stayed within in-scope boundaries?
   - *Security & Performance:* No memory leaks, concurrency hazards, unclosed handles, or bottlenecks?
2. **Revert vs. Patch:**
   - *Minor issues:* Apply targeted patches and re-verify in Step 2.
   - *Fundamental architectural flaws:* Revert affected components and re-implement cleanly. Never stack hacks on a broken foundation.

---

### Step 4: Delivery & Artifacts
1. **Walkthrough & Hygiene (`walkthrough.md`):** Summary of changes, verification proof (test logs / rendered visuals), and architectural notes. Verify `git status` to ensure zero leftover scratch/dump files in the workspace.
2. **Phase Tracking & Handoff (Investigate Tasks):** Mark phase acceptance criteria `[x]`, update `00_overview.md` status from `[>] In Progress` to `[x] Completed`. If next phase (`[ ] Pending`) exists, provide clickable link and ready `/implement` command.
3. **User Summary:** Concise summary in user's conversational language (**Rule A**).

---

## Circuit Breaker
If an error, failing test, or rendering defect persists after **4–5 iterations**, halt immediately. Summarize root blocker, reproduction steps, and attempted fixes, then request user guidance.
