# Idea Pilot — Engineering Guidelines

This document defines coding culture and quality expectations.

It complements repository etiquette.
It governs code behavior, not Git workflow.

---

## 1. Code Philosophy

### 1.1 Prefer clarity over cleverness

Readable code wins.

If it takes explanation, rewrite it.

---

### 1.2 Make illegal states unrepresentable

Types and schema should prevent invalid data.

Validation belongs in the system, not in memory.

---

### 1.3 Explicit beats implicit

Magic is a liability Pit of Failure.

Favor explicit flows over hidden side effects.

---

## 2. Testing Philosophy

- Tests describe behavior, not implementation
- Tests document guarantees
- Every bug gets a regression test
- Critical flows must have integration coverage

No test theater.

---

## 3. Error Handling

- Fail loudly, not silently
- Log with context
- Never swallow errors
- User-facing errors must be actionable

Errors are system signals.

---

## 4. Refactoring

Refactoring is normal work.

Debt compounds if ignored.

Small continuous cleanup beats big rewrites.

---

## 5. Performance

Optimize when measured, not assumed.

Clarity first.
Then optimize bottlenecks.

---

## 6. Reviews

Reviews are collaborative, not adversarial.

We review:

- correctness
- clarity
- maintainability
- alignment with principles

Not personal style.

---

## 7. Documentation

### 7.1 API Documentation (Swagger / OpenAPI)

Every REST endpoint must have Swagger/OpenAPI annotations:
- Summary and description
- Request body schema (with examples for non-trivial payloads)
- Response schemas for success and error cases
- Authentication requirements

Keep annotations co-located with route handlers.

### 7.2 Function-Level Documentation (JSDoc / TSDoc)

All public functions, service methods, and exported utilities must have doc comments:
- `@param` — name, type, and purpose of each parameter
- `@returns` — what the function returns and when
- `@throws` — error conditions
- Skip trivial getters/setters — document behavior, not boilerplate

### 7.3 Inline Comments

Use inline comments to explain:
- Business rules and domain constraints ("Tasks must be 30-180 minutes because…")
- Non-obvious logic or algorithms
- Workarounds with links to related issues
- "Why" decisions, not "what" the code does

If the code needs a "what" comment, rewrite the code to be clearer instead.

---

## 8. Logging

Console logs are not logging.

Use structured logging with levels:

- debug
- info
- warn
- error

Logs are production tools.

---

## 9. Dependencies

Every dependency adds risk.

Prefer fewer dependencies.
Prefer stable dependencies.
Avoid novelty for novelty’s sake.

---

## End of Document
