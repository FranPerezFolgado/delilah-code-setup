---
description: Searches QMD for relevant context before starting work. Run at the start of every session.
argument: topic - what to search for (optional; if omitted, loads general project context)
---

# Recall

Delegate to the `doc-searcher` subagent.

## Before searching

Check the local `CLAUDE.md` for a `## QMD Collection` section.

If no collection is configured:
> "No QMD collection found for this project. Run `/project-setup` to initialise the project, or `/setup-qmd` to index just the docs."
> Stop here — do not attempt to search.

## Search

Search query: "$ARGUMENTS" (if no argument, search for general project context, architecture decisions, and recent session summaries).

The agent will search the active project collection and return relevant excerpts with source paths.

Do not answer from memory — use only what QMD returns.
