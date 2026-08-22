# Repository Meta-Context: Antigravity Config Master

## System Identity & Domain
This workspace is the local staging and working copy for the user's global Google Antigravity configuration — encompassing global rules (`GEMINI.md`), 7 lifecycle engineering workflows (`config/global_workflows/`), and 35 specialized domain skills (`config/skills/`). All files outside `.agents/` mirror global configuration assets.

## Architecture & Tech Stack
- **Pattern:** Modular declarative configuration — Markdown prompt engineering with YAML frontmatter and helper shell scripts.
- **Module Structure:** `GEMINI.md` (core rules & guardrails) → `config/global_workflows/` (context, investigate, implement, debug, review, describe, checkpoint) → `config/skills/` (domain capability bundles).

## Non-Obvious Conventions & Guardrails
- **Tandem Lifecycle Synergy:** All 7 workflows form a unified pipeline; changes to one workflow must preserve interoperability invariants with the others.
- **Read-Only Discovery Loops:** `/context`, `/investigate`, and `/review` workflows are strictly read-only — zero code modifications or package operations.
- **Dual-Language Invariant (Rule A + E):** User interactions and markdown artifacts adhere to the user's active language; rule definitions and code identifiers remain strictly in English.
- **Lazy JIT Skill Loading (Rule H):** Domain skills load on-demand (max 1–3) only when squarely matching specialized tasks; no speculative meta-skill loading.

## Operational Context
- **Manual User Sync Model:** The user manually deploys/copies verified changes from this repository to target global locations (`~/.gemini/config/`). Agents MUST NOT attempt to touch or sync external global paths directly.
- **Immediate Execution:** Sessions targeting rule, workflow, or skill modifications are direct meta-engineering tasks requiring zero scaffolding or repo orientation overhead.
