---
description: Automated retrospective audit of active session, root-cause artifact gap analysis, and optimization prompt generation (.local/retro.md).
---

# Active Session Retrospective & Optimization Loop

Autonomous mechanism to perform a forensic audit of the active dialogue session. Parses session history and transcripts, extracts friction points (user corrections, tool errors, rule ambiguities, and hallucinations), analyzes root causes against project governance artifacts (rules, workflows, skills), and synthesizes a structured report and ready-to-use execution prompt into **`.local/retro.md`**.

---

## Core Directives

- **Strict Read-Only Guarantee:** Never alters application source code, project rules, or workflows directly during execution. Operates solely by inspecting session history and generating `.local/retro.md`.
- **Dual-Tier Forensic Analysis:** Prioritizes in-context message history for immediate turns; leverages targeted inspection of `<appDataDir>\brain\<conversation-id>\.system_generated\logs\transcript.jsonl` when session depth exceeds 10 turns or context truncation is detected.
- **Root Cause Taxonomy (5 Categories):** Classify every detected issue into:
  1. `MISSING_RULE`: Action or situation was completely ungoverned by existing rules or workflows.
  2. `AMBIGUOUS_RULE`: Existing rule allowed conflicting or subjective interpretations.
  3. `CONFLICTING_RULES`: Two or more instructions in rules/workflows contradicted each other.
  4. `SKILL_DEFICIT`: Repetitive complex engineering task lacked specialized capability instructions.
  5. `AGENT_DEVIATION`: Existing rule was explicit, clear, and unambiguous, but the agent failed to adhere to it (model lapse).
- **Minimal Intervention Guard:** Strictly prevents rule bloat. If an issue is categorized as `AGENT_DEVIATION` (an existing rule was already clear and unambiguous), flag the compliance lapse without adding redundant or duplicate rules to `GEMINI.md`. Propose additions or updates only for verified artifact gaps.
- **Dual-Language Invariant:** Analysis, output report, and execution prompt in `.local/retro.md` are strictly in **English** (**Rule E**); conversational user handoff adheres to the user's active language (**Rule A**).
- **Clean Session Handling:** If no friction or anomalies occurred during the session, output a concise verification report confirming system integrity without synthesizing unnecessary changes.

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
2. **Root Cause Mapping:**
   - For every friction incident identified in Step 1, cross-reference against the governance assets:
     - Did a rule exist covering this scenario?
       - If **No**: Classify as `MISSING_RULE`.
       - If **Yes, but ambiguous**: Classify as `AMBIGUOUS_RULE`.
       - If **Yes, but contradictory**: Classify as `CONFLICTING_RULES`.
       - If **Yes, and crystal clear**: Classify as `AGENT_DEVIATION` (enforcement lapse; no new rule warranted).
     - Was the failure caused by lack of specialized domain tooling/runbooks?
       - Classify as `SKILL_DEFICIT`.

---

### Step 3: Minimal Intervention & Deduplication Filter

1. **Threshold for Change Proposal:**
   - Propose modifications only for systemic, recurrent, or high-risk friction points.
   - Ignore one-off conversational preferences that do not represent reusable engineering patterns.
2. **Rule Formulation Standards:**
   - Proposed rules must be strictly imperative, concise, and placed in the appropriate section of `GEMINI.md` or the target workflow.
   - Ensure zero contradiction with existing rules (Rule D, Rule F, Rule I, Rule J).
   - Formulate exact replacement or addition chunks (`ADD`, `UPDATE`, `REMOVE`).

---

### Step 4: Output Synthesis & Artifact Generation

1. **Target Path Verification:**
   - Verify that `.local/` directory exists in workspace root; create it if missing.
2. **File Generation:**
   - Write or overwrite **`.local/retro.md`** using the structured specification below.

#### Standard Output Schema (`.local/retro.md`):

```markdown
# Retro Review & Optimization Prompt
Date: [YYYY-MM-DD HH:mm:ss]

## 1. Friction & Failure Analysis
- **Problem Summary:** [Concise description of the incident or suboptimal behavior]
- **Root Cause:** [MISSING_RULE | AMBIGUOUS_RULE | CONFLICTING_RULES | SKILL_DEFICIT | AGENT_DEVIATION] - [Detailed explanation]
- **Evidence:** [Quotes from session messages, step indices, or tool error logs]

## 2. Recommended Artifact Changes
- [ ] **Artifact:** `[Path to file, e.g. GEMINI.md, config/global_workflows/<name>.md]`
  - **Action:** `[ADD / UPDATE / REMOVE]`
  - **Proposed Content:** `[Exact wording or diff of the proposed rule/step]`
- [ ] **Artifact:** `[Path to target workflow or skill]`
  - **Action:** `[Description of modification]`

## 3. Ready-to-Use Execution Prompt
> You are an AI Agent Configuration Engineer. Your objective is to apply the proposed changes from Section 2 to the project's rules, workflows, or skills.
> Maintain conciseness, resolve any rule conflicts, preserve existing guardrails, and verify syntax validity after editing.
```

#### Clean Session Fallback Schema (When zero friction detected):

```markdown
# Retro Review & Optimization Prompt
Date: [YYYY-MM-DD HH:mm:ss]

## 1. Friction & Failure Analysis
- **Problem Summary:** No actionable friction, tool failures, or rule violations detected during this session.
- **Root Cause:** N/A - System operations executed in full alignment with active rules and workflows.
- **Evidence:** Clean execution across all dialogue turns and tool invocations.

## 2. Recommended Artifact Changes
- No changes required. Existing governance rules, workflows, and skills are sufficient.

## 3. Ready-to-Use Execution Prompt
> System audit confirmed clean execution. No artifact optimization required.
```

---

### Step 5: Conversational Handoff

1. Confirm artifact creation with a clickable link:
   `[retro.md](file:///.local/retro.md)`
2. Provide a concise summary in the user's active conversational language (**Rule A**):
   - Highlight whether friction points were identified or the session was clean.
   - Summarize the top root causes and recommended artifact updates.
   - Instruct the user that they can inspect [.local/retro.md](file:///.local/retro.md) or delegate the prompt in Section 3 to an agent to execute the optimizations.
