# delilah-code-setup

My personal Claude Code setup. Minimal, intentional, no bloat.

Built around four tools that work together: semantic doc search, token-efficient shell commands, code graph navigation, and spec-driven feature development.

---

## Tools

| Tool | What it does | Why |
|------|-------------|-----|
| [QMD](https://github.com/tobi/qmd) | On-device semantic search over your docs | Ask Claude about architecture decisions, past sessions, or any markdown — searches locally, no API calls |
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

After that, run the setup script to install the system tools (QMD, RTK, Codegraph, spec-kit):
```bash
curl -fsSL https://raw.githubusercontent.com/FranPerezFolgado/delilah-code-setup/main/setup.sh | zsh
```

### Option B — Full install script (tools + skills + agents)

```bash
git clone https://github.com/yourusername/delilah-code-setup
cd delilah-code-setup
chmod +x setup.sh && ./setup.sh
```

Installs QMD, RTK, Codegraph, spec-kit, configures Claude Code globally, starts the QMD daemon, and copies all skills and agents. Restart Claude Code when it finishes.

### What gets installed

```
~/.claude/
├── CLAUDE.md              ← global instructions (QMD + Codegraph + RTK)
├── settings.json          ← MCP servers, RTK hook, auto-allow permissions
├── skills/
│   ├── recall.md          ← /recall
│   ├── feature.md         ← /feature
│   ├── review.md          ← /review
│   ├── pr-review.md       ← /pr-review
│   ├── commit.md          ← /commit
│   ├── doc-check.md       ← /doc-check
│   ├── code-nav.md        ← /code-nav
│   ├── project-setup.md   ← /project-setup
│   ├── setup-qmd.md       ← /setup-qmd
│   ├── save-session.md    ← /save-session
│   ├── adr-check.md       ← /adr-check
│   └── stats.md           ← /stats
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
| `/recall` | Searches QMD for project context before starting work. Run at session start. |
| `/save-session` | Checks for undocumented ADRs, then saves session summary to `docs/sessions/` and re-indexes QMD. |
| `/stats` | Shows RTK token savings, QMD collections, and Codegraph status. Flags setup gaps. |

### Feature development

| Skill | What it does |
|-------|-------------|
| `/feature` | Spec-kit wrapper. Searches QMD for prior art, maps affected code, then runs specify → plan → tasks. |
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
| `/project-setup` | One command to initialise a new project: dirs, gitignore, Codegraph, QMD. |
| `/setup-qmd` | Initialises a QMD collection for the current project. Called by `/project-setup`. |
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

Detects pending ADRs first, then saves to `docs/sessions/` and re-indexes QMD.

See [docs/workflow.md](docs/workflow.md) for the full day-to-day reference and [docs/troubleshooting.md](docs/troubleshooting.md) for common issues.

---

## Per-project setup

Run once after cloning a new project:

```
/project-setup
```

Creates `docs/sessions/`, `docs/adr/`, `specs/`, updates `.gitignore`, initialises Codegraph and QMD.

---

## Structure

```
delilah-code-setup/
├── README.md
├── setup.sh                    ← bootstrap installer
├── skills/                     ← copied to ~/.claude/skills/
├── agents/                     ← copied to ~/.claude/agents/
├── config/
│   ├── CLAUDE.md               ← global Claude instructions
│   ├── settings.template.json  ← MCP + permissions template
│   ├── gitignore.template      ← entries added to project .gitignore
│   ├── com.qmd.mcp.plist       ← macOS launchd daemon
│   └── qmd-mcp.service         ← Linux systemd daemon
└── docs/
    ├── tools.md                ← deep dive on each tool + how it all connects
    ├── workflow.md             ← full workflow reference including ADRs
    ├── troubleshooting.md      ← common issues and fixes
    └── adr/
        └── 001-manual-pr-creation.md
```

---

## Updating

```bash
# Push local changes to repo
cp ~/.claude/skills/*.md ~/dev/delilah-code-setup/skills/
cp ~/.claude/agents/*.md ~/dev/delilah-code-setup/agents/

# Pull updates and re-apply
git pull && ./setup.sh
```

The setup script is idempotent — safe to run multiple times.
