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
Quantify requirements and evaluate steelmanned architectural options before DAG decomposition:

1. **NFR Quantification Gate:**
   - Scan raw requirements for vague statements ("fast", "reliable", "secure", "high load") and convert to hard metrics: p95/p99 latency (ms), target RPS, uptime % / RPO/RTO, concurrent user capacity, compliance standards. Record in `00_overview.md`.

2. **Steelmanned Divergent Options (2–3 Production-Grade Alternatives):**
   - **Strict Anti-Strawman Mandate:** NEVER present dummy, naive, or caricature options (e.g., no throwaway scripts without error handling or unjustified Kafka/microservices). Every option MUST be a realistic, production-viable architecture that a Staff/Principal Engineer would defend in an RFC, solving 100% of functional requirements and quantified NFRs.
   - **Divergence Along Real Trade-off Axes (Tailored to Problem):**
     - *Coupling & Execution:* In-process transactional pipeline (synchronous, direct consistency, zero infra overhead) vs. Asynchronous decoupled pipeline (event-driven, message broker/worker queue, background jobs).
     - *State & Invariants:* Database-native enforcement (ACID, row locks, constraints, atomic CTEs) vs. Application-level domain orchestration (State Machine, Saga, Outbox, rich aggregate roots).
     - *Modularity & Extensibility:* Cohesive vertical slice (minimal indirection, localized logic, rapid DX) vs. Decoupled pluggable architecture (Strategy/Adapter, extensible provider abstractions).
     - *Infrastructure Primitives:* Zero-dependency platform-native primitives vs. Dedicated external managed services (e.g., in-memory locks vs Redis / cloud distributed locks).

3. **Comparative Evaluation Matrix (Mandatory Criteria):**
   - **Completeness & NFR Alignment:** Quality of meeting scale, performance, and functional targets.
   - **Operational Footprint & Cognitive Load:** Dependency burden, infra complexity, long-term maintainability/DX.
   - **Failure Modes & Edge Case Resilience:** Synthesize ≥3 concrete failure scenarios (e.g., duplicate delivery, timeout during mutation, concurrent conflict/race) and assess handling.
   - **Performance & Footprint:** Latency (p95/p99), memory/CPU allocations, connection pools, lock contention.
   - **Blast Radius & Migration Risk:** Impacted modules, schema migration hazards, backward compatibility.
   - **Testability & Determinism:** Ease of isolated, fast unit/integration testing without complex harnesses.

4. **Dialectical Architecture Synthesis (Hybrid Blueprint):**
   - Avoid simplistic winner-picking. Actively synthesize an optimal blueprint:
     - **Strengths Extraction:** Extract the strongest traits of each option (e.g., Option 1's low-latency data path + Option 2's resilient state transition handling).
     - **Layer-by-Layer Decision Matrix:** Map explicit choices across Data/Concurrency, Domain Logic, Resiliency/Retries, and API Contracts.
     - **Target Synthesis Blueprint:** Formulate the unified design (hybrid or justified dominant path) combining strengths and eliminating weaknesses.
     - **Rejection Rationale:** Explicitly document technical grounds for any discarded trade-off (e.g., excessive lock contention, unneeded network hop, operational dependency).

---

### Step 4: Phase Classification & DAG Decomposition
Decompose the task into cohesive phases. Act situationally: for massive tasks, group related features into larger logical phases. For smaller tasks or when breaking down a specific phase, aim for **hyper-granular, atomic sub-phases** (e.g., one sub-phase = one logical PR, such as DB models only, or a single API endpoint).

1. **`[CODE]` (Automated Dev):** Domain models, migrations, business logic, APIs, tests, UI.
2. **`[MANUAL/DEVOPS]` (Cloud/Infra):** Cloud provisioning, portal config, OAuth/IdP app registration, DNS/SSL, secret vaults (Key Vault, Secrets Manager), webhooks.
3. **`[DATA]` (Data Migrations):** Idempotent transformations/backfills (`IF NOT EXISTS`, transactional) with rollback scripts and validation queries.
4. **`[QA]` (E2E Verification, Clean-Context Subagents & `/review`):**
   - Integration/E2E test suites, performance benchmarks, and security checks.
   - **Clean Context & Subagent Gate:** Execute QA and code review with an isolated, fresh context (delegating to a clean subagent or running in a clean session) to eliminate implementation anchoring bias and self-verification blind spots.
   - **Multi-Phase & Cumulative Scope:** Milestone QA and Final QA may audit uncommitted or staged (`git diff --staged` / `git diff HEAD`) code accumulated across multiple preceding sub-phases (`01..03`) or against the base branch (`git diff <base>`), reconciling all covered phase specifications simultaneously.
   - **Mandatory `/review` Integration:** Audit feature diff with `/review`. Triage `🔴 Must Fix` / `🟡 Should Fix` with surgical patches until `🟢 APPROVED`.
   - **Milestone & Final QA:** For large plans, insert a dedicated `[QA]` phase after each cohesive group of phases. **CRITICAL:** The entire master plan MUST always conclude with a final `[QA]` phase. Never skip the final review.
5. **Recursive Decomposition (Sub-phases):** If the user asks to investigate a specific large phase (e.g., `/investigate phase 2`), decompose it into atomic, highly granular sub-phases (e.g., `02a_<name>.md`, `02b_<name>.md`). Each sub-phase must be small enough to be implemented flawlessly by `/implement` (acting as actionable "tracer-bullet" tickets).
6. **Multi-Session Scaling (Frontier vs Fog of War):** For massive chunks of work that span multiple agent sessions, use `00_overview.md` as the shared map:
   - **The Frontier:** The immediate, actionable sub-phases whose prerequisites are settled. Generate full phase markdown files for these.
   - **The Fog of War (Not Yet Specified):** Work that is in-scope but whose exact details depend on the frontier being resolved. Keep these as high-level items in the `00_overview.md` Execution Matrix, but do NOT generate individual phase markdown files for them yet. As the frontier is resolved, graduate this fog into new phase files.
7. **DAG Validation & Shared Contracts:** Validate acyclic order (DAG). Extract shared cross-cutting concerns (auth, logging, config) into prerequisite phases or document in `00_overview.md`.

---

### Step 5: Specification File Generation

#### 5.1 Master Plan (`00_overview.md`)
- **System Architecture & Context:** Solution summary + Mermaid diagrams.
- **Steelmanned Architecture Options & Synthesis:**
  - Table of considered steelmanned approaches (Options A/B/C) evaluated across the 6 mandatory criteria.
  - Layer-by-layer architectural decision mapping (Data/Concurrency, Domain Logic, Resiliency, API Contracts).
  - Detailed rationale for the synthesized target architecture and why specific trade-offs were chosen or rejected.
- **Recommended Agent Skills:** Table (Name, Category, Repo URL, Scope [Workspace vs Global], Justification).
- **Execution Matrix (DAG & Shared Map):** Table (Phase ID, Name, Type, Dependencies, Complexity, Status: `[ ] Pending`, `[>] In Progress`, `[x] Completed`, `[!] Blocked`). For massive projects, demarcate the "Frontier" (live phase files) from the "Fog of War" (unspecified future phases).
- **Out of Scope:** Explicitly list work ruled out of this effort to bound the fog of war.
- **Environment & Config Matrix:** Keys, descriptions, types, and placeholder values for Local/Staging/Prod.
- **Shared Data Contracts:** DTO schemas, interfaces, event payloads.

#### 5.2 Phase Files (`01_<name>.md`, `02_<name>.md`, ...)
Use the corresponding structured template (all in **English**):

- **Template A `[CODE]`:** Objective & Scope (`Goal` / `In Scope` / `Out of Scope`) -> Prerequisites & Dependencies -> Target Files & Symbols (`[NEW/MODIFY/DELETE]`) -> Context & Interface Snippets -> Implementation Instructions -> Definition of Done (build/test commands + checklist).
- **Template B `[MANUAL/DEVOPS]`:** Objective & Overview -> Step-by-Step Portal Navigation Guide -> Alternative CLI/IaC Commands -> Secrets & Output Variables Checklist -> Verification & Connectivity Test.
- **Template C `[DATA]`:** Objective & Scope -> Prerequisites -> Idempotent Migration Script (with rollback & transactions) -> Validation Queries -> Definition of Done.
- **Template D `[QA]`:** Objective & Scope (`Goal` / `Covered Phases: 01, 02..` / `Out of Scope`) -> Target Diff Resolution (`git diff --staged` / `git diff HEAD` / `git diff <base>`) -> Test Environment Setup -> Lean Validation Scenarios (1–3 focused E2E/seam checks + full unit regression suite) -> Independent Verification Gate (`/review` with clean context) -> Triage & Remediation Protocol -> Definition of Done.

---

### Step 6: Review & Delivery
1. All generated specifications MUST be in **English** (**Rule E**).
2. Summarize findings, skill recommendations, and phase structure in user's language (**Rule A**).
3. Provide clickable markdown links to `00_overview.md` and phase files.
4. Highlight trade-offs, open questions, skill install requests (**Rule C** confirmation), and manual prerequisites.
