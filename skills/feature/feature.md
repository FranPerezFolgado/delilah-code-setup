---
description: Spec-driven feature development wrapping spec-kit early phases (specify → clarify → plan → tasks). Searches QMD for prior art and uses code-nav to analyze affected code before starting.
argument: description - what feature you want to implement
---

# feature

## FIRST ACTION — before anything else

If no argument was passed, ask the user for the feature description in a single message.

Then **immediately** call the AskUserQuestion tool with these exact parameters — do not ask in plain text, do not proceed without calling the tool:

```json
{
  "questions": [
    {
      "question": "Output format for spec artefacts?",
      "header": "Format",
      "multiSelect": false,
      "options": [
        { "label": "markdown", "description": "Only .md files in specs/" },
        { "label": "html", "description": "HTML reports + .md files" }
      ]
    },
    {
      "question": "Create a feature branch automatically?",
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

Wait for all three answers before continuing.

---

## Flow (after questions are answered)

### 1. Search for prior art in QMD
Run in parallel:

**Project collection** (defined in local `CLAUDE.md` under `## QMD Collection`):
```
query(collection: "<project-collection>", searches: [
  {type: "lex", query: "<feature keywords>"},
  {type: "vec", query: "<semantic description of the feature>"}
], intent: "prior implementations or specs for this feature")
```

**Global collections**:
```
query(searches: [
  {type: "vec", query: "<semantic description of the feature>"}
], intent: "similar features done in other projects")
```

If prior art found: show what exists and ask if they want to build on it.

### 2. Analyse affected code
Delegate to the `code-researcher` subagent: which modules, files, and dependencies will be affected.

Show a brief map before continuing.

### 3. Initialise spec-kit if missing
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

### 4. Run phases

**Always:** invoke `/speckit.specify` passing description + prior art context + affected files map

**If scope = full:** invoke `/speckit.clarify` if ambiguities detected, then invoke `/speckit.checklist`

**Always:** invoke `/speckit.plan`

**If scope = full:** invoke `/speckit.tasks`

### 5. Branch (if branch = yes)
```bash
git checkout -b feature/<kebab-case-name>
```

No `Co-Authored-By` or AI attribution in any commits.

### 6. Report
- Artefacts created with paths
- Active branch if created
- Next step: `/speckit.implement` or `/speckit.tasks`
