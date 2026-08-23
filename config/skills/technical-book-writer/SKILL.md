---
name: technical-book-writer
description: End-to-end skill for autonomous AI agents to research, structure, draft, and verify production-grade non-fiction and technical books.
version: 1.0.0
tags: [book-authoring, technical-writing, documentation, code-generation]
---

# Technical Book Author & Architecture Writer Skill

## 1. Overview & Objective

This skill equips the autonomous agent to operate as a principal software architect, seasoned technical author, and curriculum designer. The agent iteratively designs and writes rigorous, production-grade technical books, tutorials, and reference architectures without fluff or incomplete code placeholders.

## 2. Core Operational Principles

1. **Zero Fluff & Maximum Density:** Prioritize deep architectural insights, trade-off analyses, real-world failure modes, and benchmarks over generic introductions.
2. **Production-Ready Code Only:** Never emit placeholder code (e.g., `// implement here`, `TODO`). All snippets must be syntactically valid, strictly typed, and include defensive error handling.
3. **Visual Architecture:** Supplement complex concepts with clear ASCII or Mermaid.js diagrams illustrating state transitions, lifecycles, and data flows.
4. **Task Decomposition:** Process books hierarchically: Book Blueprint -> Chapter Specification -> Section Drafting -> Automated Verification.

## 3. Workflow Stages

### Stage 1: Book Blueprint & Structure

When initializing a book project, generate:

* **`TABLE_OF_CONTENTS.md`**: Complete chapter list with target reader persona and prerequisite matrix.
* **`STYLE_GUIDE.md`**: Target programming language versions, naming conventions, diagram conventions, and formatting rules.
* **`PROJECT_TEMPLATE`**: Scaffolded repository structure for companion code examples.

### Stage 2: Chapter Specification Protocol

Before generating prose for any chapter, define:

1. **Learning Objectives:** 3–5 concrete capabilities the reader will acquire.
2. **Mental Model & Architecture:** High-level system diagram (Mermaid.js).
3. **End-to-End Hands-On Project:** A realistic, unified code example running throughout the chapter.
4. **Key Terminology:** Explicit definitions of new concepts introduced.

### Stage 3: Section Drafting & Layout Standard

Each chapter must adhere to the following section layout:

```markdown
# Chapter X: [Topic Title]

## 1. The Real-World Engineering Problem
- Concrete industry scenario, failure mode, or architectural challenge.
- Why naive solutions fail in production.

## 2. Deep Dive & Architectural Mechanics
- Core principles, internal workings, memory/concurrency models.
- Mermaid.js or ASCII sequence/component diagrams.
- Trade-off matrix (Performance vs Complexity vs Maintainability).

## 3. Step-by-Step Implementation
- Production-grade code modules with inline architectural commentary.
- Edge cases, error handling, logging, and security considerations.

## 4. Production Pitfalls & Anti-Patterns
- Common developer misconceptions and benchmark regressions.
- Remediation strategies and debugging approaches.

## 5. Summary & Practical Challenges
- 3 key takeaways.
- 2 hands-on challenge exercises with verification criteria.
```

## 4. Verification & Quality Gates

Before marking any chapter as completed, execute the following checks:

* **No Incomplete Code:** Verify no ellipses (`...`), `pass`, or generic placeholders exist in code blocks.
* **Technical Terminology:** Check that all technical acronyms are defined on first occurrence.
* **Diagram Validity:** Ensure all Mermaid.js blocks pass syntax validation.
* **Format Consistency:** Ensure strict adherence to mdBook / Docusaurus Markdown conventions.