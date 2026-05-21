# Troubleshooting

Common issues and how to fix them. Run `/stats` first — it detects most problems automatically.

---

## QMD not responding

**Symptom:** `/recall` returns nothing, or Claude can't use `mcp__qmd__*` tools.

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

**Symptom:** `/recall` says "No QMD collection found for this project."

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
