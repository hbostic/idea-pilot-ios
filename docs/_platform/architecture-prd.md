# Idea Pilot — Architecture PRD

This document defines the structural invariants of the Idea Pilot platform.

It is not a code specification.
It is a system contract.

If implementation violates this document, the architecture is wrong.

---

## 1. System Overview

Idea Pilot is a multi-tier platform:

- Backend API (System of Record)
- iOS Client
- Web Client (future)
- Android Client (future)

Each tier is independently deployable.

No tier may depend on private internals of another tier.

All communication occurs through versioned APIs.

---

## 2. Canonical Truth Model

The backend is the canonical source of truth.

Clients are offline-first replicas that synchronize with the backend.

Clients may cache.
Clients may predict.
Clients may queue mutations.

Clients may not redefine business rules.

All invariants must be enforceable server-side.

---

## 3. Tier Responsibilities

### Backend

- owns canonical schema
- enforces validation
- enforces phase rules
- enforces task constraints
- resolves conflicts
- maintains audit trail
- exposes versioned APIs

### Clients

- provide UX
- maintain local cache
- enable offline operation
- queue mutations
- render execution flows

Clients do not define business rules.

---

## 4. API Contracts

APIs are contracts, not suggestions.

Rules:

- Breaking changes require version bump
- Deprecated endpoints must be supported during migration
- Clients must tolerate unknown fields
- Backend must tolerate older clients

No silent behavior changes.

---

## 5. Sync Model (MVP)

Conflict strategy: last-write-wins.

Each record carries:

- updated_at timestamp
- stable ID

Clients reconcile based on server authority.

Future enhancement: field-level merge for rich text.

---

## 6. Offline Invariants

Execution must remain possible offline.

Users must be able to:

- view Now tasks
- capture ideas
- modify lanes
- complete tasks

Network recovery triggers sync.

Offline is not a degraded mode.
It is a primary mode.

---

## 7. Deployment Invariants

Each tier must deploy independently.

Backend deploy must not require client redeploy.
Client deploy must not require backend redeploy.

Tight coupling is architectural failure.

---

## 8. Forbidden Patterns

The system must not:

- embed business logic in UI
- share database across tiers
- bypass API contracts
- depend on synchronous cross-tier calls
- require lockstep releases

Shortcuts become permanent architecture.

---

## 9. Evolution Rule

Architecture must grow by extension, not mutation.

We add layers.
We do not rewrite foundations casually.

Breaking invariants requires a formal ADR.

---

## End of Document
