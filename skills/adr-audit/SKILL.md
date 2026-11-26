---
name: adr-audit
description: >
  Use this skill when the user wants to check whether recent work has produced architectural decisions
  that should be documented as ADRs but aren't yet. Trigger on phrases like "audit our ADRs",
  "check if we're missing any ADRs", "what decisions should we document?", "any ADRs pending?",
  "review what we've built and see if we need to write ADRs", or at the end of a session after
  significant technical decisions have been made. Also trigger proactively when the user has just
  described or implemented a meaningful architectural choice (technology selection, structural pattern,
  integration approach) and there's no corresponding ADR in docs/adr/.
  The skill analyses what exists in docs/adr/ against what has been built or discussed, identifies gaps,
  and proposes — never auto-creates — specific ADRs for the user to approve.
---

# ADR Audit Skill

Reviews the current state of architectural decisions in a project and surfaces any that are undocumented.
The output is always a **proposal list** — never auto-created ADRs. The user decides what to document.

## What this skill does

1. Scans `docs/adr/` to understand what's already documented.
2. Analyses the project (code, config, conversation context) to identify architectural decisions that were made.
3. Compares both lists and identifies **gaps** — decisions made but not documented.
4. Presents a short, prioritised proposal to the user: "These decisions look undocumented. Want me to write any of them?"
5. If the user approves one or more, invokes the `adr` skill to write them.

## What counts as an ADR-worthy decision

Not every choice needs an ADR. Use this filter:

**Document it** if:
- A technology was chosen from multiple realistic alternatives (DB engine, message broker, framework, cloud provider)
- A structural pattern was adopted that will constrain future work (event-driven vs. request-response, monorepo vs. polyrepo, sync vs. async APIs)
- A tradeoff was consciously accepted (e.g. "we know this is overkill now but we want the capability later")
- The decision will surprise or confuse a new team member without context

**Skip it** if:
- It's a minor implementation detail (variable naming, folder structure within a module)
- It's provisional or exploratory ("let's try this for now")
- It's already obvious from the code itself with no meaningful alternatives considered
- It's a best practice with no real alternative (e.g. "we use git")

## Step-by-step

### 1. Read existing ADRs

Check `docs/adr/` for existing ADR files. For each one, extract:
- The decision title
- The technology or pattern documented

If `docs/adr/` doesn't exist or is empty, note that — the project has no ADRs yet.

### 2. Analyse the project for decisions made

Look at the evidence available — in order of priority:
- **Conversation context**: What technologies, patterns, or choices has the user described or discussed?
- **Config files**: `package.json`, `pyproject.toml`, `docker-compose.yml`, `Dockerfile`, `terraform/`, `k8s/` — these reveal technology choices
- **Key source files**: Entry points, service definitions, main modules — reveal structural patterns
- **README or docs**: May describe architectural intent

Extract a list of architectural decisions that are visible in the project.

### 3. Gap analysis

Compare what's documented against what's been decided. For each undocumented decision, assess:
- **Significance**: Would a new team member need to understand why this was chosen?
- **Alternatives**: Were there real alternatives that could have been picked instead?
- **Tradeoffs**: Is there a non-obvious cost or constraint that comes with this choice?

### 4. Present the proposal

Output a short, scannable list — not a wall of text. Format:

---
**ADRs already documented:** [list titles]

**Decisions that look undocumented:**

| # | Decision | Why it might need an ADR |
|---|----------|--------------------------|
| 1 | [e.g. Kafka as event bus] | Multiple alternatives existed; multi-consumer fan-out pattern constrains future services |
| 2 | [e.g. PostgreSQL as sole DB] | JSONB + GIN arrays are non-obvious choices; Neo4j was a real alternative |
| 3 | [e.g. TypeScript over JavaScript] | Team-specific context (3 months without integration tests) justifies the choice |

Which of these would you like me to document?
---

Keep the "Why" column honest — if a decision really doesn't need an ADR, don't include it.
Prioritise by impact: decisions that constrain the most future work go first.

### 5. Write approved ADRs

When the user approves one or more proposals, follow the `adr` skill to write each one. Ask for any missing context before writing — don't invent alternatives or consequences.

## Tone

Be direct and non-alarmist. The goal is not to create paperwork — it's to capture decisions that genuinely need context. If everything looks well-documented, say so. If there are 5 gaps but only 2 are really significant, say that too.

Never say "you should always document X" as a rule — evaluate each case on its actual significance.
