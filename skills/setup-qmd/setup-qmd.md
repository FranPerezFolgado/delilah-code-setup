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
mkdir -p docs/sessions
```

Add only missing entries to `.gitignore` (never overwrite existing content):
```bash
GITIGNORE=".gitignore"
[ ! -f "$GITIGNORE" ] && touch "$GITIGNORE"
for entry in "docs/sessions/" "specs/" ".specify/" ".codegraph/"; do
  grep -qF "$entry" "$GITIGNORE" || echo "$entry" >> "$GITIGNORE"
done
```

### 3. Ask which directories to index
Suggest `docs/` if it exists, otherwise `./`. Allow multiple paths.

### 4. Add collections
```bash
# Primary docs
qmd collection add <path> --name <project-name> --mask "**/*.md"

# Sessions (local session summaries)
qmd collection add ./docs/sessions --name <project-name> 2>/dev/null || true

# Specs (spec-kit artefacts, if they exist)
[ -d specs ] && qmd collection add ./specs --name <project-name> 2>/dev/null || true
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
- Paths indexed (docs, sessions, specs)
