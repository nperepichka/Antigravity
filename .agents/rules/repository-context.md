# Repository Meta-Context: Antigravity Config Master

## System Identity & Domain
This workspace is the **master source-of-truth** for the user's Google Antigravity global configuration — the complete set of global rules (`GEMINI.md`), autonomous engineering workflows (7 slash-command workflows), and 33 specialized domain skills. It defines how AI coding agents behave, reason, and self-govern across all of the user's projects. The target audience is the repository owner, who iterates on agent meta-engineering to achieve reliable, autonomous software development.

## Architecture & Tech Stack
- **Pattern:** Modular declarative configuration — pure Markdown-based prompt engineering, zero runtime code.
- **Stack:** Markdown (YAML frontmatter for skills), Mermaid diagrams, shell scripts (within skills).
- **Module Structure:** `GEMINI.md` (root rules & safety boundaries) → `config/global_workflows/` (7 lifecycle workflows: context, investigate, implement, debug, review, describe, checkpoint) → `config/skills/` (33 domain-expert skill bundles). Deployed globally via sync to `~/.gemini/config/`.

## Non-Obvious Conventions & Guardrails
- **Tandem Lifecycle Synergy:** All 7 workflows operate as a unified, cohesive pipeline (context → investigate → implement → debug → review → describe → checkpoint). Changes to one workflow must preserve interoperability invariants with the others.
- **Read-Only Discovery Safety:** `/context`, `/investigate`, and `/review` workflows are strictly read-only — zero code modifications, package installs, or state-altering commands.
- **Dual-Language Protocol (Rule A + E):** User interaction follows the user's language (often Ukrainian); all code artifacts, identifiers, docstrings, and rule file content must be in English.
- **Skill Activation is Implicit:** Skills are never invoked by name — workflows auto-discover and activate relevant skills based on project tech stack context.
- **Non-Destructive Merge on Updates:** Any automated refresh of configuration files must preserve user-defined custom notes, business rules, and manual policies.

## Operational Context
- **Source of Truth:** Changes to `GEMINI.md`, `config/global_workflows/*.md`, or `config/skills/**` represent core Antigravity meta-engineering synchronized to the global config directory (`~/.gemini/config/`).
- **Immediate Task Execution:** When the user initiates a session with a direct task (editing rules, updating workflow logic, refining skills), treat it immediately as an Antigravity customization task without requiring explanation of the repo's purpose or architecture.
