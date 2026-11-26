# Migrating session notes from QMD to Engram

Session memory now lives in Engram. QMD only indexes reference docs (`docs/`, `specs/`, ADRs). Claude Code's own auto-memory is turned off (`autoMemoryEnabled: false`) so Engram is the single store. See [ADR 002](adr/002-session-memory-engram.md).

Everything here is local. There are no cloud or sync steps. Nothing below deletes your `docs/sessions/*.md` files.

## 1. Back up Engram

```bash
engram export engram-backup-$(date +%Y%m%d).json
```

To restore later: `engram import <file>`.

## 2. Move useful session notes into Engram

List the old notes and review them:

```bash
ls docs/sessions/*.md
```

For each idea worth keeping, run `mem_search` first, then `mem_save`:

- One idea per memory.
- Scope: project, or personal if it applies across projects.
- Put the version in the title when it matters (for example "Postgres 16: ...").
- No duplicates. If `mem_search` finds the same topic, use `mem_update` instead of saving again.

Skip anything already covered by a spec or ADR. Reference the document instead of copying it.

## 3. Stop QMD from indexing the old notes

In `~/.config/qmd/index.yml`, add an `ignore` line to your docs collection, then re-index:

```yaml
    ignore: ["sessions/**"]
```

```bash
qmd update
```

Do NOT delete `docs/sessions/`. The files stay on disk, QMD just stops returning them.

## 4. Remove Claude Code auto-memory files

Auto-memory is off now. Review, then remove, the old files:

```bash
ls ~/.claude/projects/<project-slug>/memory/
rm -r ~/.claude/projects/<project-slug>/memory/   # includes MEMORY.md
```

Check that anything useful is already in Engram (step 2) before you remove them.

## 5. Clean stale instructions in `~/.claude/CLAUDE.md`

The installer only owns the text between `<!-- fran-setup:start -->` and `<!-- fran-setup:end -->`. If it printed a warning about stale lines outside the markers, edit those lines yourself. Remove instructions that send session notes to `docs/sessions/` or describe QMD as session memory.

## 6. Copy-ready migration prompt

Paste this into Claude Code in the project you are migrating:

```text
Migrate this project's old session notes to Engram. Do not delete any files.

1. Call mem_current_project to confirm the project.
2. List docs/sessions/*.md and show me the list. Wait for me to say which files to migrate.
3. For each approved file, extract the durable ideas: decisions and their why, non-obvious bugs and their cause, conventions. One idea per memory.
4. Before each save, run mem_search for the same topic. If a match exists, use mem_update instead. Otherwise use mem_save with the right scope (project or personal) and the version in the title when relevant.
5. Skip anything already documented in specs/ or an ADR; reference the document instead.
6. If mem_save returns judgment_required, resolve it with mem_judge and tell me what you decided.
7. When done, print a table: file, memories saved, memories updated, skipped. Do not touch the source files.
```
