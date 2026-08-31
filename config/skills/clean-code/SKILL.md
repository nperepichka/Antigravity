---
name: clean-code
description: Applies principles from Robert C. Martin's 'Clean Code', SOLID architecture, cyclomatic complexity reduction, and systematic code refactoring patterns. Use when writing new features, reviewing pull requests, refactoring legacy code, or eliminating code smells and deeply nested branching.
user-invocable: true
risk: safe
source: "ClawForge (https://github.com/jackjin1997/ClawForge)"
---

# Clean Code & Refactoring Engineering Guide

This skill embodies the principles of "Clean Code" by Robert C. Martin (Uncle Bob), SOLID architecture, and systematic code refactoring. Use it to transform "code that works" into "code that is clean, maintainable, and robust."

---

## 🧠 Core Philosophy
> "Code is clean if it can be read, and enhanced by a developer other than its original author." — Grady Booch

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
- **Small!**: Functions should ideally be shorter than 20 lines.
- **Do One Thing**: A function should do only one thing, and do it well (Single Level of Abstraction).
- **Descriptive Names**: `isPasswordValid` is better than `check`.
- **Arguments**: 0 is ideal, 1–2 is acceptable, 3+ requires a Parameter Object or Value Object.
- **No Side Effects**: Functions shouldn't secretly mutate global state or modify arguments unexpectedly.

---

## 3. Cyclomatic Complexity & Branching Control
- **Thresholds:** 1–5 (clean), 6–10 (watch), 11–15 (refactor now), 15+ (mandatory split).
- **Refactoring Tactics (Order of Preference):**
  1. *Guard Clauses:* Invert conditions and return early to flatten nested code.
  2. *Extract Function:* Break into intention-revealing functions named for *what* they do, not *how*.
  3. *Lookup Table / Map:* Replace `switch` or `if/else` ladders with dictionary/map dispatch.
  4. *Named Predicates:* Extract multi-clause conditionals into well-named boolean functions (`if (is_eligible)` vs boolean soup).
  5. *Flatten Loops:* Use early `continue` and extracted loop bodies instead of nested conditional blocks.
  6. *Polymorphism / Strategy:* Replace repeated switch-on-type patterns (when occurring in 2+ places).
- **Anti-Gaming Rule:** Never compress branches into dense one-liners or nested ternaries to game metrics. Complexity must move into well-named units, never hidden behind cleverness.

---

## 4. Comments & Self-Documenting Code
- **Don't Comment Bad Code—Rewrite It**: Most comments are apologies for failure to express intent in code.
- **Explain Yourself in Code**: 
  ```python
  # ❌ Bad: Comment explaining non-obvious condition
  if employee.flags & HOURLY and employee.age > 65:
  
  # ✅ Good: Self-documenting domain method
  if employee.is_eligible_for_full_benefits():
  ```
- **Good Comments**: Legal notices, Intent clarification (complex regex, external library quirks), TODOs.
- **Bad Comments**: Mumbling, Redundant restatements, Misleading/stale comments, Commented-out code (delete it; Git remembers).

---

## 5. SOLID Principles in Practice

1. **Single Responsibility Principle (SRP):** A class should have one, and only one, reason to change.
2. **Open/Closed Principle (OCP):** Software entities should be open for extension, but closed for modification (Strategy / Factory patterns).
3. **Liskov Substitution Principle (LSP):** Subtypes must be substitutable for their base types without altering system correctness.
4. **Interface Segregation Principle (ISP):** Clients should not be forced to depend on methods they do not use.
5. **Dependency Inversion Principle (DIP):** High-level modules should not depend on low-level modules; both should depend on abstractions.

---

## 6. Objects, Data Structures & Error Handling
- **The Law of Demeter**: A module should not know about the innards of the objects it manipulates (`a.getB().getC().doSomething()` is a violation).
- **Use Exceptions instead of Return Codes**: Keeps the happy path uncluttered.
- **Don't Return or Pass Null**: Use Null Object pattern, `Optional<T>`, `Result<T>`, or non-nullable types.

---

## 7. Unit Tests & TDD
- **The Three Laws of TDD**:
  1. Don't write production code until you have a failing unit test.
  2. Don't write more of a unit test than is sufficient to fail.
  3. Don't write more production code than is sufficient to pass the failing test.
- **F.I.R.S.T. Principles**: Fast, Independent, Repeatable, Self-Validating, Timely.

---

## 📚 Detailed Refactoring Playbook & Scenarios

For comprehensive, multi-language code samples (Python, TypeScript, Java, Go) illustrating:
- Monolith decomposition into domain entities, repositories, and services
- Code smell resolution (Primitive Obsession -> Value Objects, Feature Envy, Parameter Objects)
- Complexity metrics interpretation matrix (Cyclomatic complexity, Cognitive complexity)
- AI-assisted review pipelines and static analysis rules (Ruff, ESLint, SonarQube)

👉 Refer to **`resources/implementation-playbook.md`**.

---

## 🛠️ Implementation Checklist
- [ ] Is this function smaller than 20 lines with low cyclomatic complexity (CC ≤ 10)?
- [ ] Does this function do exactly one thing?
- [ ] Are nested branches flattened with guard clauses or early returns?
- [ ] Are all names searchable and intention-revealing?
- [ ] Have I avoided comments by making the code clearer?
- [ ] Have I replaced magic numbers with descriptive constants?
- [ ] Is there an automated test verifying this change?
