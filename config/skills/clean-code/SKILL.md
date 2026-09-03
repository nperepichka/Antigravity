---
name: clean-code
description: Applies principles from Robert C. Martin's 'Clean Code', modern pragmatic software engineering, cognitive complexity reduction, Locality of Behavior, and systematic refactoring patterns. Use when writing new features, reviewing pull requests, refactoring legacy code, or eliminating code smells and deeply nested branching.
user-invocable: true
risk: safe
source: "ClawForge (https://github.com/jackjin1997/ClawForge)"
---

# Clean Code & Refactoring Engineering Guide

This skill embodies the principles of "Clean Code" by Robert C. Martin (Uncle Bob), modern pragmatic software engineering, SOLID architecture, and systematic code refactoring. Use it to transform "code that works" into "code that is clean, maintainable, robust, and easy to reason about."

---

## 🧠 Core Philosophy
> "Code is clean if it can be read, and enhanced by a developer other than its original author." — Grady Booch  
> "Duplication is far cheaper than the wrong abstraction." — Sandi Metz

---

## 1. Meaningful Names
- **Use Intention-Revealing Names**: `elapsedTimeInDays` instead of `d`.
- **Avoid Disinformation**: Don't use `accountList` if it's actually a `Map`.
- **Make Meaningful Distinctions**: Avoid `ProductData` vs `ProductInfo`.
- **Use Pronounceable/Searchable Names**: Avoid `genymdhms`.
- **Class Names**: Use nouns (`Customer`, `WikiPage`). Avoid `Manager`, `Data`, `Processor`.
- **Method Names**: Use verbs (`postPayment`, `deletePage`, `isEligible`).

---

## 2. Functions & Methods
- **Small & Focused**: Functions should ideally be short (< 20–30 lines), but avoid dogmatic over-fragmentation.
- **Locality of Behavior (LoB)**: Prioritize keeping a cohesive, linear procedure together rather than scattering logic into single-use micro-helpers across multiple files ("clean architecture lasagna"). Code should be understandable by reading the unit itself.
- **Do One Thing (Single Level of Abstraction - SLA)**: A function should do only one thing at its designated level of abstraction.
- **Descriptive Names**: `isPasswordValid` is better than `check`.
- **Arguments**: 0 is ideal, 1–2 is acceptable, 3+ requires a Parameter Object, Value Object, or Options pattern.
- **No Hidden Side Effects**: Functions shouldn't secretly mutate global state or modify reference arguments unexpectedly. Prefer pure functions and immutability by default.

---

## 3. Complexity Control: Cyclomatic vs. Cognitive
- **Cyclomatic Complexity (CC):** Measures mathematical branch paths. Thresholds: 1–5 (clean), 6–10 (watch), 11–15 (refactor now), 15+ (mandatory split).
- **Cognitive Complexity (SonarQube Standard):** Measures mental effort required to understand control flow. It heavily penalizes deep nesting (`if` inside `for` inside `if`), recursion, and breaks in linear reading flow, but does NOT penalize flat, idiomatic `switch` statements or structural pattern matching (Target: ≤ 15 per function).
- **Refactoring Tactics (Order of Preference):**
  1. *Guard Clauses:* Invert conditions and return early to flatten nested code.
  2. *Extract Function:* Break into intention-revealing functions named for *what* they do, not *how*.
  3. *Lookup Table / Map Dispatch:* Replace `switch` or `if/else` ladders with dictionary/map dispatch.
  4. *Named Predicates:* Extract multi-clause conditionals into well-named boolean functions (`if (isEligible)` vs boolean soup).
  5. *Flatten Loops:* Use early `continue` and extracted loop bodies instead of nested conditional blocks.
  6. *Polymorphism / Strategy:* Replace repeated switch-on-type patterns (when occurring in 2+ places).
- **Anti-Gaming & Solution Integrity (Rule J):** Never compress branches into dense one-liners or nested ternaries to game metrics. Never add symptom-masking `if/else` checks to work around bugs; fix the underlying domain model or contract.

---

## 4. Comments & Self-Documenting Code
- **Code explains HOW & WHAT, Comments explain WHY**: Most comments explaining *what* code does are apologies for unclear naming or structure. Rewrite unclear code instead of explaining it.
- **Explain Intent & Invariants**: Document non-obvious business rules, why a naive approach was discarded (preventing regressions), bug reproduction context, or external library workarounds.
- **Explain Yourself in Code**:
  ```python
  # ❌ Bad: Comment explaining non-obvious condition
  if employee.flags & HOURLY and employee.age > 65:
  
  # ✅ Good: Self-documenting domain method
  if employee.is_eligible_for_full_benefits():
  ```
- **Bad Comments**: Mumbling, Redundant restatements, Stale/misleading comments, Commented-out dead code (delete it; Git remembers).

---

## 5. SOLID Principles in Practice
1. **Single Responsibility Principle (SRP):** A module should have one, and only one, reason to change (cohesion around a single actor/domain boundary).
2. **Open/Closed Principle (OCP):** Open for extension, closed for modification (Strategy, Factory, and plugin abstractions).
3. **Liskov Substitution Principle (LSP):** Subtypes must be substitutable for base types without breaking client expectations.
4. **Interface Segregation Principle (ISP):** Clients should not depend on interfaces they do not use (lean, role-specific interfaces).
5. **Dependency Inversion Principle (DIP):** High-level modules should depend on abstractions, not concrete low-level details.

---

## 6. Objects, Immutability & Modern Error Handling
- **The Law of Demeter**: A module should not know about the innards of the objects it manipulates (`a.getB().getC().doSomething()` is a violation).
- **Expected Domain Errors vs. Unrecoverable System Failures**:
  - Use `Result<T, E>`, `Option<T>`, or Discriminated Unions for **expected domain failures** (e.g. `NotFound`, `ValidationFailed`, `PaymentDeclined`). Keeps failure modes explicit in type signatures without hidden control jumps.
  - Reserve **Exceptions** strictly for *unexpected, unrecoverable system failures* (network drops, hardware faults, corrupted memory, violated fatal invariants).
- **Don't Return or Pass Null**: Use Null Object pattern, `Optional<T>`, `Result<T>`, or non-nullable reference types.
- **Immutability by Default**: Use readonly properties, records, and pure data structures to prevent temporal coupling and concurrency race hazards.

---

## 7. Unit Tests & TDD
- **The Three Laws of TDD**:
  1. Don't write production code until you have a failing unit test.
  2. Don't write more of a unit test than is sufficient to fail.
  3. Don't write more production code than is sufficient to pass the failing test.
- **F.I.R.S.T. Principles**: Fast, Independent, Repeatable, Self-Validating, Timely.
- **Test at Seams**: Test public behavior and business contracts, never private implementation details.

---

## 📚 Detailed Refactoring Playbook & Scenarios

For comprehensive, multi-language code samples (Python, TypeScript, C#, Java, Go) illustrating:
- Monolith decomposition into domain entities, repositories, and services
- Code smell resolution (Primitive Obsession -> Value Objects, Feature Envy, Parameter Objects)
- Complexity metrics interpretation matrix (Cyclomatic complexity, Cognitive complexity)
- AI-assisted review pipelines and static analysis rules (Ruff, ESLint, SonarQube)

👉 Refer to **`resources/implementation-playbook.md`**.

---

## 🛠️ Implementation Checklist
- [ ] Is this function focused with low cognitive (≤ 15) and cyclomatic (≤ 10) complexity?
- [ ] Does this function preserve Locality of Behavior (LoB) without unnecessary indirection lasagna?
- [ ] Does this function do one thing at a single level of abstraction?
- [ ] Are nested branches flattened with guard clauses or early returns?
- [ ] Are expected domain errors handled via `Result<T, E>` / explicit return types rather than exceptions?
- [ ] Are comments reserved for explaining the *WHY* (business invariants, non-obvious trade-offs) rather than the *WHAT*?
- [ ] Does this change address root causes without symptom-masking `if/else` conditionals (Rule J)?
- [ ] Is there an automated test verifying this change?
