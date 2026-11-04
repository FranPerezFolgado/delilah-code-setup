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

# run_setup [ENV=VAL ...]: run setup.sh in $H, capture OUT, ERR and RC
run_setup() {
  local o e
  o="$(mktemp)"; e="$(mktemp)"
  RC=0
  env HOME="$H" SETUP_SKIP_INSTALL=1 "$@" bash "$REPO/setup.sh" >"$o" 2>"$e" || RC=$?
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

count_in() { grep -c -F -- "$1" "$2" || true; }

test_us2_claude_md_replace() {
  echo "case: CLAUDE.md block replaced between markers, idempotent"
  new_home
  mkdir -p "$H/.claude"
  printf '# Mine\nkeep me\n<!-- fran-setup:start -->\nOLD\n<!-- fran-setup:end -->\ntail text\n' > "$H/.claude/CLAUDE.md"
  run_setup
  local f="$H/.claude/CLAUDE.md" first
  assert_eq "0" "$RC" "exit 0"
  first="$(mktemp)"; cp "$f" "$first"
  run_setup
  assert_eq "1" "$(count_in '<!-- fran-setup:start -->' "$f")" "one start marker"
  assert_eq "1" "$(count_in '<!-- fran-setup:end -->' "$f")" "one end marker"
  assert_contains "$(cat "$f")" "keep me" "head text kept"
  assert_contains "$(cat "$f")" "tail text" "tail text kept"
  assert_not_contains "$(cat "$f")" "OLD" "old block content gone"
  if cmp -s "$first" "$f"; then _pass "second run byte-identical"; else _fail "second run byte-identical"; fi
  rm -f "$first"
}

test_us2_claude_md_append() {
  echo "case: CLAUDE.md without markers gets the block appended once"
  new_home
  mkdir -p "$H/.claude"
  printf '# Mine\nkeep me\n' > "$H/.claude/CLAUDE.md"
  run_setup
  run_setup
  local f="$H/.claude/CLAUDE.md"
  assert_eq "1" "$(count_in '<!-- fran-setup:start -->' "$f")" "one start marker after two runs"
  assert_eq "1" "$(count_in '<!-- fran-setup:end -->' "$f")" "one end marker after two runs"
  assert_contains "$(cat "$f")" "keep me" "existing text kept"
}

test_us2_claude_md_missing() {
  echo "case: missing CLAUDE.md gets config/CLAUDE.md"
  new_home
  run_setup
  if [[ -f "$H/.claude/CLAUDE.md" ]] && cmp -s "$REPO/config/CLAUDE.md" "$H/.claude/CLAUDE.md"; then
    _pass "CLAUDE.md equals shipped config"
  else
    _fail "CLAUDE.md equals shipped config"
  fi
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
  echo "case: pre-run files are backed up, two runs give two backup dirs"
  new_home
  mkdir -p "$H/.claude"
  printf '%s\n' "$SEED_SETTINGS" > "$H/.claude/settings.json"
  printf '# Mine\n' > "$H/.claude/CLAUDE.md"
  cp "$H/.claude/settings.json" "$H/pre.json"; cp "$H/.claude/CLAUDE.md" "$H/pre.md"
  run_setup
  local b
  b="$(find "$H/.claude/backups" -mindepth 1 -maxdepth 1 -type d | head -1)"
  if [[ -n "$b" ]] && cmp -s "$H/pre.json" "$b/.claude/settings.json"; then _pass "settings.json backup has pre-run content"; else _fail "settings.json backup has pre-run content"; fi
  if [[ -n "$b" ]] && cmp -s "$H/pre.md" "$b/.claude/CLAUDE.md"; then _pass "CLAUDE.md backup has pre-run content"; else _fail "CLAUDE.md backup has pre-run content"; fi
  run_setup
  assert_eq "2" "$(find "$H/.claude/backups" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" "two runs create two backup dirs"
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

test_us2_settings_merge
test_us2_settings_forces_auto_memory
test_us2_claude_md_replace
test_us2_claude_md_append
test_us2_claude_md_missing
test_us2_bad_markers
test_us2_invalid_settings
test_us2_backups
test_us2_stale_warning

# ── US3: Engram install and final message ─────────────────────

test_us3_engram_section() {
  echo "case: Engram section is skipped under SETUP_SKIP_INSTALL"
  new_home
  run_setup
  assert_contains "$OUT" "── Engram ──" "Engram section printed"
  assert_contains "$OUT" "skipped install_engram (SETUP_SKIP_INSTALL)" "Engram install reported as skipped"
}

test_us3_final_message() {
  echo "case: final message describes Engram checks and /recall"
  new_home
  run_setup
  local final
  final="${OUT##*Setup complete}"
  assert_contains "$final" "claude mcp list | grep engram" "final message has the MCP check"
  assert_contains "$final" "engram tui" "final message mentions engram tui"
  assert_contains "$final" "/recall loads context from Engram" "/recall described as loading from Engram"
  assert_not_contains "$OUT" "engram sync" "no engram sync anywhere"
  assert_not_contains "$final" "cloud" "no cloud step in final message"
}

test_us3_engram_section
test_us3_final_message

# ── US4: working rules, permissions, /run-tasks ───────────────

test_us4_run_tasks() {
  echo "case: /run-tasks command is installed"
  new_home
  run_setup
  assert_file "$H/.claude/commands/run-tasks.md" "run-tasks.md installed"
  if cmp -s "$REPO/commands/run-tasks.md" "$H/.claude/commands/run-tasks.md"; then _pass "run-tasks.md equals shipped"; else _fail "run-tasks.md equals shipped"; fi
}

test_us4_headings() {
  echo "case: installed CLAUDE.md has the working-rules headings inside the markers"
  new_home
  run_setup
  local inside h
  inside="$(sed -n '/<!-- fran-setup:start -->/,/<!-- fran-setup:end -->/p' "$H/.claude/CLAUDE.md")"
  for h in "## Cómo trabajar" "## Spec Kit" "## Tests" "## Memoria y documentación" "## Revisión por riesgo"; do
    assert_contains "$inside" "$h" "heading inside markers: $h"
  done
  assert_contains "$(cat "$H/.claude/CLAUDE.md")" "### Engram (session memory)" "Engram tools section present"
}

test_us4_permissions() {
  echo "case: settings.json ships deny/ask and limited Engram allow"
  new_home
  run_setup
  local s="$H/.claude/settings.json" p
  assert_eq "1" "$(jq '[.permissions.deny[] | select(. == "Read(~/.ssh/**)")] | length' "$s")" "deny contains Read(~/.ssh/**)"
  assert_eq "1" "$(jq '[.permissions.ask[] | select(. == "Bash(git push:*)")] | length' "$s")" "ask contains Bash(git push:*)"
  for p in mcp__engram__ mcp__plugin_engram_engram__; do
    assert_eq "1" "$(jq --arg t "${p}mem_search" '[.permissions.allow[] | select(. == $t)] | length' "$s")" "allow has ${p}mem_search"
    assert_eq "0" "$(jq --arg t "${p}mem_update" '[.permissions.allow[] | select(. == $t)] | length' "$s")" "allow lacks ${p}mem_update"
  done
  assert_eq "0" "$(jq '[has("theme"), has("autoUpdatesChannel"), has("enabledPlugins")] | map(select(.)) | length' "$s")" "no personal preference keys"
}

test_us4_missing_claude_md_two_runs() {
  echo "case: fresh HOME, two runs leave CLAUDE.md byte-identical with one block"
  new_home
  run_setup
  cp "$H/.claude/CLAUDE.md" "$H/after1.md"
  run_setup
  if cmp -s "$H/after1.md" "$H/.claude/CLAUDE.md"; then _pass "CLAUDE.md identical after run 2"; else _fail "CLAUDE.md identical after run 2"; fi
  assert_eq "1" "$(grep -cxF '<!-- fran-setup:start -->' "$H/.claude/CLAUDE.md")" "exactly one start marker"
  assert_eq "1" "$(grep -c '^## Cómo trabajar' "$H/.claude/CLAUDE.md")" "working rules appear once"
}

test_symlinked_targets_preserved
test_us4_run_tasks
test_us4_headings
test_us4_permissions
test_us4_missing_claude_md_two_runs

echo
echo "Passed: $PASS  Failed: $FAIL"
[[ "$FAIL" -eq 0 ]]
