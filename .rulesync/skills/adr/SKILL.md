---
name: adr
description: >
  Use this skill whenever the user wants to create, write, or document an Architecture Decision Record (ADR).
  Trigger on phrases like "write an ADR", "create a decision record", "document why we chose X", "ADR for",
  "register this decision", or "why did we pick X". Also trigger when the user describes a technical decision
  — about databases, messaging systems, frameworks, infrastructure, or architecture — and wants it formally
  documented. Even if the user just says "can you write that up as an ADR?", use this skill.
  The skill produces honest, concise, 1-page ADR documents that acknowledge tradeoffs rather than selling the chosen solution.
---

# ADR Skill

Creates Architecture Decision Records (ADRs) — short, honest documents that capture why a technical decision was made, what alternatives were considered, and what the real tradeoffs are (including the downsides).

## What is an ADR

An ADR records a significant architectural decision: the context that forced it, what was decided, what else was considered and why it was rejected, and the honest consequences — including costs and risks of the chosen option.

The key quality is **honesty**. A good ADR does not sell the decision — it documents it. If the chosen option is overkill for current volume, say so and justify it on future capability. If an alternative was tempting but rejected for a specific reason, name that reason concretely.

## File location and naming

ADRs go in `docs/adr/` inside the project (create the folder if it doesn't exist).

**Filename format**: `ADR-NNN-short-kebab-title.md`

Examples:
- `ADR-001-kafka-vs-simple-queues.md`
- `ADR-002-postgresql-vs-nosql.md`
- `ADR-003-react-vs-vue.md`

The number (`NNN`) is sequential and zero-padded to 3 digits. Check existing files in `docs/adr/` to determine the next number; start at `001` if none exist.

## ADR template

Use this structure exactly:

```markdown
# ADR-NNN: [Decision Title]

- **Status**: Accepted
- **Date**: YYYY-MM-DD

## Context

[2–4 sentences. Describe the situation that made this decision necessary.
Name the concrete actors: specific services, data shapes, access patterns, team constraints.
Explain *why* a decision was needed — what problem or constraint forced the choice.]

## Decision

[1–2 sentences. State what was decided, directly.]

## Alternatives considered

**[Option A name]** — *Rejected*
[1–2 sentences. Concrete reason this option doesn't fit *this specific situation*. Not a generic criticism — tied to the actual context above.]

**[Option B name]** — *Rejected*
[1–2 sentences. Same principle.]

**[Chosen option name]** — *Accepted*

## Consequences

✅ [Concrete benefit — name the capability or property gained, not an abstraction]
✅ [Another specific benefit]
❌ [Honest cost or operational burden — don't omit this]
❌ [Another cost, risk, or limitation]

## When to reconsider

[A specific, actionable trigger. Not "if requirements change". Name a metric threshold,
a structural change, a volume milestone, or a team event that would make this worth revisiting.]
```

## Writing guidance

### Context
Describe the situation, not the solution. Name the actual services, data types, consumers, or constraints. Make it concrete enough that someone reading in 18 months understands why this decision was forced.

### Decision
One sentence. What was chosen. The "why" lives in the alternatives and consequences sections.

### Alternatives considered
For each rejected option, give a reason tied to *this specific project's context* — not a generic technology critique.

Bad: "MongoDB doesn't support joins."
Good: "MongoDB lacks native joins, which we need for artist↔recommendation queries; we'd have to replicate that logic in application code."

### Consequences
- Always include at least one ❌. If there are no downsides, the decision wasn't hard enough to merit an ADR.
- Make ✅ benefits concrete: what capability does this enable? Prefer "replay del stream para recalibrar el scorer sin re-ingestar" over "flexibility".
- Be explicit if the choice is overengineered for current volume — acknowledge it and justify by the specific future capability it enables.

### When to reconsider
Make it actionable. Specify a concrete trigger — a metric, a structural change, a time window — not vague conditions.

Good: "If after 6 months there's only one consumer per topic and replay has never been used, simplify to RabbitMQ."
Bad: "If the system grows."

### Tone
Write like an engineer explaining to a colleague, not a vendor pitch. Acknowledge tradeoffs honestly. Avoid buzzwords as justification — name the concrete capability instead.

## Step-by-step

1. **Gather content** — Extract from the conversation (or ask the user) the key elements:
   - What was decided?
   - What alternatives were considered and why were they rejected?
   - What is the context/constraints that made this decision necessary?
   - What are the real consequences, including downsides?

2. **Determine ADR number** — If you have access to the project files, check `docs/adr/` for existing ADRs and use the next sequential number. Otherwise ask the user.

3. **Write the ADR** following the template above.

4. **Save the file** to `docs/adr/ADR-NNN-short-title.md`.

5. **Confirm** the file path to the user.
