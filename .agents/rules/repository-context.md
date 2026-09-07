# Repository Meta-Context: Antigravity Config Master

## System Identity & Domain
This workspace is the local staging and working copy for the user's global Google Antigravity configuration — encompassing global rules (`GEMINI.md` / `AGENTS.md`), 9 lifecycle engineering workflows (`config/global_workflows/`), 31 specialized domain skills (`config/skills/`), and ecosystem templates (`config/templates/`). All files outside `.agents/` mirror global configuration assets.

## Architecture & Tech Stack
- **Pattern:** Modular declarative configuration — Markdown prompt engineering with YAML frontmatter, starter templates, and helper scripts.
- **Module Structure:** `GEMINI.md` / `AGENTS.md` (core rules & guardrails) → `config/global_workflows/` (context, investigate, explain, implement, debug, review, describe, checkpoint, retro) → `config/skills/` (domain capability bundles) → `config/templates/` (lifecycle hooks & configs).

## Non-Obvious Conventions & Guardrails
- **Tandem Lifecycle Synergy:** All 9 workflows form a unified pipeline; changes to one workflow must preserve interoperability invariants with the others.
- **Read-Only Discovery Loops:** `/context`, `/investigate`, `/explain`, `/review`, and `/retro` workflows are strictly read-only — zero code modifications or package operations.
- **Solution Integrity (Rule J):** Address root causes directly in contracts and domain models; never add symptom-masking conditionals or stack patches on broken foundations.
- **Dual-Language Invariant (Rule A + E):** User interactions and markdown artifacts adhere to the user's active language; rule definitions, workflows, and code identifiers remain strictly in English.
- **Lazy JIT Skill Loading (Rule H):** Domain skills load on-demand (max 1–3) only when squarely matching specialized tasks; no speculative meta-skill loading.
- **Unstaged Working Tree Delivery (Rule C):** Verified changes MUST remain unstaged in the working tree for user inspection; never run `git add` automatically.

## Operational Context
- **Manual User Sync Model:** The user manually deploys/copies verified changes from this repository to target global locations (`~/.gemini/config/`). Agents MUST NOT attempt to touch or sync external global paths directly.
- **Immediate Execution:** Sessions targeting rule, workflow, or skill modifications are direct meta-engineering tasks requiring zero scaffolding or repo orientation overhead.
