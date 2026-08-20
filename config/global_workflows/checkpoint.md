---
description: Session state distillation, interactive knowledge capture, and clean-state context restoration (/checkpoint to save, /checkpoint load to restore).
---

# Session Checkpoint & Context Compaction Loop

Autonomous mechanism to distill active session knowledge (multi-task workstreams, architectural decisions, workspace state, pending items) into a persistent `.local/checkpoint.md`, enabling seamless migration to a fresh, hallucination-free session with zero context loss.

---

## Core Directives

- **Read-Only / State-Safe:** Never alters application source code. Operates strictly by creating, updating, or reading `.local/checkpoint.md`. Permitted: `git status`, `git diff`, conversation transcript parsing.
- **Interactive Knowledge Curation (Save Mode):** Proactively extract candidate topics/decisions and present them to the user via `ask_question` (or interactive selection) to filter out transient noise and retain high-signal knowledge.
- **Passive Restoration (Load Mode):** When restoring state, strictly reconstruct context, deliver an orientation briefing, and wait for user instructions without executing unprompted actions.

---

## Modes & Execution

The workflow operates in two distinct modes based on the input argument:
1. **Save Mode (`/checkpoint` or `/checkpoint save`):** Captures, filters, and persists active session state.
2. **Load Mode (`/checkpoint load` or `/checkpoint restore`):** Ingests `.local/checkpoint.md`, rebuilds working memory, and halts for user direction.

---

## Workflow Steps

### Mode A: Save Session State (`/checkpoint`)

#### Step 1: Session Analysis & State Ingestion
1. **Transcript & Context Scan:** Parse conversation history (`transcript.jsonl`) to identify all topics discussed, problems analyzed, and solutions evaluated.
2. **Workspace Delta:** Run `git status` and `git diff --name-status` to identify modified, newly created, or uncommitted files across the workspace.

#### Step 2: Multi-Track Synthesis
Decompose the session findings into four structured dimensions (supports multiple parallel tasks):
- **Active Workstreams & Tasks:** Key tasks touched during the session (e.g. Task A: Auth Refactor, Task B: DB Schema, Task C: Workflow Tuning) with their current completion status.
- **Key Architectural Decisions & Invariants:** Core decisions, trade-offs, constraints, conventions, and rules established.
- **Environment & Workspace Delta:** Changed files, branch status, dependencies added, and verification state (tests passing/failing).
- **Pending Items & Next Actions:** Clear, actionable steps remaining for each workstream.

#### Step 3: Interactive Verification & Filtering
1. **Interactive Selection (`ask_question`):** Present extracted workstreams and critical decisions to the user using multi-select checkboxes.
2. **User Confirmation:** Allow the user to select items to persist, uncheck ephemeral discussion noise, or supply write-in notes.

#### Step 4: Checkpoint Artifact Generation
Write the distilled knowledge to **`.local/checkpoint.md`** using the structured template below (in **English** per **Rule E**):

```markdown
# Session Checkpoint: [YYYY-MM-DD HH:mm]

## 1. Active Workstreams & Task States
- **[Workstream / Topic 1]:**
  - *Context & Scope:* Brief summary of problem/goal.
  - *Accomplished:* Key changes implemented and verified.
  - *Current Status:* `[x] Completed` / `[>] In Progress` / `[!] Blocked`.
- **[Workstream / Topic 2]:**
  - *Context & Scope:* ...
  - *Accomplished:* ...
  - *Current Status:* ...

## 2. Key Decisions & System Invariants
- **[Decision 1]:** [Context, choice made, rationale, constraints].
- **[Decision 2]:** [Configuration or behavioral agreement].

## 3. Workspace State & Code Deltas
- **Modified Files:** `path/to/file1.ext`, `path/to/file2.ext`
- **Verification Status:** [Build status, test suite results, visual checks].

## 4. Pending Items & Immediate Next Steps
1. [Actionable next step for Workstream 1].
2. [Actionable next step for Workstream 2].
```

#### Step 5: Handoff Instructions
1. Confirm checkpoint creation with a clickable link to [checkpoint.md](file:///.local/checkpoint.md).
2. Present a clear transition prompt in user's conversational language (**Rule A**):
   - Notify the user that the checkpoint was successfully saved.
   - Instruct the user to open a fresh session (`+ New Chat`) and type `/checkpoint load` to restore context.

---

### Mode B: Load Session State (`/checkpoint load`)

#### Step 1: Checkpoint File Ingestion
1. Verify existence and read `.local/checkpoint.md` (or user-specified custom checkpoint file).
2. If the file does not exist, notify the user and ask for the target path.

#### Step 2: Context Reconstruction
Ingest all documented workstreams, architectural decisions, environment states, and pending backlog into the active agent context.

#### Step 3: Orientation Briefing & User Await
1. Present a concise orientation summary in the user's conversational language (**Rule A**):
   - **Active Workstreams:** Restored topics/tasks and their current completion status.
   - **Key Decisions & Invariants:** Established rules, architectural choices, and constraints.
   - **Pending Next Steps:** Actionable backlog items ready to continue.
2. **CRITICAL:** **Halt and await user instructions.** Do NOT start writing code or running build/test commands automatically until the user specifies which task to proceed with.
