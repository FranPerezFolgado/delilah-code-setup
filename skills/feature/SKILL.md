---
name: feature
description: Spec-driven feature development with Spec Kit — prior art from QMD, affected code from code-researcher, then specify → (clarify → checklist) → plan → tasks with approval between phases, and finally implementation, orchestrated with subagents or plain /speckit-implement. Use when the user wants to build a new feature from a description.
argument-hint: "<feature description>"
---

# Feature: Spec-Kit guided workflow

Starting Spec-Kit workflow for: **$ARGUMENTS**

> **RTK active** — all Bash commands are automatically rewritten by the PreToolUse hook.

---

## Phase 0 — Load context

If no description was passed, ask the user what feature they want to build.

If `.specify/` doesn't exist in the repo root, initialise Spec Kit first:
```bash
specify init . --integration claude
```

Dispatch the `code-researcher` agent and QMD search in parallel:

**QMD — prior art and decisions** (collections in the local `CLAUDE.md`, `## QMD Collection`):
```
query(collection: "<project-collection>", searches: [
  {type: "lex", query: "<feature keywords>"},
  {type: "vec", query: "<feature description>"}
], intent: "prior implementations, ADRs, or sessions related to this feature")
```
If QMD doesn't answer or the project has no collection, say so in one line and continue.

**code-researcher — affected code:**
Which modules, files, and dependencies will be touched by this feature.

Present a summary of findings: prior art (and whether to build on it) and a brief map of affected files.

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
      "question": "Work on a feature branch with commits?",
      "header": "Branch",
      "multiSelect": false,
      "options": [
        { "label": "yes", "description": "Feature branch before the spec, commits per phase and per work package" },
        { "label": "no", "description": "Stay on the current branch, no commits" }
      ]
    },
    {
      "question": "Which phases to run?",
      "header": "Scope",
      "multiSelect": false,
      "options": [
        { "label": "lean", "description": "specify → plan (→ tasks if you implement) — fast, good for exploration" },
        { "label": "full", "description": "specify → clarify → checklist → plan → tasks — production-ready" }
      ]
    },
    {
      "question": "How to implement once the tasks are approved?",
      "header": "Implement",
      "multiSelect": false,
      "options": [
        { "label": "orchestrated", "description": "Subagents per work package, test-first, parallel where files don't overlap, review per phase" },
        { "label": "normal", "description": "/speckit-implement in this session" },
        { "label": "none", "description": "Stop after planning" }
      ]
    }
  ]
}
```

Store answers as `OUTPUT_FORMAT`, `CLAUDE_BRANCHES`, `SCOPE`, `IMPLEMENTATION`.
If `IMPLEMENTATION` isn't `none`, tasks are generated even when `SCOPE` is `lean`.

Wait for all answers before continuing.

---

## Phase 1 — Specify

**Branch** — decide it before the spec, so specs and code land on the same branch:
- `CLAUDE_BRANCHES` = `yes`: if `.specify/extensions.yml` has an enabled `before_specify` hook `speckit.git.feature`, Spec Kit creates the branch itself when specify runs — don't create another. Otherwise create `feature/<kebab-case-name>` now.
- `CLAUDE_BRANCHES` = `no`: stay on the current branch. If that `before_specify` hook is enabled, tell the user it would create a branch anyway and ask whether to skip it for this run.

**Git tracking** — if the repo already tracks `specs/` or `.specify/` (`git ls-files specs .specify | head -1`), leave `.gitignore` alone. Otherwise add only the missing entries:
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

**Plan review** — before showing the plan, launch `architecture-reviewer` on it (a plan, not a diff):
give it `spec.md`, `plan.md` and the affected files map, and ask for module boundaries, coupling, contract
and migration impact, and anything the plan builds that the spec doesn't ask for — CRITICAL/HIGH/MEDIUM/LOW,
at most ~20 lines. Never pass it your own reasoning about the plan. Fix the CRITICAL/HIGH findings in
`plan.md` yourself (at most 2 rounds; if they don't converge, show them to the user as open), and keep the
rest for the summary.

If `OUTPUT_FORMAT` is `html`: generate `specs/<name>/plan.html` and open it.

Show the plan with a short "Plan review" block: what the reviewer found and what you changed.

**STOP — Ask the user:** "Here is the technical plan. Review it and let me know: approve to generate tasks, or tell me what to adjust."

Do not proceed until the user explicitly approves (e.g., "approved", "looks good", "go ahead").

---

## Phase 3 — Tasks (if SCOPE = full, or IMPLEMENTATION isn't none)

Invoke the `speckit-tasks` skill.

If `SCOPE` is `full`: invoke the `speckit-analyze` skill and fix the CRITICAL/HIGH inconsistencies it
reports in `spec.md`/`plan.md`/`tasks.md` before showing the tasks; list the rest.

If `OUTPUT_FORMAT` is `html`: generate `specs/<name>/tasks.html` and open it.

If `IMPLEMENTATION` isn't `none`: **STOP — Ask the user** to approve the tasks before implementing.

---

## Phase 4 — Implement

- `orchestrated`: invoke the `orchestrate` skill with the feature dir, `OUTPUT_FORMAT`, `CLAUDE_BRANCHES` and
  `AUTONOMY=auto` (the user already approved spec, plan and tasks; pass `AUTONOMY=step` only if they asked to
  approve each phase).
  The planning phases have filled this session's context; offer to continue here or to run `/orchestrate`
  in a new session (it picks everything up from `specs/<name>/`, and is cheaper).
- `normal`: invoke the `speckit-implement` skill.
- `none`: skip.

---

## Done

- Artefacts: paths to `spec.md`, `plan.md`, `tasks.md` (and `packages.md`, `progress.md` if orchestrated).
- Active branch, if any. If `CLAUDE_BRANCHES` is `no`, remind the user to create one before opening a PR.
- No `Co-Authored-By` or AI attribution in any commits.
- To resume later: `/orchestrate` (orchestrated) or `/speckit-implement`; artefacts persist in `specs/<name>/`.

---

## Rules

- ALWAYS use AskUserQuestion tool after presenting the context summary — never ask in plain text
- ALWAYS wait for explicit approval between phases — never auto-advance
- Implement only in Phase 4, the way `IMPLEMENTATION` says
