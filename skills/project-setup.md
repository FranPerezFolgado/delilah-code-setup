---
description: Sets up a new project for the full dev workflow — indexes code with Codegraph and docs with QMD. Run once per new project after cloning.
---

# project-setup

Initialises the current project for the full workflow: code graph + doc search.

## Steps

### 1. Check current state
```bash
[ -d .codegraph ] && echo "codegraph: ok" || echo "codegraph: missing"
```
Check local `CLAUDE.md` for `## QMD Collection` to see if QMD is configured.

### 2. Create local directories
```bash
mkdir -p docs/sessions docs/adr specs
```

### 3. Update .gitignore (safe append — never overwrite)
Check each entry and only add the ones that aren't already present:
```bash
GITIGNORE=".gitignore"
[ ! -f "$GITIGNORE" ] && touch "$GITIGNORE"
for entry in "docs/sessions/" "specs/" ".specify/" ".codegraph/"; do
  grep -qF "$entry" "$GITIGNORE" || echo "$entry" >> "$GITIGNORE"
done
```

### 4. Initialise Codegraph (if missing)
```bash
codegraph init -i
```
This is interactive — the user confirms project configuration.

### 5. Initialise QMD
Run `/setup-qmd` to create the project doc collection.

### 6. Show summary
Run `/stats` to confirm everything is operational.

## Notes

- Steps are skipped if already configured.
- `docs/adr/` is created for ADR documentation — commit this directory.
- `docs/sessions/`, `specs/`, `.codegraph/`, `.specify/` are gitignored — local only.
