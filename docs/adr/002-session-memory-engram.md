# ADR 002 — Session memory moves from QMD to Engram

**Date:** 2026-11-04  
**Status:** Accepted

## Context

Session summaries were written as `.md` files in `docs/sessions/` by `/save-session` and indexed by QMD, so `/recall` found them with semantic search. QMD is a document search engine. Session memory mixed with reference docs made results noisy, and each save needed a file write plus a re-index. Claude Code also has its own auto-memory, which would be a second, separate store.

## Decision

Engram is the single store for what we learn while working: decisions and their why, non-obvious bugs, conventions, session summaries. `/recall` uses `mem_context` and `mem_search`; `/save-session` uses `mem_save` and `mem_session_summary`. QMD is restricted to reference docs (`docs/`, `specs/`, ADRs), with `ignore: ["sessions/**"]` on the docs collection. Claude Code auto-memory is disabled with `autoMemoryEnabled: false`. Everything stays local; Engram Cloud and `engram sync` are not used.

## Reasons

- Engram is built for this: typed memories, topic keys, dedup and conflict handling (`mem_judge`), export and import.
- One store avoids the same fact living in QMD notes, auto-memory and Engram at once.
- No files to write or re-index at the end of a session.
- QMD keeps doing what it is good at, searching reference documentation.

## Tradeoffs

- Memories are no longer plain files in the repo, so they are not browsable or greppable there. `engram export` and the TUI cover inspection and backup.
- One more tool to install (binary, plugin, MCP). The installer handles it and degrades to a hint if `brew` or `claude` is missing.
- Old `docs/sessions/` notes need a one-time migration: see [migration.md](../migration.md).

## Alternatives rejected

- **Keep `.md` notes in `docs/sessions/` indexed by QMD.** Rejected: no dedup or conflict handling, mixes memory with reference docs, and needs a manual re-index after every save.
- **Install gentle-ai wholesale.** Rejected: it brings a large framework of its own rules and workflow, far more than the one piece we need. We take Engram only and keep our own proportional workflow (see [ADR 003](003-proportional-workflow.md)).

## Consequences

`setup.sh` installs Engram, forces `autoMemoryEnabled: false`, and pre-approves only the core Engram read and write tools (`mem_update` and `mem_judge` still prompt). `docs/sessions/` is no longer written by any skill, though existing files are left in place. The architecture diagram shows Engram as session memory and QMD as reference docs.
