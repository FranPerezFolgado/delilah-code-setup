---
description: Initialise a QMD doc collection for the current project. Run once per repo to index docs and update the project CLAUDE.md with the collection name.
---

# setup-qmd

Initialises a QMD collection for the current project. Run once per repo.

## Steps

### 1. Detect project name
- Try `git remote get-url origin` and extract repo name
- Fallback: `basename $(git rev-parse --show-toplevel)` or current directory name

### 2. Ensure local directories exist and .gitignore is safe
```bash
mkdir -p docs/adr
```

Add only missing entries to `.gitignore` (never overwrite existing content):
```bash
GITIGNORE=".gitignore"
[ ! -f "$GITIGNORE" ] && touch "$GITIGNORE"
for entry in "specs/" ".specify/" ".codegraph/"; do
  grep -qF "$entry" "$GITIGNORE" || echo "$entry" >> "$GITIGNORE"
done
```

### 3. Add collections
```bash
# Full docs/ directory (adr/ and everything else in docs/)
qmd collection add ./docs --name <project-name> --mask "**/*.md"

# Specs (spec-kit artefacts, if they exist)
[ -d specs ] && qmd collection add ./specs --name <project-name> 2>/dev/null || true
```

### 4. Exclude old session notes from the index
Older projects may still have `docs/sessions/`. Session memory now lives in Engram, so keep those notes out of QMD.
`ignore` is a YAML-only key (no CLI flag sets it). In `~/.config/qmd/index.yml`, add to this project's collection:
```yaml
collections:
  <project-name>:
    ignore: ["sessions/**"]
```
Then re-index so the ignored docs are dropped:
```bash
qmd update
```

### 5. Generate embeddings
```bash
qmd embed
```

### 6. Update local CLAUDE.md
Add to the project's `CLAUDE.md` (create if missing):
```markdown
## QMD Collection
Active collection: `<project-name>`
```

### 7. Confirm
- Collection name and document count
- Paths indexed (docs/, specs/ if present)
