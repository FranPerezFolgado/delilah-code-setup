#!/usr/bin/env bash
# Test harness for setup.sh. Every case runs against a temporary HOME with
# SETUP_SKIP_INSTALL=1, so nothing is installed and the real HOME is untouched.
# shellcheck disable=SC2034,SC2120,SC2119,SC2154  # helpers are reused by later cases
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0
H=""; OUT=""; ERR=""; RC=0
TMPDIRS=()
trap 'for d in ${TMPDIRS[@]+"${TMPDIRS[@]}"}; do rm -rf "$d"; done' EXIT


# new_home: create a fresh temp HOME and set $H
new_home() {
  H="$(mktemp -d)"
  TMPDIRS+=("$H")
}

# run_setup [ENV=VAL ...] [--flag ...]: run setup.sh in $H, capture OUT, ERR and RC.
# Without flags it runs --claude, so results don't depend on which agents this
# machine has installed.
run_setup() {
  local o e a envs=() flags=()
  for a in "$@"; do
    if [[ "$a" == --* ]]; then flags+=("$a"); else envs+=("$a"); fi
  done
  [[ ${#flags[@]} -gt 0 ]] || flags=(--claude)
  o="$(mktemp)"; e="$(mktemp)"
  RC=0
  env HOME="$H" SETUP_SKIP_INSTALL=1 ${envs[@]+"${envs[@]}"} bash "$REPO/setup.sh" "${flags[@]}" >"$o" 2>"$e" || RC=$?
  OUT="$(cat "$o")"; ERR="$(cat "$e")"
  rm -f "$o" "$e"
}

_pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
_fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; [[ -n "${2:-}" ]] && echo "        $2"; return 0; }

# assert_eq EXPECTED ACTUAL NAME
assert_eq() {
  if [[ "$1" == "$2" ]]; then _pass "$3"; else _fail "$3" "expected '$1', got '$2'"; fi
}
# assert_contains HAYSTACK NEEDLE NAME
assert_contains() {
  if [[ "$1" == *"$2"* ]]; then _pass "$3"; else _fail "$3" "missing '$2'"; fi
}
# assert_not_contains HAYSTACK NEEDLE NAME
assert_not_contains() {
  if [[ "$1" != *"$2"* ]]; then _pass "$3"; else _fail "$3" "unexpected '$2'"; fi
}
# assert_file PATH NAME
assert_file() {
  if [[ -f "$1" ]]; then _pass "$2"; else _fail "$2" "no such file: $1"; fi
}

# ── Cases ─────────────────────────────────────────────────────

test_smoke_empty_home() {
  echo "case: run in an empty HOME exits 0 and writes only under \$H"
  new_home
  local before after
  before="$(cd "$REPO" && git status --porcelain 2>/dev/null || true)"
  run_setup
  after="$(cd "$REPO" && git status --porcelain 2>/dev/null || true)"
  assert_eq "0" "$RC" "exit code is 0"
  assert_eq "$before" "$after" "repo tree untouched"
  assert_file "$H/.claude/settings.json" "settings.json written under \$H"
  assert_contains "$OUT" "skipped install_rtk (SETUP_SKIP_INSTALL)" "installs reported as skipped"
  assert_not_contains "$OUT" '\n' "no literal \\n in output"
}

cat_glob() { cat "$@" 2>/dev/null || true; }

test_us1_memory_skills() {
  echo "case: installed memory skills use Engram and never create docs/sessions"
  new_home
  run_setup
  local save recall all
  save="$(cat_glob "$H"/.claude/skills/save-session/*.md)"
  recall="$(cat_glob "$H"/.claude/skills/recall/*.md)"
  all="$(cat_glob "$H"/.claude/skills/*/*.md)"
  assert_contains "$save" "mem_save" "save-session uses mem_save"
  assert_contains "$save" "mem_session_summary" "save-session uses mem_session_summary"
  assert_not_contains "$save" "docs/sessions" "save-session does not mention docs/sessions"
  assert_contains "$recall" "mem_context" "recall uses mem_context"
  assert_contains "$recall" "mem_search" "recall uses mem_search"
  assert_not_contains "$all" "mkdir -p docs/sessions" "no skill creates docs/sessions"
  assert_not_contains "$all" "mkdir -p docs/sessions docs/adr" "no skill creates docs/sessions with adr"
  assert_not_contains "$all" '"docs/sessions/"' "no skill adds docs/sessions/ to gitignore"
  assert_not_contains "$all" "collection add ./docs/sessions" "no skill adds docs/sessions as a collection"
}

test_us1_auto_memory_off() {
  echo "case: settings.json has autoMemoryEnabled=false"
  new_home
  run_setup
  local v
  v="$(jq -r '.autoMemoryEnabled' "$H/.claude/settings.json" 2>/dev/null || echo "error")"
  assert_eq "false" "$v" "autoMemoryEnabled is false"
}

test_smoke_empty_home
test_us1_memory_skills
test_us1_auto_memory_off

# ── US2: safe, idempotent merge ───────────────────────────────

SEED_SETTINGS='{"myKey":1,"theme":"light","permissions":{"allow":["Bash(ls:*)"],"deny":["Read(./x)"]},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo hi"}]}]}}'

test_us2_settings_merge() {
  echo "case: settings merge keeps user content and is idempotent"
  new_home
  mkdir -p "$H/.claude"
  printf '%s\n' "$SEED_SETTINGS" > "$H/.claude/settings.json"
  run_setup
  local s="$H/.claude/settings.json" first
  assert_eq "0" "$RC" "first run exits 0"
  first="$(mktemp)"; cp "$s" "$first"
  run_setup
  assert_eq "0" "$RC" "second run exits 0"
  assert_eq "1" "$(jq '.myKey' "$s")" "myKey kept"
  assert_eq "light" "$(jq -r '.theme' "$s")" "theme kept"
  assert_eq "true" "$(jq '.permissions.allow | index("Bash(ls:*)") != null' "$s")" "user allow entry kept"
  assert_eq "true" "$(jq '.permissions.allow | index("mcp__qmd__query") != null' "$s")" "template allow entry added"
  assert_eq "true" "$(jq '.permissions.deny | index("Read(./x)") != null' "$s")" "user deny entry kept"
  assert_eq "echo hi" "$(jq -r '.hooks.Stop[0].hooks[0].command' "$s")" "user Stop hook kept"
  assert_eq "true" "$(jq '[.permissions.allow, .permissions.deny, .permissions.ask] | map(. // [] | length == (unique | length)) | all' "$s")" "no duplicate permission entries"
  assert_eq "1" "$(jq '[.hooks.PreToolUse[] | select(.hooks[].command == "rtk hook claude")] | length' "$s")" "rtk hook group appears once"
  assert_eq "false" "$(jq '.autoMemoryEnabled' "$s")" "autoMemoryEnabled forced false"
  if cmp -s "$first" "$s"; then _pass "second run leaves settings.json byte-identical"; else _fail "second run leaves settings.json byte-identical"; fi
  rm -f "$first"
}

test_us2_settings_forces_auto_memory() {
  echo "case: user autoMemoryEnabled=true is forced to false"
  new_home
  mkdir -p "$H/.claude"
  echo '{"autoMemoryEnabled":true}' > "$H/.claude/settings.json"
  run_setup
  assert_eq "false" "$(jq '.autoMemoryEnabled' "$H/.claude/settings.json")" "autoMemoryEnabled false"
}

test_symlinked_targets_preserved() {
  echo "case: symlinked settings.json and CLAUDE.md stay symlinks after a merge"
  new_home
  mkdir -p "$H/.claude" "$H/dots"
  echo '{"autoMemoryEnabled":true}' > "$H/dots/settings.json"
  echo "# mine" > "$H/dots/CLAUDE.md"
  ln -s "$H/dots/settings.json" "$H/.claude/settings.json"
  ln -s "$H/dots/CLAUDE.md" "$H/.claude/CLAUDE.md"
  run_setup
  assert_eq "0" "$RC" "exit code is 0"
  [[ -L "$H/.claude/settings.json" ]] && _pass "settings.json still a symlink" || _fail "settings.json symlink replaced"
  [[ -L "$H/.claude/CLAUDE.md" ]] && _pass "CLAUDE.md still a symlink" || _fail "CLAUDE.md symlink replaced"
  assert_eq "false" "$(jq '.autoMemoryEnabled' "$H/dots/settings.json")" "merge written through the link"
}

test_skills_legacy_layout_cleaned() {
  echo "case: legacy <name>/<name>.md is backed up and removed; edited skill files are backed up"
  new_home
  mkdir -p "$H/.claude/skills/recall" "$H/.claude/skills/audit/references"
  printf 'old recall\n' > "$H/.claude/skills/recall/recall.md"
  printf 'my edit\n' > "$H/.claude/skills/audit/references/trends.md"
  run_setup
  [[ -e "$H/.claude/skills/recall/recall.md" ]] && _fail "legacy recall.md removed" || _pass "legacy recall.md removed"
  local b
  b="$(find "$H/.claude/backups" -mindepth 1 -maxdepth 1 -type d | head -1)"
  assert_eq "old recall" "$(cat "$b/.claude/skills/recall/recall.md" 2>/dev/null)" "legacy recall.md backed up"
  assert_eq "my edit" "$(cat "$b/.claude/skills/audit/references/trends.md" 2>/dev/null)" "edited reference file backed up"
}
test_us2_bad_markers() {
  echo "case: CLAUDE.md with only a start marker aborts before any write"
  new_home
  mkdir -p "$H/.claude"
  printf 'x\n<!-- fran-setup:start -->\ny\n' > "$H/.claude/CLAUDE.md"
  cp "$H/.claude/CLAUDE.md" "$H/pre.md"
  run_setup
  if [[ "$RC" -ne 0 ]]; then _pass "non-zero exit"; else _fail "non-zero exit"; fi
  if cmp -s "$H/pre.md" "$H/.claude/CLAUDE.md"; then _pass "CLAUDE.md unchanged"; else _fail "CLAUDE.md unchanged"; fi
  if [[ ! -e "$H/.claude/settings.json" ]]; then _pass "settings.json not created"; else _fail "settings.json not created"; fi
  assert_contains "$ERR" "CLAUDE.md" "error names the file"
}

test_us2_invalid_settings() {
  echo "case: invalid settings.json aborts, file unchanged, nothing else written"
  new_home
  mkdir -p "$H/.claude"
  printf '{oops' > "$H/.claude/settings.json"
  cp "$H/.claude/settings.json" "$H/pre.json"
  run_setup
  if [[ "$RC" -ne 0 ]]; then _pass "non-zero exit"; else _fail "non-zero exit"; fi
  if cmp -s "$H/pre.json" "$H/.claude/settings.json"; then _pass "settings.json unchanged"; else _fail "settings.json unchanged"; fi
  if [[ ! -e "$H/.claude/CLAUDE.md" && ! -d "$H/.claude/skills" ]]; then _pass "nothing else written"; else _fail "nothing else written"; fi
  assert_contains "$ERR" "settings.json" "error names the file"
}

test_us2_backups() {
  echo "case: pre-run files are backed up; a second run needs no backup"
  new_home
  mkdir -p "$H/.claude"
  printf '%s\n' "$SEED_SETTINGS" > "$H/.claude/settings.json"
  printf '# Mine\n<!-- fran-setup:start -->\nOLD\n<!-- fran-setup:end -->\n' > "$H/.claude/CLAUDE.md"
  cp "$H/.claude/settings.json" "$H/pre.json"; cp "$H/.claude/CLAUDE.md" "$H/pre.md"
  run_setup
  local b
  b="$(find "$H/.claude/backups" -mindepth 1 -maxdepth 1 -type d | head -1)"
  if [[ -n "$b" ]] && cmp -s "$H/pre.json" "$b/.claude/settings.json"; then _pass "settings.json backup has pre-run content"; else _fail "settings.json backup has pre-run content"; fi
  if [[ -n "$b" ]] && cmp -s "$H/pre.md" "$b/.claude/CLAUDE.md"; then _pass "CLAUDE.md backup has pre-run content"; else _fail "CLAUDE.md backup has pre-run content"; fi
  run_setup
  assert_eq "1" "$(find "$H/.claude/backups" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" "an up-to-date second run creates no backup dir"
  assert_eq "700" "$(stat -f %Lp "$b" 2>/dev/null || stat -c %a "$b")" "backup dir is private (700)"
}

test_us2_stale_warning() {
  echo "case: stale session text outside markers triggers a warning"
  new_home
  mkdir -p "$H/.claude"
  printf '# Mine\nsave notes to docs/sessions please\n<!-- fran-setup:start -->\nOLD docs/sessions\n<!-- fran-setup:end -->\n' > "$H/.claude/CLAUDE.md"
  run_setup
  assert_contains "$OUT" "stale session-memory instructions outside fran-setup block: line 2" "warning names line 2"
  assert_not_contains "$OUT" "line 4" "no warning for text inside markers"
  assert_contains "$OUT" "docs/migration.md" "final message points to migration doc"
}
# ── US3: Engram install and final message ─────────────────────

test_us3_engram_section() {
  echo "case: Engram section is skipped under SETUP_SKIP_INSTALL"
  new_home
  run_setup
  assert_contains "$OUT" "── Engram ──" "Engram section printed"
  assert_contains "$OUT" "skipped install_engram (SETUP_SKIP_INSTALL)" "Engram install reported as skipped"
}

test_us3_final_message() {
  echo "case: final message describes the checks and /recall"
  new_home
  run_setup
  local final
  final="${OUT##*Setup complete}"
  assert_contains "$final" "claude mcp list" "final message has the MCP check"
  assert_contains "$final" "engram tui" "final message mentions engram tui"
  assert_contains "$final" "/recall loads context from Engram" "/recall described as loading from Engram"
  assert_contains "$final" "re-run ./setup.sh" "final message says to re-run after edits"
  assert_not_contains "$OUT" "engram sync" "no engram sync anywhere"
  assert_not_contains "$final" "cloud" "no cloud step in final message"
}

test_skills_installed_as_skill_md() {
  echo "case: every shipped skill is installed as <name>/SKILL.md"
  new_home
  run_setup
  local d n missing=""
  for d in "$REPO"/.rulesync/skills/*/; do
    n="$(basename "$d")"
    [[ -f "$H/.claude/skills/$n/SKILL.md" ]] || missing="$missing $n"
  done
  assert_eq "" "$missing" "no skill missing its SKILL.md"
  [[ -d "$H/.claude/skills/audit/references" ]] && _pass "skill subdirectories copied" || _fail "audit/references not copied"
}

test_agents_installed() {
  echo "case: every shipped agent is installed with its Claude tools and model"
  new_home
  run_setup
  local f n missing=""
  for f in "$REPO"/.rulesync/subagents/*.md; do
    n="$(basename "$f")"
    [[ -f "$H/.claude/agents/$n" ]] || missing="$missing $n"
  done
  assert_eq "" "$missing" "no agent missing"
  assert_contains "$(cat "$H/.claude/agents/security-reviewer.md")" "model: sonnet" "Claude agent keeps its model"
  assert_contains "$(cat "$H/.claude/agents/security-reviewer.md")" "- Grep" "Claude agent keeps its tools"
  assert_not_contains "$(cat "$H/.claude/agents/security-reviewer.md")" "read_file" "no agy tool names in Claude agents"
}

count_in() { grep -c -F -- "$1" "$2" || true; }

test_claude_md_old_block_removed() {
  echo "case: the old fran-setup block is removed from CLAUDE.md, the rest kept"
  new_home
  mkdir -p "$H/.claude"
  printf '# Mine\nkeep me\n<!-- fran-setup:start -->\nOLD\n<!-- fran-setup:end -->\ntail text\n' > "$H/.claude/CLAUDE.md"
  run_setup
  local f="$H/.claude/CLAUDE.md" first
  assert_eq "0" "$RC" "exit 0"
  assert_eq "0" "$(count_in '<!-- fran-setup:start -->' "$f")" "start marker gone"
  assert_eq "0" "$(count_in 'OLD' "$f")" "old block content gone"
  assert_contains "$(cat "$f")" "keep me" "head text kept"
  assert_contains "$(cat "$f")" "tail text" "tail text kept"
  first="$(mktemp)"; cp "$f" "$first"
  run_setup
  if cmp -s "$first" "$f"; then _pass "second run byte-identical"; else _fail "second run byte-identical"; fi
  rm -f "$first"
}

test_claude_md_untouched() {
  echo "case: CLAUDE.md without markers is left alone; a missing one is not created"
  new_home
  mkdir -p "$H/.claude"
  printf '# Mine\nkeep me\n' > "$H/.claude/CLAUDE.md"
  cp "$H/.claude/CLAUDE.md" "$H/pre.md"
  run_setup
  if cmp -s "$H/pre.md" "$H/.claude/CLAUDE.md"; then _pass "CLAUDE.md unchanged"; else _fail "CLAUDE.md unchanged"; fi
  new_home
  run_setup
  [[ -e "$H/.claude/CLAUDE.md" ]] && _fail "no CLAUDE.md created" || _pass "no CLAUDE.md created"
}

test_rules_installed() {
  echo "case: working rules are installed as ~/.claude/rules/delilah.md, loaded always"
  new_home
  run_setup
  local f="$H/.claude/rules/delilah.md" h
  assert_file "$f" "rules file installed"
  for h in "## Cómo trabajar" "## Spec Kit" "## Tests" "## Memoria y documentación" "## Revisión por riesgo" "### Engram (session memory)"; do
    assert_contains "$(cat "$f")" "$h" "rules have: $h"
  done
  assert_not_contains "$(head -5 "$f")" "paths:" "rule is not path-scoped"
}

test_run_tasks_skill() {
  echo "case: run-tasks is a skill; the legacy command is backed up and removed"
  new_home
  mkdir -p "$H/.claude/commands"
  printf 'old command\n' > "$H/.claude/commands/run-tasks.md"
  run_setup
  assert_file "$H/.claude/skills/run-tasks/SKILL.md" "run-tasks skill installed"
  [[ -e "$H/.claude/commands/run-tasks.md" ]] && _fail "legacy command removed" || _pass "legacy command removed"
  local b
  b="$(find "$H/.claude/backups" -mindepth 1 -maxdepth 1 -type d | head -1)"
  assert_eq "old command" "$(cat "$b/.claude/commands/run-tasks.md" 2>/dev/null)" "legacy command backed up"
}

test_permissions() {
  echo "case: settings.json ships deny/ask and limited Engram allow"
  new_home
  run_setup
  local s="$H/.claude/settings.json" p
  assert_eq "1" "$(jq '[.permissions.deny[] | select(. == "Read(~/.ssh/**)")] | length' "$s")" "deny contains Read(~/.ssh/**)"
  assert_eq "1" "$(jq '[.permissions.ask[] | select(. == "Bash(git push *)")] | length' "$s")" "ask contains Bash(git push *)"
  for p in mcp__engram__ mcp__plugin_engram_engram__; do
    assert_eq "1" "$(jq --arg t "${p}mem_search" '[.permissions.allow[] | select(. == $t)] | length' "$s")" "allow has ${p}mem_search"
    assert_eq "0" "$(jq --arg t "${p}mem_update" '[.permissions.allow[] | select(. == $t)] | length' "$s")" "allow lacks ${p}mem_update"
  done
  assert_eq "0" "$(jq '[has("theme"), has("autoUpdatesChannel"), has("enabledPlugins")] | map(select(.)) | length' "$s")" "no personal preference keys"
}

test_legacy_colon_permissions_replaced() {
  echo "case: old Bash(cmd:*) asks are replaced by the shipped Bash(cmd *) form; others kept"
  new_home
  mkdir -p "$H/.claude"
  echo '{"permissions":{"ask":["Bash(git push:*)","Bash(make deploy:*)"]}}' > "$H/.claude/settings.json"
  run_setup
  local s="$H/.claude/settings.json"
  assert_eq "0" "$(jq '[.permissions.ask[] | select(. == "Bash(git push:*)")] | length' "$s")" "old git push form dropped"
  assert_eq "1" "$(jq '[.permissions.ask[] | select(. == "Bash(git push *)")] | length' "$s")" "new git push form present"
  assert_eq "1" "$(jq '[.permissions.ask[] | select(. == "Bash(make deploy:*)")] | length' "$s")" "user's own :* entry kept"
}

test_claude_mcp_merge() {
  echo "case: ~/.claude.json gets qmd and codegraph, keeps user servers and other keys"
  new_home
  echo '{"numStartups":3,"mcpServers":{"mine":{"command":"x"},"qmd":{"url":"http://other"}}}' > "$H/.claude.json"
  run_setup
  local c="$H/.claude.json"
  assert_eq "3" "$(jq '.numStartups' "$c")" "other keys kept"
  assert_eq "x" "$(jq -r '.mcpServers.mine.command' "$c")" "user server kept"
  assert_eq "http://other" "$(jq -r '.mcpServers.qmd.url' "$c")" "user's qmd entry wins"
  assert_eq "codegraph" "$(jq -r '.mcpServers.codegraph.command' "$c")" "codegraph added"
  assert_eq "null" "$(jq -r '.mcpServers.engram' "$c")" "engram not registered (plugin provides it)"
}

test_claude_json_not_reformatted() {
  echo "case: an up-to-date ~/.claude.json is not rewritten just to reformat it"
  new_home
  printf '{"mcpServers":{"qmd":{"url":"http://localhost:8181/mcp"},"codegraph":{"type":"stdio","command":"codegraph","args":["serve","--mcp"]}}}' > "$H/.claude.json"
  cp "$H/.claude.json" "$H/pre.json"
  run_setup
  if cmp -s "$H/pre.json" "$H/.claude.json"; then _pass ".claude.json byte-identical"; else _fail ".claude.json byte-identical"; fi
}

# ── Targets and flags ─────────────────────────────────────────

test_flags() {
  echo "case: --claude writes only Claude files; an unknown flag fails"
  new_home
  run_setup --claude
  [[ -e "$H/.gemini" || -e "$H/.codex" || -e "$H/.agents" ]] && _fail "only ~/.claude written" || _pass "only ~/.claude written"
  new_home
  run_setup --bogus
  if [[ "$RC" -ne 0 ]]; then _pass "unknown flag exits non-zero"; else _fail "unknown flag exits non-zero"; fi
  [[ -e "$H/.claude" ]] && _fail "unknown flag writes nothing" || _pass "unknown flag writes nothing"
}

test_antigravity() {
  echo "case: --antigravity installs agents, skills, rules, MCP and permissions, keeping the user's"
  new_home
  mkdir -p "$H/.gemini/config" "$H/.gemini/antigravity-cli"
  : > "$H/.gemini/config/mcp_config.json"
  echo '{"colorScheme":"dark","permissions":{"allow":["command(ls)"]}}' > "$H/.gemini/antigravity-cli/settings.json"
  echo '{"mine":{"SessionEnd":[{"type":"command","command":"echo bye"}]}}' > "$H/.gemini/config/hooks.json"
  run_setup --antigravity
  assert_eq "0" "$RC" "exit 0"
  [[ -e "$H/.claude/agents" ]] && _fail "no Claude files" || _pass "no Claude files"
  local a="$H/.gemini/config/agents/implementer.md" s="$H/.gemini/antigravity-cli/settings.json"
  assert_contains "$(cat "$a")" "- run_command" "agy agent has run_command"
  assert_contains "$(cat "$a")" "- edit_file" "agy agent has edit_file"
  assert_not_contains "$(cat "$a")" "model: sonnet" "no Claude model in agy agent"
  assert_file "$H/.gemini/antigravity-cli/skills/recall/SKILL.md" "agy skill installed"
  assert_file "$H/.gemini/config/rules/delilah.md" "agy rule installed"
  assert_eq "chrome-devtools,codegraph,engram,qmd" "$(jq -r '.mcpServers | keys | join(",")' "$H/.gemini/config/mcp_config.json")" "agy MCP servers"
  assert_eq "dark" "$(jq -r '.colorScheme' "$s")" "agy user setting kept"
  assert_eq "true" "$(jq '.permissions.allow | index("command(ls)") != null' "$s")" "agy user permission kept"
  assert_eq "true" "$(jq '.permissions.ask | index("command(git push)") != null' "$s")" "agy ask rule added"
  assert_eq "echo bye" "$(jq -r '.mine.SessionEnd[0].command' "$H/.gemini/config/hooks.json")" "user hook set kept"
  assert_eq "true" "$(jq 'has("rulesync")' "$H/.gemini/config/hooks.json")" "rulesync hook set added"
  assert_contains "$(jq -r '.permissions.deny[]' "$s")" "read_file($H/.ssh)" "~ paths point at the real HOME"
  assert_eq "0" "$(jq --arg h "$H/" '[.permissions.deny[] | select(test("_file\\(") and (contains($h) | not))] | length' "$s")" "no staging paths left"
}

test_codex() {
  echo "case: --codex installs agents, skills, rules and AGENTS.md; leaves an existing config.toml alone"
  new_home
  mkdir -p "$H/.codex"
  printf 'my codex notes\n' > "$H/.codex/AGENTS.md"
  printf 'model = "mine"\n' > "$H/.codex/config.toml"
  echo '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo hi"}]}]}}' > "$H/.codex/hooks.json"
  run_setup --codex
  assert_eq "0" "$RC" "exit 0"
  assert_file "$H/.codex/agents/implementer.toml" "Codex agent installed"
  assert_file "$H/.agents/skills/recall/SKILL.md" "Codex skill installed"
  assert_file "$H/.codex/rules/rulesync.rules" "Codex command rules installed"
  local m="$H/.codex/AGENTS.md"
  assert_contains "$(cat "$m")" "my codex notes" "user AGENTS.md text kept"
  assert_contains "$(cat "$m")" "## Cómo trabajar" "working rules in AGENTS.md"
  assert_eq "1" "$(count_in '<!-- fran-setup:start -->' "$m")" "one managed block"
  assert_eq 'model = "mine"' "$(cat "$H/.codex/config.toml")" "config.toml untouched"
  assert_file "$H/.codex/config.delilah.toml" "generated config left next to it"
  assert_contains "$OUT" "config.delilah.toml" "user told to merge config.toml"
  assert_eq "echo hi" "$(jq -r '.hooks.Stop[0].hooks[0].command' "$H/.codex/hooks.json")" "user Codex hook kept"
  assert_eq "true" "$(jq 'has("hooks") and (.hooks | has("SessionStart"))' "$H/.codex/hooks.json")" "codegraph hook added"
}

test_all_targets_idempotent() {
  echo "case: two runs with every target change nothing the second time"
  new_home
  run_setup --claude --antigravity --codex
  assert_eq "0" "$RC" "first run exits 0"
  local before after
  before="$(cd "$H" && find . -type f -not -path './.claude/backups/*' | sort | xargs shasum)"
  run_setup --claude --antigravity --codex
  assert_eq "0" "$RC" "second run exits 0"
  after="$(cd "$H" && find . -type f -not -path './.claude/backups/*' | sort | xargs shasum)"
  assert_eq "$before" "$after" "second run changes no file"
  assert_contains "$OUT" "nothing needed a backup" "second run backs up nothing"
}

test_us2_settings_merge
test_us2_settings_forces_auto_memory
test_symlinked_targets_preserved
test_rulesync_layout_change_aborts() {
  echo "case: a rulesync that doesn't generate the expected files aborts before any write"
  new_home
  local bin="$H/bin"; mkdir -p "$bin"
  printf '#!/bin/sh\nexit 0\n' > "$bin/rulesync"; chmod +x "$bin/rulesync"
  run_setup "PATH=$bin:$PATH"
  if [[ "$RC" -ne 0 ]]; then _pass "exits non-zero"; else _fail "exits non-zero"; fi
  assert_contains "$ERR" "output layout changed" "names the cause"
  [[ -e "$H/.claude" ]] && _fail "nothing written" || _pass "nothing written"
}

test_codex_config_warning_once() {
  echo "case: the Codex config.toml warning is loud once, then quiet while nothing we ship changes"
  new_home
  mkdir -p "$H/.codex"; printf 'model = "mine"\n' > "$H/.codex/config.toml"
  run_setup --codex
  assert_contains "$OUT" "NOT active" "first run warns loudly"
  run_setup --codex
  assert_not_contains "$OUT" "NOT active" "second run doesn't repeat the loud warning"
  assert_contains "$OUT" "unchanged since last run" "second run gives a quiet reminder"
}

test_home_with_special_chars() {
  echo "case: a HOME with & and | in its path gets correct ~ paths"
  H="$(mktemp -d)/a&b|c"; mkdir -p "$H"; TMPDIRS+=("$(dirname "$H")")
  run_setup --antigravity
  assert_eq "0" "$RC" "exit 0"
  assert_contains "$(jq -r '.permissions.deny[]' "$H/.gemini/antigravity-cli/settings.json")" "read_file($H/.ssh)" "~ paths use the literal HOME"
}

test_skills_installed_as_skill_md
test_agents_installed
test_skills_legacy_layout_cleaned
test_claude_md_old_block_removed
test_claude_md_untouched
test_rules_installed
test_run_tasks_skill
test_permissions
test_legacy_colon_permissions_replaced
test_claude_mcp_merge
test_claude_json_not_reformatted
test_us2_bad_markers
test_us2_invalid_settings
test_us2_backups
test_us2_stale_warning
test_us3_engram_section
test_us3_final_message
test_flags
test_antigravity
test_codex
test_all_targets_idempotent
test_rulesync_layout_change_aborts
test_codex_config_warning_once
test_home_with_special_chars

echo
echo "Passed: $PASS  Failed: $FAIL"
[[ "$FAIL" -eq 0 ]]
