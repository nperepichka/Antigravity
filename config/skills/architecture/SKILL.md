---
name: architecture
description: "Architectural decision-making framework. Requirements analysis, trade-off evaluation, ADR documentation. Use when making architecture decisions or analyzing system design."
allowed-tools: Read, Glob, Grep
risk: unknown
source: community
---

# Architecture Decision Framework

> "Requirements drive architecture. Trade-offs inform decisions. ADRs capture rationale."

## 🎯 Selective Reading Rule

**Read ONLY files relevant to the request!** Check the content map, find what you need.

| File | Description | When to Read |
|------|-------------|--------------|
| `context-discovery.md` | Questions to ask, project classification | Starting architecture design |
| `trade-off-analysis.md` | ADR templates, trade-off framework | Documenting decisions |
| `pattern-selection.md` | Decision trees, anti-patterns | Choosing patterns |
| `examples.md` | MVP, SaaS, Enterprise examples | Reference implementations |
| `patterns-reference.md` | Quick lookup for patterns | Pattern comparison |

---

## 🔗 Related Skills

| Skill | Use For |
|-------|---------|
| `@[skills/database-design]` | Database schema design |
| `@[skills/api-patterns]` | API design patterns |
| `@[skills/deployment-procedures]` | Deployment architecture |

---

## Core Principle

**"Simplicity is the ultimate sophistication."**

- Start simple
- Add complexity ONLY when proven necessary
- You can always add patterns later
- Removing complexity is MUCH harder than adding it

---

## Codebase Design (Deep Modules)

When structuring modules and interfaces, optimize for **leverage** (for callers) and **locality** (for maintainers):
- **Deep Modules**: A lot of behavior behind a small interface. (e.g. `processOrder(order)` instead of 10 micro-steps).
- **Interfaces over Implementations**: The interface is everything a caller must know (signatures, invariants, errors). Hide the complex implementation.
- **Test at Seams**: A seam is where you can alter behavior without editing in that place. Tests and callers should cross the exact same external seam.
- **Design for Testability**: Accept dependencies (injection), return results instead of side effects, and keep the interface surface area small.

---

## Validation Checklist

Before finalizing architecture:

- [ ] Requirements clearly understood
- [ ] Constraints identified
- [ ] Each decision has trade-off analysis
- [ ] Simpler alternatives considered
- [ ] ADRs written for significant decisions
- [ ] Team expertise matches chosen patterns

## When to Use
This skill is applicable to execute the workflow or actions described in the overview.
