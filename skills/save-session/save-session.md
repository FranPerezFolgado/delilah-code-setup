---
name: save-session
description: Saves the current session to Engram — decisions, bugs and conventions with mem_save, then a session summary with mem_session_summary. Checks for undocumented ADRs first so they're included.
argument: topic - short name for what was worked on (e.g. auth-refactor)
---

# save-session

Saves session context to Engram so future sessions recover it with `mem_context` / `mem_search`.
Reference documentation (specs, ADRs, docs/) stays in QMD; don't copy it into Engram, point to it.

> **RTK active** — all Bash commands are automatically rewritten by the PreToolUse hook.

## Steps

### 1. Determine topic and project
Use the argument if provided. Otherwise derive a short name from what was worked on.
Call `mem_current_project` and use that project for every write below.

### 2. Detect pending ADRs first
Run `/adr-check` to scan for important decisions made during the session that aren't yet documented.

If candidates are found:
- Present them to the user
- Ask which ones to document now
- Run `/adr` for each selected one
- Wait for completion before continuing

This ensures the session summary reflects any ADRs written during the session.

### 3. Save durable learnings with `mem_save`
One observation per idea, only for what is durable and costly to reconstruct:

| Kind | `type` |
|---|---|
| Decision and its why (not already in an ADR / decisions doc) | `decision` |
| Non-obvious bug and its root cause | `bugfix` |
| Convention discovered or agreed | `pattern` |
| Finding about a tool, API or environment | `discovery` / `config` |

For each one:
1. `mem_search` the topic in this project first. If a match exists, read it with
   `mem_get_observation`; same topic → `mem_update` by id (keep its `topic_key`), already covered → skip.
2. Otherwise `mem_save` with a distinct `topic_key`, content as **What / Why / Where / Learned**,
   and `path:line` references instead of pasted code.
3. Scope: `project` for this repo; `personal` for facts about your own tools that aren't specific to it.
   If the memory depends on a specific tool version, put the version in the title (e.g. "QMD 2.1: ignore is YAML-only").
4. If the save returns `judgment_required`, resolve it with `mem_judge` (ask the user when unsure).

Skip routine progress, file lists and anything the docs or git history already record.

### 4. Save the session summary with `mem_session_summary`
```markdown
## Goal
<one sentence>

## Instructions
<user preferences or constraints discovered; skip if none>

## Discoveries
- <gotchas and learnings, with ids of the observations saved in step 3>

## Accomplished
- ✅ <done>
- 🔲 <identified, not done>
- ADRs written: <paths from step 2>

## Next Steps
- <what to pick up next, open questions>

## Relevant Files
- <path> — <role or what changed>
- <specs/ artefacts if spec-kit was used>
```

### 5. Confirm
- Observations saved / updated in step 3 (id + title)
- That the session summary was saved, and the project it went to

## Notes

- Session notes are no longer written to disk; Engram is the only store for session memory.
- Don't run `qmd update` / `qmd embed` here unless step 2 wrote an ADR into `docs/`.
