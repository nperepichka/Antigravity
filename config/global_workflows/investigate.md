---
description: Deep task investigation, architecture discovery, greenfield scaffolding planning, and atomic sub-task decomposition (automated coding + manual cloud/DevOps runbooks).
---

# Task Investigation & Decomposition Loop

Exploratory analysis of complex tasks, architecture designs (HLD/ADR/PDF), or project specifications without modifying production code. Generates self-contained sub-task specifications for automated implementation and manual cloud/DevOps setups.

---

## Core Directives
- **Read-Only Safety:** ZERO code modifications, destructive commands, or package installs. Only analysis and markdown specification generation.
- **Self-Contained Isolation:** Every sub-task file must contain complete context (paths, signatures, constraints, cloud steps, DoD) for isolated execution.

---

## Workflow Steps

### Step 1: Ingestion & Directory Setup
1. **Ingest Requirements:** Parse prompts, task files (`task.md`, `specs/*.md`, `ADR.md`), or **PDF documents** (architectural designs, topologies, wireframes).
2. **Project State:** Classify as **Greenfield** (new setup, scaffolding, infra) or **Brownfield** (existing project, impact & compatibility analysis).
3. **Directory Target:** Create `.local/tasks/<YYYY-MM-DD>_<task-slug>/` at project root.

---

### Step 2: Architecture Discovery & Skill Assessment
1. **Brownfield Discovery:** Trace symbols/flows via `grep_search` and range-limited `view_file` (`DB -> Domain -> API -> UI`). Assess schema impact, breaking risks, and existing test suites/coverage.
2. **Greenfield / HLA Discovery:** Synthesize runtimes, DBs, message queues, auth providers (Entra ID, Auth0, Cognito), 3rd-party APIs (Stripe, Twilio, SendGrid), and cloud topology (Azure, AWS, GCP).
3. **Skill Gap Discovery & Security Guard:**
   - Check active workspace (`.agents/skills/`) and global (`~/.gemini/config/skills/`) skills.
   - Cross-reference curated repositories:
     - `https://github.com/benjaminasterA/antigravity-awesome-skills` (Curated Antigravity skills)
     - `https://github.com/sickn33/antigravity-awesome-skills` (Engineering, security & ops library)
     - `https://github.com/VoltAgent/awesome-agent-skills` (Vendor-vetted specialized capabilities)
     - `https://github.com/ZhangYu-zjut/awesome-Antigravity` (Workflows & best practices)
   - Dynamic search if specialized: `search_web` for `"<domain> skill antigravity" site:github.com` or `"SKILL.md" "<tech>"`.
   - **Skill Security Guard:** Audit `SKILL.md` before recommending (no unauthorized network calls or unsafe scripts). Recommend 1–3 vetted skills in `00_overview.md`.

---

### Step 3: Phase Classification & DAG Decomposition
Decompose into minimally coupled, logically cohesive phases with rigorous DoDs:

1. **`[CODE]` (Automated Dev):** Domain models, migrations, business logic, APIs, tests, UI.
2. **`[MANUAL/DEVOPS]` (Cloud/Infra):** Cloud provisioning, portal config, OAuth/IdP app registration, DNS/SSL, secret vaults (Key Vault, Secrets Manager), webhooks.
3. **`[DATA]` (Data Migrations):** Idempotent transformations/backfills (`IF NOT EXISTS`, transactional) with rollback scripts and validation queries.
4. **`[QA]` (E2E Verification & `/review`):**
   - Integration/E2E test suites, performance benchmarks, and security checks.
   - **Mandatory `/review` Integration:** Audit feature diff with `/review`. Triage `🔴 Must Fix` / `🟡 Should Fix` with surgical patches until `🟢 APPROVED`.
   - **Milestone QA Scheduling:** For large plans, insert a dedicated `[QA]` phase after each cohesive group of phases (e.g., Core Models -> `[QA]`, APIs -> `[QA]`, Full UI -> `[QA]`).
5. **DAG Validation & Shared Contracts:** Validate acyclic order (DAG). Extract shared cross-cutting concerns (auth, logging, config) into prerequisite phases or document in `00_overview.md`.

---

### Step 4: Specification File Generation

#### 4.1 Master Plan (`00_overview.md`)
- **System Architecture & Context:** Solution summary + Mermaid diagrams.
- **Recommended Agent Skills:** Table (Name, Category, Repo URL, Scope [Workspace vs Global], Justification).
- **Execution Matrix (DAG):** Table (Phase ID, Name, Type, Dependencies, Complexity, Status: `[ ] Pending`, `[>] In Progress`, `[x] Completed`, `[!] Blocked`).
- **Environment & Config Matrix:** Keys, descriptions, types, and placeholder values for Local/Staging/Prod.
- **Shared Data Contracts:** DTO schemas, interfaces, event payloads.

#### 4.2 Phase Files (`01_<name>.md`, `02_<name>.md`, ...)
Use the corresponding structured template (all in **English**):

- **Template A `[CODE]`:** Objective & Scope (`Goal` / `In Scope` / `Out of Scope`) -> Prerequisites & Dependencies -> Target Files & Symbols (`[NEW/MODIFY/DELETE]`) -> Context & Interface Snippets -> Implementation Instructions -> Definition of Done (build/test commands + checklist).
- **Template B `[MANUAL/DEVOPS]`:** Objective & Overview -> Step-by-Step Portal Navigation Guide -> Alternative CLI/IaC Commands -> Secrets & Output Variables Checklist -> Verification & Connectivity Test.
- **Template C `[DATA]`:** Objective & Scope -> Prerequisites -> Idempotent Migration Script (with rollback & transactions) -> Validation Queries -> Definition of Done.
- **Template D `[QA]`:** Objective & Scope -> Test Environment Setup -> Test Scenarios -> Execution Commands -> Automated Code Review Gate (`/review`) -> Triage & Remediation Protocol -> Definition of Done.

---

### Step 5: Review & Delivery
1. All generated specifications MUST be in **English** (**Rule E**).
2. Summarize findings, skill recommendations, and phase structure in user's language (**Rule A**).
3. Provide clickable markdown links to `00_overview.md` and phase files.
4. Highlight trade-offs, open questions, skill install requests (**Rule C** confirmation), and manual prerequisites.
