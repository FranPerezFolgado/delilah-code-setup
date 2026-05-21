# Project Constitution

This constitution codifies the architectural and code-quality rules enforced
in this project. Compliance is a prerequisite for Pull Request approval.

**Customise this file for your project.** Replace the generic principles below
with the specific conventions of your stack and team. The governance structure
and gates are ready to use as-is.

---

## Core Principles

### I. Separation of Concerns (NON-NEGOTIABLE)

Business logic must not live in entry points (controllers, views, handlers,
routes). Entry points are adapters and nothing more.

- Business logic lives in a dedicated service or domain layer.
- Each layer has a single, clear responsibility.
- Cross-cutting concerns (logging, auth, validation) are handled at the
  appropriate boundary, not scattered across layers.

### II. Service Layer for Business Logic (NON-NEGOTIABLE)

Services encapsulate domain operations and are the default home for:
- Complex algorithms and multi-step orchestrations.
- Calls to external systems (APIs, queues, file systems).
- Any logic with potential for reuse across multiple entry points.

Services MUST be unit-testable without simulating a full HTTP request.

### III. Typed Contracts

- Functions with ≥5 parameters MUST encapsulate them in a typed object
  (dataclass, Pydantic model, TypeScript interface, etc.).
- Every external API integration MUST define typed DTOs that map the response.
  DTOs pin the external contract and surface silent upstream changes.

### IV. Documented APIs (NON-NEGOTIABLE)

Every public endpoint MUST have complete API documentation including:
- Description, HTTP method, inputs with types, outputs with examples,
  and all possible error codes.

### V. Testing Discipline

- Services and domain logic MUST be unit-testable.
- New endpoints SHOULD have integration tests covering the success path and
  at least the documented error codes.
- No `--no-verify` or hook bypass on commits.

### VI. No Magic Side Effects

Implicit hooks, signals, or event listeners that modify state as a side effect
of unrelated operations are an antipattern. New cross-entity workflows MUST
use explicit service method calls.

---

## Development Workflow & Quality Gates

- **Peer review is mandatory.** No PR is merged without the reviewer
  explicitly verifying constitution compliance.
- **Feature branches** are created in the affected repository, never in a
  parent or meta-repo.
- **Pushes target the feature branch only.** Automatic commits MUST NEVER
  target `main` or `develop`. Merges go through PR review.

### Knowledge Context Gate — QMD Consultation Before Specifying (NON-NEGOTIABLE)

Before writing any feature spec — whether calling `/speckit-specify` directly
or going through `/feature` — the agent MUST consult QMD to load relevant
context from the project knowledge base.

Concretely:

1. Before invoking `/speckit-specify`, run a QMD search using the feature
   description as the query across the project collection and sessions.
2. Load full documents with high relevance scores.
3. Present a context summary before proceeding to spec writing:
   existing related functionality, prior decisions, relevant ADRs,
   and detected constraints.
4. The agent MUST NOT start writing the spec until the developer
   acknowledges the context summary (or explicitly says to skip it).

**Rationale**: Projects accumulate prior decisions documented in QMD.
Speccing without loading context leads to re-inventing documented solutions
and contradicting prior ADRs. The `/feature` skill automates this gate.

---

## Governance

- Amendments require a PR against `.specify/memory/constitution.md`.
- Include a version bump and brief rationale for the change.
- **Versioning** (semantic):
  - **MAJOR**: removal or redefinition of a NON-NEGOTIABLE principle.
  - **MINOR**: new principle or section added.
  - **PATCH**: wording, typos, clarifications.

**Version**: 1.0.0 | **Created**: <!-- date -->
