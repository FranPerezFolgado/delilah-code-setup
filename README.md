# delilah-code-setup

My personal Claude Code setup. Minimal, intentional, no bloat.

Built around five tools that work together: session memory, semantic doc search, token-efficient shell commands, code graph navigation, and spec-driven feature development.

---

## Tools

| Tool | What it does | Why |
|------|-------------|-----|
| [Engram](https://github.com/Gentleman-Programming/engram) | Persistent session memory (MCP), stored locally | Decisions, non-obvious bugs and conventions survive across sessions. `/recall` reads it, `/save-session` writes it. No cloud sync by default |
| [QMD](https://github.com/tobi/qmd) | On-device semantic search over your reference docs | Ask Claude about architecture decisions, specs or any markdown in `docs/`, `specs/` and ADRs. Searches locally, no API calls. Not used for session memory |
| [RTK](https://github.com/rtk-ai/rtk) | Rewrites shell commands transparently to cut token usage 60–90% | `git status` output drops from thousands of tokens to hundreds. Happens via hook, zero friction |
| [Codegraph](https://github.com/colbymchenry/codegraph) | AST-based code knowledge graph exposed as MCP tools | Claude navigates code via graph queries instead of reading files. 70% fewer tool calls, 59% fewer tokens |
| [Spec-kit](https://github.com/github/spec-kit) | Spec-driven feature development | Define what before how. Generates spec → plan → tasks before touching code |

---

## Install

### Prerequisites

- macOS or Linux
- [Claude Code CLI](https://claude.ai/code)
- [Bun](https://bun.sh) — installed automatically if missing
- Homebrew (macOS only, for RTK) — fallback curl installer used on Linux

### Option A — Claude Code plugin (skills + agents only)

In Claude Code, run the slash command to register the marketplace:
```
/plugin marketplace add FranPerezFolgado/delilah-code-setup
```

Then install:
```bash
claude plugin install delilah-code-setup@FranPerezFolgado
```

After that, run the setup script to install the system tools (Engram, QMD, RTK, Codegraph, spec-kit):
```bash
curl -fsSL https://raw.githubusercontent.com/FranPerezFolgado/delilah-code-setup/main/setup.sh | bash
```

### Option B — Full install script (tools + skills + agents)

```bash
git clone https://github.com/yourusername/delilah-code-setup
cd delilah-code-setup
./setup.sh        # or: bash setup.sh
```

Installs Engram (binary via Homebrew, Claude Code plugin and MCP registration), QMD, RTK, Codegraph and spec-kit, configures Claude Code globally, starts the QMD daemon, and copies all skills, agents and commands. Restart Claude Code when it finishes.

Notes:

- Engram is installed with `brew` when available; otherwise the script prints the manual install link. If the `claude` CLI is missing, the plugin and MCP are not registered and the script says so at the end.
- `SETUP_SKIP_INSTALL=1 ./setup.sh` skips every step that installs software or touches system services and only applies the configuration (settings, `CLAUDE.md`, skills, agents, commands).
- Before overwriting `~/.claude/settings.json`, the managed block of `~/.claude/CLAUDE.md`, or any installed skill, agent or command, the script copies the previous file to `~/.claude/backups/<timestamp>/`. The path is printed at the end.
- The script validates `settings.json` and the `CLAUDE.md` markers first and aborts before changing anything if they are malformed (see [troubleshooting](docs/troubleshooting.md)).
- Coming from the old `docs/sessions/` flow? See [docs/migration.md](docs/migration.md).

### What gets installed

```
~/.claude/
├── CLAUDE.md              ← global instructions (Engram + QMD + Codegraph + RTK + working rules)
├── settings.json          ← MCP servers, RTK hook, auto-allow permissions, autoMemoryEnabled: false
├── backups/<timestamp>/   ← copies of files the installer overwrote
├── commands/
│   └── run-tasks.md       ← /run-tasks
├── skills/
│   ├── recall/recall.md ← /recall
│   ├── feature/feature.md ← /feature
│   ├── review/review.md ← /review
│   ├── pr-review/pr-review.md ← /pr-review
│   ├── commit/commit.md ← /commit
│   ├── doc-check/doc-check.md ← /doc-check
│   ├── code-nav/code-nav.md ← /code-nav
│   ├── project-setup/project-setup.md ← /project-setup
│   ├── setup-qmd/setup-qmd.md ← /setup-qmd
│   ├── save-session/save-session.md ← /save-session
│   ├── adr-check/adr-check.md ← /adr-check
│   └── stats/stats.md ← /stats
└── agents/
    ├── code-researcher.md    ← Haiku: code search via Codegraph
    ├── doc-searcher.md       ← Haiku: QMD queries
    ├── commit-writer.md      ← Haiku: commit message generation
    ├── doc-checker.md        ← Haiku: stale doc detection
    ├── security-reviewer.md  ← Sonnet: security review
    ├── code-quality-reviewer.md ← Sonnet: SOLID, patterns, correctness
    ├── test-reviewer.md      ← Haiku: test coverage and quality
    └── architecture-reviewer.md ← Sonnet: coupling and structure

# QMD daemon (auto-starts at login)
macOS  → ~/Library/LaunchAgents/com.qmd.mcp.plist   (launchd)
Linux  → ~/.config/systemd/user/qmd-mcp.service      (systemd)
Other  → entry added to ~/.zshrc / ~/.bashrc
```

---

## Agents

Subagents invoked by skills. Lightweight tasks use **Haiku**; review tasks use **Sonnet**.

| Agent | Model | Called by | What it does |
|-------|-------|-----------|-------------|
| `code-researcher` | Haiku | `/feature`, `/code-nav` | Searches codebase via Codegraph — symbols, call chains, affected files |
| `doc-searcher` | Haiku | `/recall`, `/feature` | Queries QMD collections with lex + vec search |
| `commit-writer` | Haiku | `/commit` | Generates Conventional Commits message from staged diff |
| `doc-checker` | Haiku | `/doc-check` | Finds documentation that's become stale after code changes |
| `security-reviewer` | Sonnet | `/review`, `/pr-review` | OWASP, secrets, auth/authz, injections, data exposure |
| `code-quality-reviewer` | Sonnet | `/review`, `/pr-review` | Correctness, SOLID, design patterns, error handling |
| `test-reviewer` | Haiku | `/review`, `/pr-review` | Coverage, test quality, edge cases |
| `architecture-reviewer` | Sonnet | `/review`, `/pr-review` | Coupling, consistency, breaking changes, abstractions |

---

## Skills

### Session

| Skill | What it does |
|-------|-------------|
| `/recall` | Loads project context from Engram (`mem_context`, `mem_search`) and queries QMD only for docs, specs and ADRs. Run at session start. |
| `/save-session` | Checks for undocumented ADRs, then saves decisions, bugs and conventions with `mem_save` and closes with `mem_session_summary`. Nothing is written to disk. |
| `/stats` | Shows RTK token savings, QMD collections, and Codegraph status. Flags setup gaps. |

### Feature development

| Skill | What it does |
|-------|-------------|
| `/feature` | Spec-kit wrapper. Searches QMD for prior art, maps affected code, then runs specify → plan → tasks. |
| `/run-tasks` | Command (not a skill). Executes the `tasks.md` of a Spec Kit feature, in parallel only when tasks touch different files. |
| `/adr-check` | Scans recent changes for decisions worth documenting as ADRs. Offers to write them. |

### Code review

| Skill | What it does |
|-------|-------------|
| `/review` | Fast parallel review of local changes or a known PR number. |
| `/pr-review` | Guided PR review — fetches PR metadata and stats before running agents. |

### Git

| Skill | What it does |
|-------|-------------|
| `/commit` | Generates a Conventional Commits message from staged changes. |
| `/doc-check` | Detects outdated documentation after changes on the current branch. |

### Project setup

| Skill | What it does |
|-------|-------------|
| `/project-setup` | One command to initialise a new project: dirs, gitignore, spec-kit, Codegraph, QMD. |
| `/setup-qmd` | Initialises a QMD collection for the current project's reference docs. Called by `/project-setup`. |
| `/code-nav` | Delegates code search to a subagent, keeping main context clean. |

---

## Workflow

### Starting a session

```
/recall
```

### New feature

```
/feature "description"
```

### Review before merge

```
/review              ← local changes, fast
/review 42           ← known PR, fast
/pr-review           ← unknown PR, guided (fetches metadata first)
```

### Commit

```
/commit
```

### End of session

```
/save-session topic
```

Detects pending ADRs first, then saves to Engram: durable learnings with `mem_save` (project or personal scope), then `mem_session_summary`.

See [docs/workflow.md](docs/workflow.md) for the full day-to-day reference and [docs/troubleshooting.md](docs/troubleshooting.md) for common issues.

---

## Working rules

`~/.claude/CLAUDE.md` ships a short set of proportional rules (the installer manages only the block between its `fran-setup` markers). In summary:

- **Delegation by reason**: work inline by default; use a subagent only for one of four named reasons (explore unfamiliar code, parallel writers, context handoff, independent verification of high-risk changes).
- **Spec Kit only for large work**: small work is done directly; large work (several sessions, external waits) gets a spec and is executed with `/run-tasks`.
- **Test-first**: a failing test per requested rule, then implementation, then refactor.
- **Risk-based review**: low, medium or high depending on what the change touches; only high risk triggers the security and architecture reviewers.

`/run-tasks <feature folder>` reads `tasks.md`, groups pending tasks by phase, runs `[P]` tasks with non-overlapping files as a parallel batch, marks each task done with an evidence line, reviews each phase by risk, saves decisions to Engram, and stops without committing.

Claude Code's built-in auto-memory is disabled (`autoMemoryEnabled: false`) so Engram is the only memory. Details in [docs/tools.md](docs/tools.md).

---

## Per-project setup

Run once after cloning a new project:

```
/project-setup
```

Creates `docs/adr/` and `specs/`, updates `.gitignore`, initialises spec-kit, Codegraph and QMD. Session memory is not stored in the project: it lives in Engram.

---

## Structure

```
delilah-code-setup/
├── README.md
├── setup.sh                    ← bootstrap installer
├── skills/                     ← copied to ~/.claude/skills/
├── agents/                     ← copied to ~/.claude/agents/
├── commands/                   ← copied to ~/.claude/commands/ (/run-tasks)
├── tests/                      ← installer tests (bash tests/setup_test.sh)
├── config/
│   ├── CLAUDE.md               ← global Claude instructions and working rules
│   ├── settings.template.json  ← MCP + permissions template
│   ├── merge-settings.jq       ← non-destructive settings merge
│   ├── gitignore.template      ← entries added to project .gitignore
│   ├── com.qmd.mcp.plist       ← macOS launchd daemon
│   └── qmd-mcp.service         ← Linux systemd daemon
└── docs/
    ├── tools.md                ← deep dive on each tool + how it all connects
    ├── workflow.md             ← full workflow reference including ADRs
    ├── troubleshooting.md      ← common issues and fixes
    ├── migration.md            ← moving from docs/sessions/ to Engram
    └── adr/
        └── 001-manual-pr-creation.md
```

---

## Updating

```bash
# Push local changes to repo
cp -R ~/.claude/skills/. ~/dev/delilah-code-setup/skills/
cp ~/.claude/commands/*.md ~/dev/delilah-code-setup/commands/
cp ~/.claude/agents/*.md ~/dev/delilah-code-setup/agents/

# Pull updates and re-apply
git pull && ./setup.sh
```

The setup script is idempotent — safe to run multiple times.
