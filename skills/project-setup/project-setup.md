---
description: Sets up a new project for the full dev workflow — indexes code with Codegraph and docs with QMD. Run once per new project after cloning.
---

# project-setup

Initialises the current project for the full workflow: code graph + doc search + spec-kit.

## Steps

### 1. Check current state
```bash
[ -d .codegraph ] && echo "codegraph: ok" || echo "codegraph: missing"
[ -d .specify ] && echo "spec-kit: ok" || echo "spec-kit: missing"
```
Check local `CLAUDE.md` for `## QMD Collection` to see if QMD is configured.

### 2. Create local directories
```bash
mkdir -p docs/sessions docs/adr specs
```

### 3. Update .gitignore (safe append — never overwrite)
```bash
GITIGNORE=".gitignore"
[ ! -f "$GITIGNORE" ] && touch "$GITIGNORE"
for entry in "docs/sessions/" "specs/" ".specify/" ".codegraph/"; do
  grep -qF "$entry" "$GITIGNORE" || echo "$entry" >> "$GITIGNORE"
done
```

### 4. Initialise spec-kit (if missing)
```bash
specify init --here --integration claude --force --no-git
```

- `--here`: initialise in current directory
- `--integration claude`: non-interactive, installs spec-kit skills into `.claude/`
- `--force`: skip confirmation if directory not empty
- `--no-git`: project already has git

Then create the base constitution if it doesn't exist yet:
```bash
mkdir -p .specify/memory
```

Copy `config/constitution.template.md` from the delilah-code-setup repo to `.specify/memory/constitution.md`, replacing the `<!-- date -->` placeholder with today's date.

Tell the user: "A base constitution has been created at `.specify/memory/constitution.md`. **Review and customise it for this project before using `/feature`** — replace the generic principles with your stack's specific rules."

### 5. Initialise Codegraph (if missing)
```bash
codegraph init -i
```
This is interactive — the user confirms project configuration.

### 6. Initialise QMD
Run `/setup-qmd` to create the project doc collection.

### 7. Show summary
Run `/stats` to confirm everything is operational.

## Notes

- Steps are skipped if already configured.
- `.specify/memory/constitution.md` is the single source of truth for spec-kit quality gates.
- `docs/adr/` is created for ADR documentation — commit this directory.
- `docs/sessions/`, `specs/`, `.codegraph/`, `.specify/` are gitignored — local only.
