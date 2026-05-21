---
description: Scans recent changes and session context to detect decisions worth documenting as ADRs. Offers to write them with the /adr skill.
---

# adr-check

Detects important architectural decisions that should be documented as ADRs but aren't yet.

## Steps

### 1. Gather context

```bash
git diff main...HEAD --stat
git diff main...HEAD
ls docs/adr/ 2>/dev/null || echo "no ADRs yet"
```

### 2. Identify ADR candidates

Look for patterns in the diff and session context that indicate decisions:

**Strong signals** (almost always an ADR):
- New dependency added to package.json / go.mod / Cargo.toml / pyproject.toml
- Framework, core library, or database change
- New integration with an external service
- Architectural change: new layer, new pattern (Repository, Event Sourcing, etc.)
- Decision NOT to do something obvious, with explicit reasoning

**Moderate signals** (ADR if the change is significant):
- Auth or session management strategy change
- Data format or inter-service communication protocol change
- New directory structure or naming conventions
- Testing strategy change

**Not ADRs:**
- Internal refactors without interface changes
- Bug fixes
- Adding tests
- Style or formatting changes

### 3. Compare against existing ADRs
Check that candidates aren't already documented in `docs/adr/`.

### 4. Present candidates

For each candidate:
```
📋 CANDIDATE: <short title>
   Decision: <what was decided in one line>
   Evidence: <file or change that indicates it>
   → Run /adr to document this
```

If no candidates: `✅ No undocumented decisions detected in recent changes.`

### 5. Offer to write
Ask if the user wants to document any of the candidates. If yes, run `/adr` for each selected one.
