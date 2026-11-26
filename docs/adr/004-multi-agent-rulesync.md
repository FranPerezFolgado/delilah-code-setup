# ADR 004 — One source for Claude Code, Antigravity and Codex with rulesync

**Date:** 2026-11-26  
**Status:** Accepted

## Context

The setup only installed for Claude Code (plugin + `skills/`, `agents/`, `commands/`, `config/CLAUDE.md`). We also use Antigravity (`agy`) and Codex. Keeping one folder per agent would duplicate every skill and agent by hand.

## Decision

- The source is `.rulesync/` (rules, skills, subagents, MCP, hooks, permissions). [rulesync](https://github.com/dyoshikawa/rulesync) generates each agent's files. What applies to one agent only goes in its block inside the same file (`claudecode:`, `antigravity-cli:`, `codexcli:`).
- `setup.sh` runs `rulesync generate --global` into a **temporary HOME** and merges the result into the real one: file trees are copied when they differ, JSON is merged with the user's values winning and lists unioned, Codex `AGENTS.md` gets a marked block, an existing Codex `config.toml` is never rewritten.
- Flags `--claude`, `--antigravity`, `--codex`, `--all` (default: Claude plus whichever others are installed).
- Hooks and permissions stay per agent; no invented equivalences. RTK is set up with its own installer per agent.
- The Claude Code plugin and the `fran-setup` block in `~/.claude/CLAUDE.md` are retired; rules go to `~/.claude/rules/delilah.md`.

## Reasons

- rulesync already maps skills, subagents, MCP, hooks and permissions for all three agents, and is actively maintained. No home-made generator.
- rulesync in global mode replaces whole files (MCP list, settings, rules). Generating into a staging HOME keeps what the user added by hand and keeps backups and idempotency in our control.

## Tradeoffs

- Files are copied, not linked: edits need a re-run.
- agy has no grep/glob tool: `Grep`/`Glob` map to `run_command`, so agents that are read-only in Claude can run shell commands in agy.
- agy doesn't get the `**` file denies (rulesync skips them). Codex gets them only when its `config.toml` was created by us or merged by hand.
- A new runtime dependency (rulesync) and a coupling to its output paths; tests in `tests/setup_test.sh` pin those paths.
