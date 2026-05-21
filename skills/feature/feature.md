---
description: Spec-driven feature development wrapping spec-kit early phases (specify → clarify → plan → tasks). Searches QMD for prior art and uses code-nav to analyze affected code before starting.
argument: description - what feature you want to implement
---

# Feature: Spec-Kit guided workflow

Starting Spec-Kit workflow for: **$ARGUMENTS**

---

## Phase 0 — Setup

**Ask the user these three questions before doing anything else:**

1. "Output format for the spec and plan — `html` (opens in browser) or `markdown` (inline)?"
2. "Create the feature branch automatically when we reach implementation? (`yes` / `no`)"
3. "Scope — `lean` (specify → plan, fast) or `full` (specify → clarify → checklist → plan → tasks)?"

Store answers as:
- `OUTPUT_FORMAT`: `html` or `markdown`
- `CLAUDE_BRANCHES`: `yes` or `no`
- `SCOPE`: `lean` or `full`

Wait for all three answers before continuing.

---

## Phase 1 — Load context

Dispatch the `code-researcher` agent and QMD search in parallel:

**QMD — prior art and decisions:**
```
query(collection: "<project-collection>", searches: [
  {type: "lex", query: "<feature keywords>"},
  {type: "vec", query: "<feature description>"}
], intent: "prior implementations, ADRs, or sessions related to this feature")
```

**code-researcher — affected code:**
Which modules, files, and dependencies will be touched by this feature.

Present a summary: prior art found + affected files map.

**STOP — Ask:** "Context loaded. Anything to add before I write the spec?"

Wait for go-ahead before continuing.

---

## Phase 2 — Specify

Initialise spec-kit if `.specify/` is missing:
```bash
specify init . --integration claude
```

Add missing entries to `.gitignore`:
```bash
GITIGNORE=".gitignore"
[ ! -f "$GITIGNORE" ] && touch "$GITIGNORE"
for entry in ".specify/" "specs/"; do
  grep -qF "$entry" "$GITIGNORE" || echo "$entry" >> "$GITIGNORE"
done
```

Invoke `/speckit.specify` passing: description + prior art context + affected files map.

If `OUTPUT_FORMAT` is `html`:
- Generate a complete `<html>` version with inline CSS
- Write to `specs/<name>/spec.html`
- Open: `open specs/<name>/spec.html`

If `OUTPUT_FORMAT` is `markdown`, present spec inline.

**STOP — Ask:** "Spec ready. Approve to move to planning, or tell me what to change."

Wait for explicit approval before continuing.

---

## Phase 3 — Plan

Invoke `/speckit.plan`.

If `SCOPE` is `full`: invoke `/speckit.clarify` first if ambiguities exist, then `/speckit.checklist`.

If `OUTPUT_FORMAT` is `html`:
- Generate `specs/<name>/plan.html` with same styling
- Open: `open specs/<name>/plan.html`

**STOP — Ask:** "Plan ready. Approve to generate tasks, or tell me what to adjust."

Wait for explicit approval before continuing.

---

## Phase 4 — Tasks (only if SCOPE = full)

Invoke `/speckit.tasks`.

If `OUTPUT_FORMAT` is `html`:
- Generate `specs/<name>/tasks.html`
- Open: `open specs/<name>/tasks.html`

---

## Done

Artefacts saved to `specs/`. Next steps:

- **If `CLAUDE_BRANCHES` is `yes`**: create branch `feature/<spec-short-name>` now
- **If `CLAUDE_BRANCHES` is `no`**: remind the user to create it manually

No `Co-Authored-By` or AI attribution in any commits.

---

## Rules

- ALWAYS ask the three setup questions BEFORE loading context
- ALWAYS wait for explicit approval between phases — never auto-advance
- Never start implementation — this command covers up to task generation only
