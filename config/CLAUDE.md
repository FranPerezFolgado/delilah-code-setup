## Active tools

### RTK (token reduction)
RTK is active via PreToolUse hook. Shell commands are rewritten automatically — no manual action needed.

### Codegraph (code exploration)
ALWAYS use codegraph tools before Read/grep to explore code:
- `codegraph_search` — find symbols by name
- `codegraph_context` — get relevant context for a task
- `codegraph_callers` / `codegraph_callees` — trace call chains
- `codegraph_impact` — analyse change impact

Only use Read/Grep for config files, plain text, or when the symbol isn't in the graph.

### QMD (doc search)
ALWAYS use QMD before asking about documentation, architecture decisions, or project context.
- Tool: `query` combining `lex` (keywords) and `vec` (semantic)
- Active collection is in the local `CLAUDE.md` (`## QMD Collection`)
- If no collection configured: run `/project-setup`

If QMD doesn't respond: the daemon is managed by launchd (macOS) or systemd (Linux). Run `/stats` to diagnose.

@RTK.md
