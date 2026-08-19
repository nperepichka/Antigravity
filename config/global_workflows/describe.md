---
description: Autonomous generation of concise, high-signal Pull Request descriptions (.local/pr_description.md) from git diffs, commit history, and task specs.
---

# Pull Request Description Loop

Generates a concise, structured, senior-level Pull Request description saved directly to **`.local/pr_description.md`** based on git diffs, commit logs, and completed task specifications.

---

## Core Directives

- **Strict Read-Only Guarantee:** ZERO modifications to source code files. Only creates or updates `.local/pr_description.md`. Permitted: `git diff`, `git log`, `git status`, `git show`, and reading task files.
- **High-Signal & Concise:** Focus strictly on *what changed, why, and architectural impact*. Omit boilerplate filler, verbose test run logs, or generic reviewer checklists.
- **Conventional Commits & Clean Layout:** Format PR title according to Conventional Commits (`feat`, `fix`, `refactor`, `perf`, `chore`) and group changes logically by component.

---

## Workflow Steps

### Step 1: Target Resolution & Context Ingestion

1. **Target Identification:**
   - *Branch Comparison (Default):* `git diff <base>...<target>` (e.g. `main...HEAD` or `origin/main...HEAD`)
   - *Commit Range:* `git diff HEAD~N..HEAD` (e.g. `git diff HEAD~3..HEAD`)
   - *Working Tree (Uncommitted):* `git diff HEAD`
2. **Diff & History Extraction:**
   - Changed files summary: `git diff --name-status <base>...<target>`
   - Unified diff: `git diff <base>...<target>`
   - Commit history: `git log -n 15 --oneline <base>..<target>`
3. **Task Context Ingestion:**
   - Check for master specs (`.local/tasks/**/00_overview.md`) or completed phase files (`.local/tasks/**/01_<name>.md`) to extract business goals, requirements, and background motivation.

---

### Step 2: Change Synthesis & Component Categorization

Analyze the unified diff and group modifications by functional layer:
- **Core / Domain:** Business rules, entity models, domain events.
- **API / Transport:** Endpoints, request/response DTOs, middleware, routes.
- **Data & Persistence:** Database migrations, repository queries, ORM entity configurations.
- **Configuration & Infra:** New environment variables (`.env.example`, `appsettings.json`), Docker/CI adjustments.
- **Breaking Changes:** Any altered public contracts, deprecated parameters, or non-reversible database schema changes.

---

### Step 3: PR Description File Generation

Create or overwrite **`.local/pr_description.md`** using the following clean, standard structure (in **English**):

```markdown
# <type>(<scope>): <concise, imperative title>

## Summary
Brief 1–3 sentence explanation of the problem solved, feature added, or bug fixed, along with the motivation.

## Key Changes
- **<Component / Layer>:**
  - Concise bullet describing specific change and intent.
  - Another key detail.
- **<Component / Layer>:**
  - Concise bullet describing specific change.

<!-- Include only if breaking changes or migrations exist -->
## Breaking Changes & Migration Notes
- **Database / Schema:** [Details on migrations, indexes, or rollback safety]
- **API Contracts:** [Details on field renames, type changes, or deprecations]
- **Configuration:** [New environment variables and sample values]
```

---

### Step 4: Delivery

1. The generated PR description in `.local/pr_description.md` MUST be in **English** (**Rule E**).
2. Present a clickable link to [pr_description.md](file:///.local/pr_description.md) and a brief conversational summary in the user's language (**Rule A**).
