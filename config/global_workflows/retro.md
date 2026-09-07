---
description: Automated retrospective audit of active session, root-cause artifact gap analysis, and scope-bifurcated optimization prompt generation (.local/retro/).
---

# Active Session Retrospective & Optimization Loop

Autonomous mechanism to perform a forensic audit of the active dialogue session. Parses session history and transcripts, extracts friction points (user corrections, tool errors, rule ambiguities, and hallucinations), analyzes root causes against project governance artifacts (rules, workflows, skills), and synthesizes a structured report and ready-to-use execution prompt into **`.local/retro/retro-local-<N+1>.md`** and/or **`.local/retro/retro-global-<N+1>.md`** (or confirms clean execution with zero disk artifacts).

---

## Core Directives

- **Strict Read-Only Guarantee:** Never alters application source code, project rules, or workflows directly during execution. Operates solely by inspecting session history and generating `.local/retro/retro-local-<N+1>.md` and/or `.local/retro/retro-global-<N+1>.md` (when friction is detected).
- **Dual-Tier Forensic Analysis:** Prioritizes in-context message history for immediate turns; leverages targeted inspection of `<appDataDir>\brain\<conversation-id>\.system_generated\logs\transcript.jsonl` when session depth exceeds 10 turns or context truncation is detected.
- **Scope Bifurcation & Governance Boundaries:**
  - *Local Project Scope (`retro-local-<N>.md`):* Project source code (`src/**`, `app/**`), project-level `.agents/rules/repository-context.md`, project-level `.agents/skills/`, application-under-test agent prompts/processors, local Docker/CI configs.
  - *Global Governance Scope (`retro-global-<N>.md`):* Universal polyglot boundaries in `GEMINI.md`, global workflows (`config/global_workflows/*.md`), global IDE skills.
- **Anti-Rule-Bloat Governance:** `GEMINI.md` is strictly reserved for universal, cross-cutting engineering boundaries that apply equally across all programming languages (.NET, TS, Python, Go, Rust). Never promote application-level agent dialogue quirks, third-party library behaviors, or project-specific REST endpoints to `GEMINI.md`.
- **Root Cause Taxonomy (5 Categories):** Classify every detected issue into:
  1. `MISSING_RULE`: Action or situation was completely ungoverned by existing rules or workflows.
  2. `AMBIGUOUS_RULE`: Existing rule allowed conflicting, subjective, or underspecified interpretations.
  3. `CONFLICTING_RULES`: Two or more instructions in rules/workflows contradicted each other.
  4. `SKILL_DEFICIT`: Repetitive complex engineering task lacked specialized capability instructions.
  5. `AGENT_DEVIATION`: Existing rule was explicit, concrete, and unambiguous, but the agent failed to adhere to it (model lapse). *(Note: If the lapse stemmed from an uncodified senior expectation rather than an explicit verbatim rule, reclassify as `MISSING_RULE` or `AMBIGUOUS_RULE` to ensure actionable remediation).*
- **Minimal Intervention & Token Density Guard (Rule H):** Strictly prevents rule bloat while eliminating remediation gaps. Pure compliance lapses of already explicit, concrete rules are flagged without adding redundant rules. Every genuine friction point in Section 1 must have an actionable proposed rule in Section 2, OR an explicit justification explaining why codification is counterproductive. Proposed rules for `GEMINI.md` must strictly adhere to the Token Density Guard: **15–25 words per directive**, telegraphic imperative style, zero conversational fluff.
- **Zero Duplicate Invariant:** Never create alias files (`latest.md`, `latest-local.md`). Sequential version numbers (`retro-local-1.md`, `retro-global-1.md`) are the sole sources of truth.
- **Selective Generation Invariant:** If a session only encounters project-specific issues, generate ONLY `retro-local-<N>.md`. If only global engine issues, generate ONLY `retro-global-<N>.md`. Generate both ONLY when both scopes have genuine friction.
- **Workspace Staging Override:** If running within a workspace that serves as a local staging copy of configuration assets (containing `GEMINI.md`, `config/global_workflows/`, etc.), all proposed changes and target paths MUST resolve to the local workspace copies directly — regardless of whether session history or transcripts referenced external global paths (`~/.gemini/`).
- **Dual-Language Invariant:** Analysis, output report, and execution prompt in `.local/retro/` are strictly in **English** (**Rule E**); conversational user handoff adheres to the user's active language (**Rule A**).
- **Clean Session Invariant (Zero-Artifact):** If zero friction, tool errors, or rule ambiguities occurred during the session, do NOT create or update any retro files. Simply deliver a concise verification confirmation directly in the dialogue without generating disk artifacts.

---

## Workflow Steps

### Step 1: Session Analysis & Friction Extraction

1. **Dialogue History Inspection:**
   - Scan all user turns from the start of the session to the current moment.
   - Flag user corrections, objections, or redirections (e.g., *"no"*, *"not like that"*, *"fix this"*, *"you forgot"*, *"stop"*, *"revert"*, *"ні"*, *"не так"*, *"виправ"*, *"забув"*).
   - Identify instances where the user had to repeat requirements or clarify ambiguities.
2. **Execution & Tool Telemetry Scan:**
   - Inspect tool invocation logs, shell execution outputs, and subagent lifecycles.
   - Detect tool failures (exit codes $\ne 0$, syntax errors, unhandled exceptions, missing file paths, permission rejections).
   - Detect hallucinations (fictitious imports, non-existent file paths, fabricated API methods, unverified assumptions violating **Rule I**).
3. **Deep Transcript Fallback (Dual-Tier):**
   - If the active session is extensive (>10 turns) or context compaction has occurred, inspect:
     `<appDataDir>\brain\<conversation-id>\.system_generated\logs\transcript.jsonl`
   - Use targeted queries (`grep_search`) for `"type":"USER_INPUT"` and `"status":"ERROR"` to retrieve exact historical quotes and step indices.

---

### Step 2: Project Artifact & Root Cause Analysis

1. **Governance Asset Audit:**
   - Inspect active project rules (`GEMINI.md`, `AGENTS.md`, `.agents/rules/*.md`).
   - Inspect active lifecycle workflows (`config/global_workflows/*.md`, `.agents/workflows/*.md`).
   - Inspect available domain skills (`config/skills/`, `.agents/skills/`).
2. **Root Cause Mapping & Remediation Integrity:**
   - For every friction incident identified in Step 1, cross-reference against governance assets:
     - Did an explicit, concrete rule exist covering this specific scenario?
       - If **No**: Classify as `MISSING_RULE`.
       - If **Yes, but underspecified / broad**: Classify as `AMBIGUOUS_RULE` (e.g., generic "Senior Quality" without specific constraint).
       - If **Yes, but contradictory**: Classify as `CONFLICTING_RULES`.
       - If **Yes, and 100% concrete & unambiguous**: Classify as `AGENT_DEVIATION` (pure compliance lapse).
     - Was the failure caused by lack of specialized domain tooling/runbooks?
       - Classify as `SKILL_DEFICIT`.
   - **Remediation Invariant:** Do not discard friction points. Every incident in Section 1 MUST map to a concrete artifact recommendation in Section 2, or contain an explicit explanation why codification is counterproductive.
3. **Scope Triage & Anti-Bloat Gate:**
   - For each identified friction point and recommended remediation, classify into:
     - `[LOCAL]`: Belongs to project source code, project-level `.agents/rules/repository-context.md`, project-level `.agents/skills/`, or application agent prompts.
     - `[GLOBAL]`: Belongs to `GEMINI.md`, `config/global_workflows/*.md`, or global skills.
   - **Triage Filter:** Before assigning a finding to `[GLOBAL]`, verify that it is universally applicable across all tech stacks (.NET, TS, Python, Rust, Go) and across all repositories. If it concerns a specific framework, API contract, or application agent persona, it MUST be routed to `[LOCAL]`.
4. **Cross-Workflow Ripple Audit:**
   - When proposing changes to global workflow steps or interaction protocols (e.g., git staging, test harnesses, diff targeting), audit all other workflows in `config/global_workflows/` to identify downstream ripple effects and maintain cross-workflow harmony.

---

### Step 3: Minimal Intervention & Token Density Filter

1. **Threshold for Change Proposal:**
   - Propose modifications only for systemic, recurrent, or high-risk friction points.
   - Ignore one-off conversational preferences that do not represent reusable engineering patterns.
2. **Rule Formulation & Token Density Standards:**
   - Proposed rules must be strictly imperative, dense, and placed in the appropriate section of `GEMINI.md` or the target workflow.
   - **Token Density Constraint (Rule H):** Target 15–25 words per bullet for `GEMINI.md`. Prohibit preamble filler, conversational framing, and duplicate synonyms.
   - Ensure zero contradiction with existing rules (Rule D, Rule F, Rule I, Rule J).
   - Formulate exact replacement or addition chunks (`ADD`, `UPDATE`, `REMOVE`).

---

### Step 4: Output Synthesis & Sequential Versioning

1. **Clean Session Short-Circuit (Zero-Artifact):**
   - If Step 1 & 2 detect zero friction points, tool failures, or rule ambiguities, **do not create any retro files**.
   - Skip disk artifact generation entirely and proceed directly to **Step 5 (Case B: Clean Session)**.
2. **Sequential Versioning & Target Directory (When Friction Detected):**
   - Verify that `.local/retro/` directory exists in workspace root; create it if missing.
   - Inspect existing files in `.local/retro/` matching `retro-local-<N>.md` and `retro-global-<N>.md`.
   - Determine the next sequential index $N+1$ (e.g., `retro-local-1.md` -> `retro-local-2.md`; default to `1` if none exist). If both local and global files are generated in the same session, synchronize their index $N+1$.
   - Write to **`.local/retro/retro-local-<N+1>.md`** (if local friction present).
   - Write to **`.local/retro/retro-global-<N+1>.md`** (if global friction present).
   - NEVER create or update `latest.md` or any alias files.
3. **Workspace Staging Path Resolution:**
   - If in a configuration repository, resolve all artifact paths in Section 2 to local workspace files (`GEMINI.md`, `config/global_workflows/...`).

#### Standard Output Schema for Local Scope (`.local/retro/retro-local-<N+1>.md`):

```markdown
# Retro Review & Optimization Prompt (Project Scope)
Date: [YYYY-MM-DD HH:mm:ss]
Scope: Local Project Workspace

## 1. Friction & Failure Analysis
- **Problem Summary:** [Concise description of the project-level incident or suboptimal behavior]
- **Root Cause:** [MISSING_RULE | AMBIGUOUS_RULE | CONFLICTING_RULES | SKILL_DEFICIT | AGENT_DEVIATION] - [Detailed explanation]
- **Evidence:** [Quotes from session messages, step indices, or tool error logs]

## 2. Recommended Artifact Changes (Project Scope)
- [ ] **Artifact:** `[Project file, e.g. .agents/rules/repository-context.md, src/..., .agents/skills/...]`
  - **Action:** `[ADD / UPDATE / REMOVE]`
  - **Proposed Content:** `[Exact directive, configuration snippet, or surgical code diff]`

## 3. Next Steps & Execution Prompt
- **Execute via `/implement`:** `/implement .local/retro/retro-local-<N+1>.md` (Run directly in this project workspace)
- **Execute via `/investigate`:** `/investigate .local/retro/retro-local-<N+1>.md` (If architectural planning is needed)
```

#### Standard Output Schema for Global Scope (`.local/retro/retro-global-<N+1>.md`):

```markdown
# Retro Review & Optimization Prompt (Global Governance Scope)
Date: [YYYY-MM-DD HH:mm:ss]
Scope: Global Antigravity Governance

## 1. Friction & Failure Analysis
- **Problem Summary:** [Concise description of the universal engine/rule friction]
- **Root Cause:** [MISSING_RULE | AMBIGUOUS_RULE | CONFLICTING_RULES | SKILL_DEFICIT | AGENT_DEVIATION] - [Detailed explanation]
- **Evidence:** [Quotes from session messages, step indices, or tool error logs]

## 2. Recommended Artifact Changes (Global Scope)
- [ ] **Artifact:** `[Global file, e.g. GEMINI.md, config/global_workflows/<name>.md, config/skills/...]`
  - **Action:** `[ADD / UPDATE / REMOVE]`
  - **Proposed Content:** `[Exact 15-25 word imperative directive or surgical diff]`

## 3. Next Steps & Execution Prompt
- **Execute via `/implement`:** `/implement .local/retro/retro-global-<N+1>.md` (Run in Antigravity configuration repository)
- **Execute via `/investigate`:** `/investigate .local/retro/retro-global-<N+1>.md` (If multi-workflow ripple analysis is needed)

> **Workspace Staging Directive:** If operating within a local configuration staging workspace (containing local copies of `GEMINI.md` or `config/`), apply all optimizations directly to the workspace files. Keep all changes unstaged in the working tree for user inspection.
```

---

### Step 5: Conversational Handoff

#### Case A: Friction Detected (Artifacts Created)
1. Confirm artifact creation with clickable links to the newly generated file(s):
   - Local Scope (if generated): `[retro-local-<N+1>.md](file:///.local/retro/retro-local-<N+1>.md)`
   - Global Scope (if generated): `[retro-global-<N+1>.md](file:///.local/retro/retro-global-<N+1>.md)`
2. Provide a concise summary in the user's active conversational language (**Rule A**):
   - Highlight whether friction points were identified, top root causes, and scope distribution.
   - Provide ready slash commands with explicit execution context:
     - For local fixes: `Run in this project: /implement .local/retro/retro-local-<N+1>.md`
     - For global fixes: `Run in Antigravity repo: /implement .local/retro/retro-global-<N+1>.md`

#### Case B: Clean Session (Zero-Artifact Confirmation)
1. Deliver a concise verification summary in the user's active conversational language (**Rule A**):
   - Confirm that forensic analysis detected zero friction, errors, rule ambiguities, or deviations.
   - Confirm that existing governance rules, workflows, and skills are sufficient.
   - Explicitly note that no retro files were created or updated, keeping the repository clean.
