# Tools

Deep dive on each tool in the stack.

---

## How it all connects

The five tools form a stack. Skills and agents sit on top and wire them together.

```
┌─────────────────────────────────────────────────────────┐
│                        Skills                           │
│  /recall  /feature  /review  /commit  /save-session … │
└──────────┬─────────────────────────┬────────────────────┘
           │ delegates to            │ calls
┌──────────▼──────────┐  ┌──────────▼──────────────────┐
│       Agents        │  │       spec-kit phases        │
│  (Haiku / Sonnet)   │  │  specify / plan / tasks      │
└──────────┬──────────┘  └─────────────────────────────┘
           │ uses
┌──────────▼────────────────────────────────────────────┐
│                   MCP Tools                           │
│  Engram (memory)  QMD (docs)  Codegraph (code)        │
└──────────────────────────────────────────────────────┘
           +
┌─────────────────────────────────────────────────────┐
│              RTK (transparent shell hook)           │
│       rewrites every Bash call before it runs       │
└─────────────────────────────────────────────────────┘
```

**Skills** are the entry points — slash commands you run. They orchestrate the flow but keep the main context clean by delegating work to agents.

**Agents** are subprocesses with a focused job and a specific model. Lightweight tasks (search, commit message, doc check) use **Haiku** to save tokens. Review and reasoning tasks use **Sonnet**.

**MCP tools** (Engram, QMD and Codegraph) run as servers that Claude queries instead of reading files. They're always available — Claude uses them automatically when `CLAUDE.md` instructs it to.

**RTK** operates at the shell layer — completely invisible to Claude, it filters every command output before it reaches the context.

![Architecture](assets/architecture.svg)

---

## Engram — Persistent session memory

**Repo:** https://github.com/Gentleman-Programming/engram  
**What it is:** A local memory store exposed to Claude as an MCP server (and a Claude Code plugin). It is the single place where what you learn while working is kept between sessions.

### What it stores

Durable, hard-to-reconstruct knowledge, saved as observations with `mem_save`:

- decisions and their why (`decision`)
- non-obvious bugs and their root cause (`bugfix`)
- conventions discovered or agreed (`pattern`)
- findings about tools, APIs or the environment (`discovery`, `config`)

It also keeps one summary per session (`mem_session_summary`). It does not hold reference documentation: specs, ADRs and `docs/` stay in QMD and memories point to them instead of copying them.

### Project vs personal scope

- **project**: facts about the current repo. Found by `/recall` when you work in that repo.
- **personal**: facts about your own tools and habits that are not specific to one repo.

If a memory depends on a tool version, put the version in its title (for example "QMD 2.1: ignore is YAML-only").

### How it is used

- `/recall` reads it at session start: `mem_context`, `mem_search`, `mem_get_observation`.
- `/save-session` writes it at the end: `mem_save` (searching first, `mem_update` for the same topic, `mem_judge` on `judgment_required`), then `mem_session_summary`.
- `mem_context`, `mem_search`, `mem_get_observation`, `mem_current_project`, `mem_save` and `mem_session_summary` are pre-approved in `~/.claude/settings.json`, for both the `engram` MCP server name and the plugin one. `mem_update` and `mem_judge` are not pre-approved, so Claude Code asks before using them.

### CLI

```bash
engram tui                   # browse saved memories
engram export [file]         # export memories (backup)
engram import <file>         # import an export (restore)
engram setup claude-code     # register the MCP server with Claude Code
claude mcp list | grep engram   # check it is registered
```

### Cloud sync

Engram has optional cloud sync features. They are **not part of the default setup**: nothing here enables, configures or requires them, and your memories stay on your machine.

### Claude Code auto-memory is disabled

The installer sets `"autoMemoryEnabled": false` in `~/.claude/settings.json`. Claude Code has its own built-in auto-memory, and running it next to Engram would give two competing memories for the same purpose. Engram is the one on purpose. The setting is documented at https://code.claude.com/docs/en/memory.md#enable-or-disable-auto-memory (it can be set at user, project or local level). The installer forces this key on every run; every other scalar you already set in `settings.json` is kept.

---

## QMD — On-device semantic search

**Repo:** https://github.com/tobi/qmd  
**What it is:** A local search engine over markdown files. Runs entirely on your machine with locally downloaded embedding models. No external API calls, no data leaves your machine.

In this setup QMD is for **reference documentation only**: `docs/`, `specs/` and ADRs. Session memory lives in [Engram](#engram--persistent-session-memory), not here.

### How it works

QMD organises content into named **collections**. Each collection points to a directory of markdown files. When you run `qmd embed`, it generates vector embeddings and stores them in a local SQLite database at `~/.cache/qmd/index.sqlite`.

Claude connects to QMD via MCP. In this setup, QMD runs as an HTTP daemon at `http://localhost:8181/mcp` (started automatically at login via launchd).

### Three search modes

| Mode | How | Use when |
|------|-----|----------|
| `lex` | BM25 keyword search | You know the exact term |
| `vec` | Semantic vector search | You want similar meaning, not exact words |
| `hyde` | Hypothetical document | You describe what the answer looks like |

Best results combine `lex` + `vec` in the same query.

### Per-project setup

Each project gets its own named collection:

```bash
qmd collection add ./docs --name my-project --mask "**/*.md"
qmd embed
```

The `/setup-qmd` skill does this automatically and writes the collection name to the local `CLAUDE.md`.

If an older project still has a `docs/sessions/` folder, keep it out of the index with an `ignore` entry in the collection config:

`ignore` is YAML-only (no CLI flag sets it). In `~/.config/qmd/index.yml`, under the project's collection:

```yaml
    ignore: ["sessions/**"]
```

Then run `qmd update` so the ignored files are dropped. See [migration](migration.md).

### CLI reference

```bash
qmd collection list          # show all collections
qmd collection add <path> --name <name>
qmd embed                    # generate/update embeddings
qmd ls <collection>          # browse files in a collection
qmd mcp --http --daemon      # start HTTP MCP server
```

---

## RTK — Rust Token Killer

**Repo:** https://github.com/rtk-ai/rtk  
**What it is:** A transparent proxy that rewrites Claude Code shell commands to filter noise and reduce token usage 60–90%.

### How it works

RTK is installed as a `PreToolUse` hook on the `Bash` matcher. Every shell command Claude runs goes through `rtk hook claude`, which applies smart filtering — removing boilerplate, truncating verbose output, deduplicating repeated lines — before the result reaches Claude.

From Claude's perspective, it just runs commands. From your token budget's perspective, `git log` goes from ~8,000 tokens to ~400.

### Zero friction

There's nothing to invoke. You never call `rtk` directly for normal work. It's entirely transparent.

```bash
rtk gain              # see accumulated token savings
rtk gain --history    # per-command savings breakdown
rtk discover          # analyse history for missed opportunities
```

### What it filters

- `git log`, `git diff`, `git status`
- `ls`, `cat`, `find`, `grep`
- Test output (jest, pytest, cargo test, go test)
- Build output (tsc, eslint, cargo build)
- Docker and kubectl output
- npm/pip/cargo package manager output

---

## Codegraph — AST code knowledge graph

**Repo:** https://github.com/colbymchenry/codegraph  
**What it is:** Builds a local SQLite graph of your codebase using tree-sitter AST parsing. Exposed to Claude as an MCP stdio server.

### How it works

On `codegraph init`, it parses all source files and extracts symbols (functions, classes, methods, variables) and their relationships (calls, imports, inheritance). The result is a queryable graph stored in `.codegraph/` in your project root.

File watchers keep the graph in sync automatically as you edit.

### MCP tools Claude uses

| Tool | What it does |
|------|-------------|
| `codegraph_search` | Find symbols by name |
| `codegraph_context` | Get relevant code context for a task |
| `codegraph_callers` | What calls this function? |
| `codegraph_callees` | What does this function call? |
| `codegraph_impact` | What breaks if I change this? |
| `codegraph_node` | Details for a specific symbol |

### Why it matters

Without Codegraph, Claude reads files to understand code — expensive, slow, and context-heavy. With Codegraph, Claude queries the graph. 70% fewer tool calls, 59% fewer tokens, meaningfully faster responses on large codebases.

### Per-project setup

```bash
codegraph init -i    # interactive setup, auto-detects Claude Code
```

### Supported languages

TypeScript, JavaScript, Python, Go, Rust, Java, C#, PHP, Ruby, C, C++, Swift, Kotlin, Dart, Svelte, Vue — 19+ languages.

---

## Spec-kit — Spec-driven feature development

**Repo:** https://github.com/github/spec-kit  
**What it is:** A methodology and toolset for writing specifications before writing code. Installs as a Claude Code plugin with slash commands for each phase.

### Philosophy

Spec-Driven Development (SDD) inverts the usual flow. You define *what* and *why* before touching code. The specification becomes the primary artefact — code is derived from it, not the other way around.

### Phases

| Phase | Command | Output |
|-------|---------|--------|
| Specify | `/speckit.specify` | `spec.md` with user stories and acceptance criteria |
| Clarify | `/speckit.clarify` | Resolves ambiguities in the spec |
| Checklist | `/speckit.checklist` | Quality validation of the spec |
| Plan | `/speckit.plan` | `plan.md`, `research.md`, `data-model.md`, `contracts/` |
| Tasks | `/speckit.tasks` | `tasks.md` with phased, dependency-ordered work |
| Implement | `/speckit.implement` | Executes tasks to build the feature |

### The `/feature` skill

The `/feature` skill wraps the early phases (specify → plan, optionally → tasks). It asks you three questions upfront and then orchestrates the workflow. See [workflow.md](./workflow.md) for the full flow.

### Artifacts stay local

`.specify/` and `specs/` are always added to `.gitignore`. Specs don't go to the repo — they're your working notes, not deliverables.

### Install

Spec-kit installs as a Claude Code plugin:

```bash
claude plugin install github/spec-kit
```
