---
name: clean-code
description: Applies principles from Robert C. Martin's 'Clean Code', SOLID architecture, and systematic code refactoring patterns. Use when writing new features, reviewing pull requests, refactoring legacy code, or eliminating code smells.
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

## 3. Comments & Self-Documenting Code
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

## 4. SOLID Principles in Practice

1. **Single Responsibility Principle (SRP):** A class should have one, and only one, reason to change.
2. **Open/Closed Principle (OCP):** Software entities should be open for extension, but closed for modification (Strategy / Factory patterns).
3. **Liskov Substitution Principle (LSP):** Subtypes must be substitutable for their base types without altering system correctness.
4. **Interface Segregation Principle (ISP):** Clients should not be forced to depend on methods they do not use.
5. **Dependency Inversion Principle (DIP):** High-level modules should not depend on low-level modules; both should depend on abstractions.

---

## 5. Objects, Data Structures & Error Handling
- **The Law of Demeter**: A module should not know about the innards of the objects it manipulates (`a.getB().getC().doSomething()` is a violation).
- **Use Exceptions instead of Return Codes**: Keeps the happy path uncluttered.
- **Don't Return or Pass Null**: Use Null Object pattern, `Optional<T>`, `Result<T>`, or non-nullable types.

---

## 6. Unit Tests & TDD
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
- [ ] Is this function smaller than 20 lines?
- [ ] Does this function do exactly one thing?
- [ ] Are all names searchable and intention-revealing?
- [ ] Have I avoided comments by making the code clearer?
- [ ] Have I replaced magic numbers with descriptive constants?
- [ ] Is there an automated test verifying this change?
