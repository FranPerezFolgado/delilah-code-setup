---
description: Saves a structured summary of the current session to sessions/ and re-indexes QMD. Checks for undocumented ADRs first so they're included in the saved summary.
argument: topic - descriptive name for the file (e.g. auth-refactor)
---

# save-session

Saves session context to QMD so `/recall` finds it in future sessions.

## Steps

### 1. Determine topic
Use the argument if provided. Otherwise derive a short name from what was worked on.

### 2. Detect pending ADRs first
Run `/adr-check` to scan for important decisions made during the session that aren't yet documented.

If candidates are found:
- Present them to the user
- Ask which ones to document now
- Run `/adr` for each selected one
- Wait for completion before continuing

This ensures the session summary reflects any ADRs written during the session.

### 3. Generate structured summary
Save to `docs/sessions/YYYY-MM-DD-<topic>.md`:

```markdown
# Session: <topic>
Date: YYYY-MM-DD

## What was done
- <bullet points>

## Decisions made
- <decisions with reasoning>
- ADRs written: <list any ADRs created in step 2, with paths>

## Files changed
- <main files touched>

## Context for next session
- <what to know before continuing>
- <open questions or next steps>

## Specs generated (if any)
- <links to specs/ artefacts if spec-kit was used>
```

### 4. Index sessions and specs into QMD
```bash
qmd collection add ./docs/sessions --name <project-collection> 2>/dev/null || true
[ -d specs ] && qmd collection add ./specs --name <project-collection> 2>/dev/null || true
```

### 5. Re-index QMD
```bash
qmd embed
```

### 6. Confirm
- Path of saved file
- Document count in updated QMD collection

## Notes

- `docs/sessions/` is in `.gitignore` — local only, never committed.
- The project collection name comes from the local `CLAUDE.md` (`## QMD Collection`).
