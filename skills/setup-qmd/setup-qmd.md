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
mkdir -p docs/sessions docs/adr
```

Add only missing entries to `.gitignore` (never overwrite existing content):
```bash
GITIGNORE=".gitignore"
[ ! -f "$GITIGNORE" ] && touch "$GITIGNORE"
for entry in "docs/sessions/" "specs/" ".specify/" ".codegraph/"; do
  grep -qF "$entry" "$GITIGNORE" || echo "$entry" >> "$GITIGNORE"
done
```

### 3. Add collections
```bash
# Full docs/ directory (includes sessions/, adr/, and everything else in docs/)
qmd collection add ./docs --name <project-name> --mask "**/*.md"

# Specs (spec-kit artefacts, if they exist)
[ -d specs ] && qmd collection add ./specs --name <project-name> 2>/dev/null || true
```

### 4. Generate embeddings
```bash
qmd embed
```

### 5. Update local CLAUDE.md
Add to the project's `CLAUDE.md` (create if missing):
```markdown
## QMD Collection
Active collection: `<project-name>`
```

### 6. Confirm
- Collection name and document count
- Paths indexed (docs/, specs/ if present)
