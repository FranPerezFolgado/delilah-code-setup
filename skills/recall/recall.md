---
name: recall
description: Recovers context before starting work. Searches Engram for session memory (decisions, bugs, conventions) and QMD only for docs, specs and ADRs. Run at the start of every session.
argument: topic - what to search for (optional; if omitted, loads recent project context)
---

# Recall

Session memory lives in Engram. Reference docs (docs/, specs/, ADRs) live in QMD.

## Steps

### 1. Recent context
Call `mem_current_project`, then `mem_context` for the recent project history.

### 2. Search by topic
Search query: "$ARGUMENTS" (if no argument, skip to step 3 with the recent context only).
Call `mem_search` with the topic keywords: project scope first, then personal scope.

### 3. Full content
For each relevant hit, call `mem_get_observation` to read the full untruncated content. Search results are truncated.

### 4. Docs, specs and ADRs (QMD)
Only for documentation, specs and ADRs: check the local `CLAUDE.md` for a `## QMD Collection` section and delegate to the `doc-searcher` subagent with that collection.
If no collection is configured, say so and suggest `/project-setup` or `/setup-qmd`; this does not affect steps 1 to 3.

## If Engram fails

If an Engram call fails or the `mem_*` tools are missing, say explicitly: "Engram is not responding."
Suggest checking `claude mcp list | grep engram`, and stop the memory part there.
Do NOT silently fall back to QMD for session memory: QMD no longer holds it.

## Output

Return what was found with its source (observation id and title, or doc path). Do not answer from memory; use only what Engram and QMD return.
