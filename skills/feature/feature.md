---
description: Spec-driven feature development wrapping spec-kit early phases (specify → clarify → plan → tasks). Searches QMD for prior art and uses code-nav to analyze affected code before starting.
argument: description - what feature you want to implement
---

# feature

Spec-driven feature development wrapping the early phases of spec-kit.
Usage: `/feature <feature description>`

## Flow

### 1. Get description
If not passed as argument, ask the user what feature they want to implement.

### 2. Search for prior art in QMD
Before anything else, search QMD for similar work already implemented or specified.

Run in parallel:

**Project collection** (defined in local `CLAUDE.md` under `## QMD Collection`):
```
query(collection: "<project-collection>", searches: [
  {type: "lex", query: "<feature keywords>"},
  {type: "vec", query: "<semantic description of the feature>"}
], intent: "prior implementations or specs for this feature")
```

**Global collections** (if relevant collections from other projects exist):
```
query(searches: [
  {type: "vec", query: "<semantic description of the feature>"}
], intent: "similar features done in other projects")
```

Present relevant results to the user:
- If prior art found: show what exists, where, and ask if they want to build on it
- If nothing found: continue

### 3. Analyse affected code with code-nav
Delegate to the `code-researcher` subagent to identify which parts of the codebase will be affected by the feature:
- Modules, classes, or services related to the feature area
- Files likely to change
- Relevant dependencies (what calls what in that area)

Show the user a brief map of affected files/modules before continuing. This feeds context into spec-kit.

### 4. Ask three questions

- **Output format**: `markdown` (only .md files) or `html` (reports + .md)
- **Auto branch and commits**: `yes` — creates `feature/<name>` / `no`
- **Scope**: `lean` (specify → plan) or `full` (specify → clarify → checklist → plan → tasks)

### 5. Initialise spec-kit if missing
Check if `.specify/` exists in the current directory.

If not:
```bash
specify init . --integration claude
```

Add only missing entries to `.gitignore`:
```bash
GITIGNORE=".gitignore"
[ ! -f "$GITIGNORE" ] && touch "$GITIGNORE"
for entry in ".specify/" "specs/"; do
  grep -qF "$entry" "$GITIGNORE" || echo "$entry" >> "$GITIGNORE"
done
```

### 6. Run phases

**Always:**
- `/speckit.specify` — pass description + prior art context + affected files map

**If `full`:**
- `/speckit.clarify` if ambiguities detected
- `/speckit.checklist`

**Always:**
- `/speckit.plan`

**If `full`:**
- `/speckit.tasks`

### 7. Branch management (if auto-branch = yes)
```bash
git checkout -b feature/<kebab-case-name>
```

Any commits made (spec artefacts, implementation, or otherwise) must never include `Co-Authored-By` lines or AI attribution. Plain commits only.

### 8. Report to user
- Artefacts created: paths to `spec.md`, `plan.md`, `tasks.md`
- Active branch (if created)
- Suggested next step: `/speckit.implement` or `/speckit.tasks`

## Notes

- Artefacts in `specs/` and `.specify/` are in `.gitignore` — local only, not committed.
- To resume a paused feature: artefacts persist in `specs/<name>/`.
