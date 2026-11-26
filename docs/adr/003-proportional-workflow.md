# ADR 003 — Proportional workflow: delegation by reason and Spec Kit only for large work

**Date:** 2026-11-04  
**Status:** Accepted

## Context

The earlier setup leaned on subagents and Spec Kit for most tasks. For small changes that costs more context and turns than it saves. gentle-ai, which we looked at for Engram, retired its own spec-driven development (SDD) in v4.0 in favour of ODD, which is a signal that heavy process everywhere does not pay off.

## Decision

The rules shipped in the `fran-setup` block of `~/.claude/CLAUDE.md`:

- Work inline by default. Delegate to a subagent only for a named reason: explore unfamiliar code (more than about 5 searches), parallel writers on independent files, context handoff in a long session, or independent verification of a high-risk change. When in doubt, inline.
- Use Spec Kit only for large work (several sessions, external waits, or requirements that would not survive compaction). Small work goes direct, with no spec.
- Test first when a runnable test with a clear result exists.
- Classify each change by risk (low, medium, high). Only high risk triggers the review agents, in one correction round.
- Engram holds what we learn; QMD holds reference docs.

## Reasons

- Delegation has a fixed cost. It pays off for exploration, real parallelism and independent review, not for size alone.
- Spec Kit artefacts are worth the overhead only when the work outlives one session.
- Review effort should match risk.

## Tradeoffs

- The judgment about "small" vs "large" is left to the user and the agent; borderline cases may be misjudged.
- Less automatic review on medium-risk changes. Tests are the safety net there.

## Consequences

The installer manages the block between the `fran-setup` markers and leaves text outside them alone. The `/run-tasks` command ships in `commands/` and is installed to `~/.claude/commands/`. It executes Spec Kit's `tasks.md` for large work. The docs describe delegation by reason instead of by task size.
