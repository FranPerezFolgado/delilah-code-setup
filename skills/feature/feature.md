---
description: Spec-driven feature development wrapping spec-kit early phases (specify → clarify → plan → tasks). Searches QMD for prior art and uses code-nav to analyze affected code before starting.
argument: description - what feature you want to implement
---

# Feature: Spec-Kit guided workflow

Starting Spec-Kit workflow for: **$ARGUMENTS**

---

## Phase 0 — Load context

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

Present a summary of findings.

Then use the AskUserQuestion tool with these exact parameters:

```json
{
  "questions": [
    {
      "question": "Output format for the spec and plan?",
      "header": "Format",
      "multiSelect": false,
      "options": [
        { "label": "markdown", "description": "Only .md files in specs/" },
        { "label": "html", "description": "HTML reports + .md files, opened in browser" }
      ]
    },
    {
      "question": "Create the feature branch automatically?",
      "header": "Branch",
      "multiSelect": false,
      "options": [
        { "label": "yes", "description": "Creates feature/<name> branch" },
        { "label": "no", "description": "Local only, no branch created" }
      ]
    },
    {
      "question": "Which phases to run?",
      "header": "Scope",
      "multiSelect": false,
      "options": [
        { "label": "lean", "description": "specify → plan — fast, good for exploration" },
        { "label": "full", "description": "specify → clarify → checklist → plan → tasks — production-ready" }
      ]
    }
  ]
}
```

Store answers as `OUTPUT_FORMAT`, `CLAUDE_BRANCHES`, `SCOPE`.

Wait for all answers before continuing.

---

## Phase 1 — Specify

Add missing entries to `.gitignore`:
```bash
GITIGNORE=".gitignore"
[ ! -f "$GITIGNORE" ] && touch "$GITIGNORE"
for entry in ".specify/" "specs/"; do
  grep -qF "$entry" "$GITIGNORE" || echo "$entry" >> "$GITIGNORE"
done
```

Invoke the `speckit-specify` skill passing: description + prior art context + affected files map.

If `OUTPUT_FORMAT` is `html`: generate `specs/<name>/spec.html` and open it.
If `OUTPUT_FORMAT` is `markdown`: present spec inline.

**STOP — Ask the user:** "Here is the spec. Review it and let me know: approve to move to planning, or tell me what to change."

Do not proceed until the user explicitly approves (e.g., "approved", "looks good", "go ahead").

---

## Phase 2 — Plan

If `SCOPE` is `full`: invoke the `speckit-clarify` skill if ambiguities exist, then `speckit-checklist`.

Invoke the `speckit-plan` skill.

If `OUTPUT_FORMAT` is `html`: generate `specs/<name>/plan.html` and open it.

**STOP — Ask the user:** "Here is the technical plan. Review it and let me know: approve to generate tasks, or tell me what to adjust."

Do not proceed until the user explicitly approves (e.g., "approved", "looks good", "go ahead").

---

## Phase 3 — Tasks (only if SCOPE = full)

Invoke the `speckit-tasks` skill.

If `OUTPUT_FORMAT` is `html`: generate `specs/<name>/tasks.html` and open it.

---

## Done

- If `CLAUDE_BRANCHES` is `yes`: create branch `feature/<spec-short-name>`
- If `CLAUDE_BRANCHES` is `no`: remind user to create it manually
- No `Co-Authored-By` or AI attribution in any commits

---

## Rules

- ALWAYS use AskUserQuestion tool after presenting the context summary — never ask in plain text
- ALWAYS wait for explicit approval between phases — never auto-advance
- Never start implementation — this skill covers up to task generation only
