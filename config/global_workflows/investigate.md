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
1. **Ingest Requirements:** Parse prompts, task files (`task.md`, `specs/*.md`, `ADR.md`), **PDF documents** (architectural designs, topologies, wireframes), meeting transcripts, client briefs, or RFP sections.
2. **Project State:** Classify as **Greenfield** (new setup, scaffolding, infra) or **Brownfield** (existing project, impact & compatibility analysis).
3. **Directory Target:** Create `.local/tasks/<YYYY-MM-DD>_<task-slug>/` at project root.

---

### Step 2: Architecture Discovery & Skill Assessment
1. **Brownfield Discovery:** Trace symbols/flows via `grep_search` and range-limited `view_file` (`DB -> Domain -> API -> UI`). Assess schema impact, breaking risks, and existing test suites/coverage. **Cite only verified paths and signatures in specs — never speculate about file contents or API shapes without inspection (Rule I).**
2. **Greenfield / HLA Discovery:** Synthesize runtimes, DBs, message queues, auth providers (Entra ID, Auth0, Cognito), 3rd-party APIs (Stripe, Twilio, SendGrid), and cloud topology (Azure, AWS, GCP).
3. **Skill Gap Discovery & Security Guard:**
   - Check active workspace (`.agents/skills/`) and global (`~/.gemini/config/skills/`) skills.
   - Cross-reference curated repositories:
     - `https://github.com/benjaminasterA/antigravity-awesome-skills` (Curated Antigravity skills)
     - `https://github.com/sickn33/antigravity-awesome-skills` (Engineering, security & ops library)
     - `https://github.com/VoltAgent/awesome-agent-skills` (Vendor-vetted specialized capabilities)
     - `https://github.com/ZhangYu-zjut/awesome-Antigravity` (Workflows & best practices)
   - Dynamic search if specialized: `search_web` for `"<domain> skill antigravity" site:github.com` or `"SKILL.md" "<tech>"`.
   - **Skill Security Guard:** Audit `SKILL.md` before recommending (no unauthorized network calls or unsafe scripts). Recommend 1–3 vetted skills in `00_overview.md` (provide URL).

---

### Step 3: Mandatory Solution Exploration & Trade-off Synthesis
Before decomposing into phases, quantify requirements and evaluate architectural options:

0. **NFR Quantification Gate (Pre-Architecture):**
   - Scan raw requirements for vague non-functional statements ("fast", "reliable", "secure", "handles high load").
   - Transform each into measurable metrics: p95/p99 latency (ms), target RPS, uptime % with RPO/RTO, concurrent user capacity, compliance standards.
   - Document quantified NFRs in `00_overview.md`.

Evaluate **2–3 distinct architectural approaches / design options** to prevent premature commitments, minimize blast radius, and avoid overengineering:

1. **Divergent Ideation (2–3 Architectural Options):**
   - **Option A (Lightweight / Native / Minimalist):** Minimal/zero new dependencies, native language/platform features, lowest cognitive overhead and minimal diff.
   - **Option B (Pattern-Rich / Extensible / Enterprise):** Established design patterns (Strategy, Pipeline, State Machine, CQRS), battle-tested libraries, high decoupling for future scale.
   - **Option C (Alternative Paradigm):** Alternative execution/storage models (e.g., event-driven vs request-response, streaming vs batch, DB-level constraints vs application-level logic).

2. **Comparative Evaluation Matrix (Mandatory Criteria):**
   - **Requirement Completeness:** Does this option fulfill 100% of functional & non-functional requirements without hacky workarounds?
   - **Anti-Overengineering & Parsimony (KISS / YAGNI):** Is the solution appropriately sized, or does it introduce unnecessary abstractions, premature generalizations, or bloated dependencies?
   - **Blast Radius & Regression Risk:** How many modules, schemas, or existing tests are impacted?
   - **Cognitive Load & DX:** Is the resulting code easy to comprehend, navigate, and debug for other engineers 6+ months from now?
   - **Performance & Resource Footprint:** Latency, CPU/memory allocations, throughput, and connection/lock overhead.
   - **Testability:** Ease of writing isolated, deterministic unit and integration tests.
   - **Edge Case & Failure Mode Coverage:** For features involving payments, webhooks, file uploads, or third-party APIs, synthesize ≥3 failure scenarios (duplicate delivery, timeout during state mutation, concurrent state conflicts) and evaluate each option's resilience.

3. **Decision & Hybrid Synthesis Gate:**
   - Select either a clear winning option OR synthesize a **Hybrid Approach** combining the strengths of multiple options (e.g., lightweight native interfaces from Option A + robust error handling / resilience policies from Option B).
   - Formulate clear architectural justification and document it in the master plan.

---

### Step 4: Phase Classification & DAG Decomposition
Decompose the task into cohesive phases. Act situationally: for massive tasks, group related features into larger logical phases. For smaller tasks or when breaking down a specific phase, aim for **hyper-granular, atomic sub-phases** (e.g., one sub-phase = one logical PR, such as DB models only, or a single API endpoint).

1. **`[CODE]` (Automated Dev):** Domain models, migrations, business logic, APIs, tests, UI.
2. **`[MANUAL/DEVOPS]` (Cloud/Infra):** Cloud provisioning, portal config, OAuth/IdP app registration, DNS/SSL, secret vaults (Key Vault, Secrets Manager), webhooks.
3. **`[DATA]` (Data Migrations):** Idempotent transformations/backfills (`IF NOT EXISTS`, transactional) with rollback scripts and validation queries.
4. **`[QA]` (E2E Verification & `/review`):**
   - Integration/E2E test suites, performance benchmarks, and security checks.
   - **Mandatory `/review` Integration:** Audit feature diff with `/review`. Triage `🔴 Must Fix` / `🟡 Should Fix` with surgical patches until `🟢 APPROVED`.
   - **Milestone & Final QA:** For large plans, insert a dedicated `[QA]` phase after each cohesive group of phases. **CRITICAL:** The entire master plan MUST always conclude with a final `[QA]` phase. Never skip the final review.
5. **Recursive Decomposition (Sub-phases):** If the user asks to investigate a specific large phase (e.g., `/investigate phase 2`), decompose it into atomic, highly granular sub-phases (e.g., `02a_<name>.md`, `02b_<name>.md`). Each sub-phase must be small enough to be implemented flawlessly by `/implement`.
6. **DAG Validation & Shared Contracts:** Validate acyclic order (DAG). Extract shared cross-cutting concerns (auth, logging, config) into prerequisite phases or document in `00_overview.md`.

---

### Step 5: Specification File Generation

#### 5.1 Master Plan (`00_overview.md`)
- **System Architecture & Context:** Solution summary + Mermaid diagrams.
- **Architecture Decisions & Trade-off Synthesis:** Mandatory comparative table of considered approaches (Options A/B/C), scores against criteria (Completeness, Anti-Overengineering, Blast Radius, DX, Performance, Testability), and detailed rationale for the chosen or hybrid path.
- **Recommended Agent Skills:** Table (Name, Category, Repo URL, Scope [Workspace vs Global], Justification).
- **Execution Matrix (DAG):** Table (Phase ID, Name, Type, Dependencies, Complexity, Status: `[ ] Pending`, `[>] In Progress`, `[x] Completed`, `[!] Blocked`).
- **Environment & Config Matrix:** Keys, descriptions, types, and placeholder values for Local/Staging/Prod.
- **Shared Data Contracts:** DTO schemas, interfaces, event payloads.

#### 5.2 Phase Files (`01_<name>.md`, `02_<name>.md`, ...)
Use the corresponding structured template (all in **English**):

- **Template A `[CODE]`:** Objective & Scope (`Goal` / `In Scope` / `Out of Scope`) -> Prerequisites & Dependencies -> Target Files & Symbols (`[NEW/MODIFY/DELETE]`) -> Context & Interface Snippets -> Implementation Instructions -> Definition of Done (build/test commands + checklist).
- **Template B `[MANUAL/DEVOPS]`:** Objective & Overview -> Step-by-Step Portal Navigation Guide -> Alternative CLI/IaC Commands -> Secrets & Output Variables Checklist -> Verification & Connectivity Test.
- **Template C `[DATA]`:** Objective & Scope -> Prerequisites -> Idempotent Migration Script (with rollback & transactions) -> Validation Queries -> Definition of Done.
- **Template D `[QA]`:** Objective & Scope -> Test Environment Setup -> Test Scenarios -> Execution Commands -> Automated Code Review Gate (`/review`) -> Triage & Remediation Protocol -> Definition of Done.

---

### Step 6: Review & Delivery
1. All generated specifications MUST be in **English** (**Rule E**).
2. Summarize findings, skill recommendations, and phase structure in user's language (**Rule A**).
3. Provide clickable markdown links to `00_overview.md` and phase files.
4. Highlight trade-offs, open questions, skill install requests (**Rule C** confirmation), and manual prerequisites.
