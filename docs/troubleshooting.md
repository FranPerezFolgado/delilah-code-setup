# Troubleshooting

Common issues and how to fix them. Run `/stats` first — it detects most problems automatically.

---

## QMD not responding

**Symptom:** `/recall` can't find docs, or Claude can't use `mcp__qmd__*` tools. (QMD only holds reference docs; session memory is in Engram.)

**Check:**
```bash
curl -s http://localhost:8181/mcp
```

If no response, the daemon isn't running.

**Fix — start manually:**
```bash
qmd mcp --http --daemon
```

**Fix — restart the daemon:**

macOS:
```bash
launchctl unload ~/Library/LaunchAgents/com.qmd.mcp.plist
launchctl load ~/Library/LaunchAgents/com.qmd.mcp.plist
```

Linux:
```bash
systemctl --user restart qmd-mcp
```

**Fix — daemon not installed:**
Run `./setup.sh` again — it creates and loads the daemon config.

---

## QMD collection not found

**Symptom:** `/recall` says no QMD collection is configured (the Engram part still works).

**Fix:**
```
/project-setup    ← first time on this project
/setup-qmd        ← if Codegraph is already set up
```

**Check what's indexed:**
```bash
qmd collection list
```

**Re-index after adding docs:**
```bash
qmd embed
```

---

## Codegraph not initialised

**Symptom:** `/stats` warns "Codegraph not initialised", or Claude uses `grep`/`Read` instead of graph tools.

**Fix:**
```bash
codegraph init -i
```

Run from the project root. This is interactive.

**Check status:**
```bash
codegraph status
```

**Codegraph not syncing after edits:**
File watchers should handle this automatically. If not:
```bash
codegraph index    # force re-index
```

---

## RTK not active

**Symptom:** `rtk gain` shows 0 commands, or shell output is very verbose.

**Check:**
```bash
rtk --version      # confirm RTK is installed
rtk gain           # should show command count > 0 after any shell use
```

**Fix — reinstall hook:**
```bash
rtk init -g --auto-patch
```

Then restart Claude Code.

**Verify hook is in settings.json:**
```bash
grep -A3 "rtk" ~/.claude/settings.json
```

Should show:
```json
"command": "rtk hook claude"
```

---

## spec-kit commands not found

**Symptom:** `/feature` fails when trying to run `/speckit.specify`.

**Fix:**
```bash
claude plugin install github/spec-kit
```

Then restart Claude Code.

---

## Engram not listed in `claude mcp list`

**Symptom:** `claude mcp list | grep engram` prints nothing, `/recall` says "Engram is not responding", or the `mem_*` tools are missing.

**Check:**
```bash
command -v engram        # the binary
claude plugin list       # the Engram plugin
claude mcp list | grep engram
```

**Fix:**
1. If the binary is missing: `brew install gentleman-programming/tap/engram` (or follow https://github.com/Gentleman-Programming/engram).
2. If the plugin is missing: `claude plugin marketplace add Gentleman-Programming/engram`, then `claude plugin install engram`.
3. Register the MCP server:
   ```bash
   engram setup claude-code
   ```
4. Restart Claude Code.

Re-running `./setup.sh` does steps 1 to 3 for you. If the `claude` CLI was not on your PATH, the installer prints a warning at the end that the plugin and MCP were not registered.

---

## Conflicts when saving memories

**Symptom:** `mem_save` returns `judgment_required`, or you suspect duplicates.

**What to do:**
1. Run `mem_search` for the topic in the project before saving.
2. If a memory on the same topic exists, read it with `mem_get_observation` and update it with `mem_update` (keep its `topic_key`) instead of saving a new one. If it is already covered, skip.
3. If a save still returns `judgment_required`, resolve it with `mem_judge` (use `mem_judge_many` when there are several candidates). Ask the user when unsure.

`/save-session` follows this order already.

---

## Backup and restore

**Back up your memories:**
```bash
engram export [file]
```

**Restore them:**
```bash
engram import <file>
```

**Config files.** Before the installer overwrites `~/.claude/settings.json`, the managed block of `~/.claude/CLAUDE.md`, or an installed skill, agent or command, it copies the previous file to `~/.claude/backups/<timestamp>/` (same path relative to `$HOME`). The path is printed at the end of the run. To restore, copy the files back from that folder.

Restoring a whole `~/.claude/backups/<timestamp>/` also undoes that run's `rtk init` changes to `settings.json`, because the backup holds the file as it was before the run.

---

## Installer aborted: malformed markers / invalid settings.json

**Symptom:** `./setup.sh` stops early with one of:

- `~/.claude/settings.json is not a valid JSON object — fix or remove it and re-run (nothing was changed)`
- `~/.claude/CLAUDE.md has unbalanced or duplicate fran-setup markers — fix them by hand and re-run (nothing was changed)`
- `jq is required but not installed` / `curl is required but not installed`

These checks run before any write, so nothing was modified.

**Fix:**
- `settings.json`: validate with `jq . ~/.claude/settings.json`, fix the syntax error (or restore a copy from `~/.claude/backups/`), then re-run.
- `CLAUDE.md`: the managed block must be exactly one `<!-- fran-setup:start -->` line followed by one `<!-- fran-setup:end -->` line. Remove the duplicate or orphan marker, then re-run.
- Missing `jq` or `curl`: install it and re-run.

---

## Skills or agents not loading

**Symptom:** A skill or agent isn't recognised after install.

**Fix:** Restart Claude Code. Skills and agents load at startup.

**Check installed files:**
```bash
ls ~/.claude/skills/
ls ~/.claude/agents/
```

**Reinstall from repo:**
```bash
cd ~/path/to/delilah-code-setup
./setup.sh
```

---

## .gitignore being overwritten

**Symptom:** Existing `.gitignore` entries disappeared after running `/project-setup` or `/setup-qmd`.

This should not happen — both skills use `grep -qF` to check before appending. If it did happen, restore from git:
```bash
git checkout .gitignore
```

Then re-run `/project-setup` — it will only add the missing entries.

---

## General: run /stats

```
/stats
```

Shows RTK savings, QMD collections, and Codegraph status. Flags any detected gaps with the fix command.
