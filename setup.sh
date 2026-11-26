#!/usr/bin/env bash
# =============================================================
#  delilah-code-setup — agent setup installer
#  Run from the repo root: ./setup.sh [--claude] [--antigravity] [--codex] [--all]
#  Supports: macOS, Linux
#
#  The source is .rulesync/. rulesync generates each agent's files into a
#  staging HOME, and this script merges them into the real one: rulesync
#  itself replaces whole files (MCP servers, permissions, rules), which would
#  drop what you added by hand.
# =============================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { printf '%b✓%b %s\n' "$GREEN" "$NC" "$1"; }
info() { printf '%b→%b %s\n' "$YELLOW" "$NC" "$1"; }
warn() { printf '%b⚠%b %s\n' "$YELLOW" "$NC" "$1"; }
err()  { printf '%b✗%b %s\n' "$RED" "$NC" "$1" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: ./setup.sh [--claude] [--antigravity] [--codex] [--all]

  --claude       Claude Code (~/.claude)
  --antigravity  Antigravity CLI, agy (~/.gemini)
  --codex        Codex CLI (~/.codex, ~/.agents)
  --all          Claude Code, plus Antigravity and Codex when they are
                 installed (agy/codex on PATH, or ~/.gemini / ~/.codex exists).
                 This is the default.
EOF
}

# ── Targets ───────────────────────────────────────────────────
DO_CLAUDE=0; DO_AGY=0; DO_CODEX=0; ALL=0
[[ $# -eq 0 ]] && ALL=1
for arg in "$@"; do
  case "$arg" in
    --claude)      DO_CLAUDE=1 ;;
    --antigravity) DO_AGY=1 ;;
    --codex)       DO_CODEX=1 ;;
    --all)         ALL=1 ;;
    -h|--help)     usage; exit 0 ;;
    *)             usage >&2; err "unknown option: $arg" ;;
  esac
done
if [[ "$ALL" == "1" ]]; then
  DO_CLAUDE=1
  if command -v agy &>/dev/null || [[ -d "$HOME/.gemini" ]]; then DO_AGY=1; else info "Antigravity not found — skipping it (use --antigravity to force)"; fi
  if command -v codex &>/dev/null || [[ -d "$HOME/.codex" ]]; then DO_CODEX=1; else info "Codex not found — skipping it (use --codex to force)"; fi
fi

# ── Install guard ─────────────────────────────────────────────
# SETUP_SKIP_INSTALL=1 skips every step that installs software or touches
# system services (used by tests/setup_test.sh). Usage: run_install <fn> [args]
run_install() {
  if [[ "${SETUP_SKIP_INSTALL:-0}" == "1" ]]; then
    echo "  skipped $1 (SETUP_SKIP_INSTALL)"
    return 0
  fi
  "$@"
}

# ── Backup helper ─────────────────────────────────────────────
# Lazily creates $BACKUP_DIR; backup <file> copies an existing file there
# (path relative to $HOME), at most once per file per run.
BACKUP_DIR=""
BACKED_UP=""
backup() {
  local file="$1" rel dest
  [[ -f "$file" ]] || return 0
  case "$BACKED_UP" in *"|$file|"*) return 0 ;; esac
  if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR="$HOME/.claude/backups/$(date +%Y%m%d-%H%M%S)"
    [[ -d "$BACKUP_DIR" ]] && BACKUP_DIR="${BACKUP_DIR}-$$"
    (umask 077; mkdir -p "$BACKUP_DIR")
  fi
  rel="${file#"$HOME"/}"
  dest="$BACKUP_DIR/$rel"
  (umask 077; mkdir -p "$(dirname "$dest")"; cp "$file" "$dest")
  BACKED_UP="${BACKED_UP}|$file|"
}

TARGET_NAMES=""
[[ "$DO_CLAUDE" == "1" ]] && TARGET_NAMES+=" claude"
[[ "$DO_AGY" == "1" ]] && TARGET_NAMES+=" antigravity"
[[ "$DO_CODEX" == "1" ]] && TARGET_NAMES+=" codex"
[[ -n "$TARGET_NAMES" ]] || err "no target selected"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   delilah-code-setup                     ║"
echo "║   rtk · qmd · codegraph · spec-kit       ║"
echo "║   engram · rulesync                      ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  OS: $OS"
echo "  Targets:$TARGET_NAMES"
echo ""

# ── Preflight ─────────────────────────────────────────────────
# Runs before any write. Fails fast, naming the missing tool or the bad file.
for tool in jq curl; do
  command -v "$tool" >/dev/null 2>&1 || err "$tool is required but not installed — install it and re-run"
done

CLAUDE_SETTINGS="$HOME/.claude/settings.json"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
MD_START='<!-- fran-setup:start -->'
MD_END='<!-- fran-setup:end -->'

# Prints "ok" when the markers in $1 are absent or one start followed by one end.
check_markers() {
  awk -v s="$MD_START" -v e="$MD_END" '
    $0 == s { ns++; if (ne > 0 || ns > 1) bad = 1 }
    $0 == e { ne++; if (ns == 0 || ne > 1) bad = 1 }
    END { print ((ns == ne && !bad) ? "ok" : "bad") }' "$1"
}

# check_json <file>: an existing, non-empty file we merge into must be a JSON object.
check_json() {
  [[ -s "$1" ]] || return 0
  jq -e 'type == "object"' "$1" >/dev/null 2>&1 \
    || err "$1 is not a valid JSON object — fix or remove it and re-run (nothing was changed)"
}

if [[ "$DO_CLAUDE" == "1" ]]; then
  check_json "$CLAUDE_SETTINGS"
  check_json "$HOME/.claude.json"
  if [[ -f "$CLAUDE_MD" && "$(check_markers "$CLAUDE_MD")" != "ok" ]]; then
    err "$CLAUDE_MD has unbalanced or duplicate fran-setup markers — fix them by hand and re-run (nothing was changed)"
  fi
fi
if [[ "$DO_AGY" == "1" ]]; then
  check_json "$HOME/.gemini/config/mcp_config.json"
  check_json "$HOME/.gemini/config/hooks.json"
  check_json "$HOME/.gemini/antigravity-cli/settings.json"
fi
if [[ "$DO_CODEX" == "1" ]]; then
  check_json "$HOME/.codex/hooks.json"
  if [[ -f "$HOME/.codex/AGENTS.md" && "$(check_markers "$HOME/.codex/AGENTS.md")" != "ok" ]]; then
    err "$HOME/.codex/AGENTS.md has unbalanced or duplicate fran-setup markers — fix them by hand and re-run (nothing was changed)"
  fi
fi

# ── Prerequisites ─────────────────────────────────────────────
install_bun() {
  if ! command -v bun &>/dev/null; then
    info "Installing bun..."
    curl -fsSL https://bun.sh/install | bash
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    ok "bun installed"
  fi
}

install_uv() {
  if ! command -v uv &>/dev/null; then
    info "Installing uv..."
    if [[ "$OS" == "Darwin" ]] && command -v brew &>/dev/null; then
      brew install uv
    else
      curl -LsSf https://astral.sh/uv/install.sh | sh
      export PATH="$HOME/.local/bin:$PATH"
    fi
    ok "uv installed"
  fi
}

install_rtk() {
  if command -v rtk &>/dev/null; then
    ok "rtk already installed ($(rtk --version 2>/dev/null || echo 'unknown version'))"
  else
    info "Installing rtk..."
    if [[ "$OS" == "Darwin" ]] && command -v brew &>/dev/null; then
      brew install rtk
    else
      curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh
    fi
    ok "rtk installed"
  fi
}

install_qmd() {
  if command -v qmd &>/dev/null; then
    ok "qmd already installed"
  else
    info "Installing qmd..."
    npm install -g @tobilu/qmd && ok "qmd installed"
  fi
}

install_codegraph() {
  if command -v codegraph &>/dev/null; then
    ok "codegraph already installed"
  else
    info "Installing codegraph via bun..."
    bun install -g @colbymchenry/codegraph && ok "codegraph installed"
  fi
}

install_specify() {
  if command -v specify &>/dev/null; then
    ok "specify already installed ($(specify --version 2>/dev/null || echo 'unknown version'))"
  else
    info "Installing specify-cli via uv..."
    uv tool install specify-cli --from git+https://github.com/github/spec-kit.git && ok "specify installed"
  fi
}

init_rtk_hook() {
  if command -v rtk &>/dev/null; then
    if rtk init -g --auto-patch 2>/dev/null; then ok "RTK hook configured"; else ok "RTK hook already configured"; fi
  fi
}

printf '\n%s\n' "── Prerequisites ──"
run_install install_bun
run_install install_uv

printf '\n%s\n' "── RTK ──"
run_install install_rtk

printf '\n%s\n' "── QMD ──"
run_install install_qmd

printf '\n%s\n' "── Codegraph ──"
run_install install_codegraph

printf '\n%s\n' "── Spec-kit ──"
run_install install_specify

# Engram: binary, Claude Code plugin and MCP registration (R7).
# CLAUDE_MISSING=1 makes the final message say plugin/MCP were not registered.
CLAUDE_MISSING=0
install_engram() {
  if command -v engram &>/dev/null; then
    ok "engram already installed ($(engram version 2>/dev/null || engram --version 2>/dev/null || echo 'unknown version'))"
  elif command -v brew &>/dev/null; then
    info "Installing engram via brew..."
    brew install gentleman-programming/tap/engram && ok "engram installed"
  else
    info "brew not found — install engram manually: https://github.com/Gentleman-Programming/engram"
  fi

  if ! command -v claude &>/dev/null; then
    CLAUDE_MISSING=1
    info "claude CLI not found — Engram plugin/MCP not registered"
    return 0
  fi
  # Capture output first: `grep -q` closing the pipe early would SIGPIPE claude under pipefail.
  local out
  out="$(claude plugin marketplace list 2>/dev/null || true)"
  grep -qi engram <<< "$out" \
    || claude plugin marketplace add Gentleman-Programming/engram \
    || info "could not add the Engram marketplace"
  out="$(claude plugin list 2>/dev/null || true)"
  grep -qi engram <<< "$out" \
    || claude plugin install engram \
    || info "could not install the Engram plugin"
  # The plugin ships its own MCP server: registering `engram setup claude-code`
  # as well would duplicate every mem_* tool. Only fall back when the plugin is absent.
  out="$(claude plugin list 2>/dev/null || true)"
  if grep -qi engram <<< "$out"; then
    ok "Engram plugin installed (provides the MCP server)"
  else
    out="$(claude mcp list 2>/dev/null || true)"
    if grep -qi engram <<< "$out"; then
      ok "Engram MCP already registered"
    elif command -v engram &>/dev/null; then
      if engram setup claude-code; then ok "Engram MCP registered"; else info "could not register the Engram MCP"; fi
    else
      info "engram binary missing — Engram MCP not registered"
    fi
  fi
}

printf '\n%s\n' "── Engram ──"
if [[ "$DO_CLAUDE" == "1" ]]; then
  run_install install_engram
elif ! command -v engram &>/dev/null; then
  info "engram not found — install it: brew install gentleman-programming/tap/engram"
fi

install_rulesync() {
  if command -v rulesync &>/dev/null; then
    ok "rulesync already installed ($(rulesync --version 2>/dev/null || echo 'unknown version'))"
  elif command -v brew &>/dev/null; then
    info "Installing rulesync via brew..."
    brew install rulesync && ok "rulesync installed"
  else
    info "Installing rulesync via npm..."
    npm install -g rulesync && ok "rulesync installed"
  fi
}

printf '\n%s\n' "── rulesync ──"
run_install install_rulesync
command -v rulesync &>/dev/null || err "rulesync is required but not installed — brew install rulesync (or npm i -g rulesync) and re-run"

# ── Generate into a staging HOME ──────────────────────────────
printf '\n%s\n' "── Generate ──"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
RS_TARGETS=""
[[ "$DO_CLAUDE" == "1" ]] && RS_TARGETS+=",claudecode"
[[ "$DO_AGY" == "1" ]] && RS_TARGETS+=",antigravity-cli"
[[ "$DO_CODEX" == "1" ]] && RS_TARGETS+=",codexcli"
gen_log="$STAGE.log"
if ! (cd "$REPO_DIR" && HOME="$STAGE" rulesync generate --global --targets "${RS_TARGETS#,}" --features '*') >"$gen_log" 2>&1; then
  cat "$gen_log" >&2; rm -f "$gen_log"
  err "rulesync generate failed — nothing was changed"
fi
# Show rulesync's warnings. The per-rule agy notices about ** globs become one line.
grep -iE 'warn|deprecat|ignored' "$gen_log" | grep -v 'Antigravity CLI permissions: skipping' | sed 's/^/  /' || true
if grep -q 'Antigravity CLI permissions: skipping' "$gen_log"; then
  warn "Antigravity does not get the ** file denies (.env, *.pem, *.key, secrets/): agy can read those files"
fi
rm -f "$gen_log"

# Every path we read from the staging HOME must exist, or a rulesync release
# changed its layout: stop before writing anything.
REQUIRED=()
[[ "$DO_CLAUDE" == "1" ]] && REQUIRED+=(.claude/agents .claude/skills .claude/rules .claude/settings.json .claude.json)
[[ "$DO_AGY" == "1" ]] && REQUIRED+=(.gemini/config/agents .gemini/config/rules .gemini/antigravity-cli/skills .gemini/config/mcp_config.json .gemini/config/hooks.json .gemini/antigravity-cli/settings.json)
[[ "$DO_CODEX" == "1" ]] && REQUIRED+=(.codex/agents .codex/rules .agents/skills .codex/hooks.json .codex/AGENTS.md .codex/config.toml)
for p in "${REQUIRED[@]}"; do
  [[ -e "$STAGE/$p" ]] || err "rulesync $(rulesync --version 2>/dev/null) did not generate ~/$p — its output layout changed; nothing was changed"
done

# rulesync expands ~ against the staging HOME; point those paths at the real one.
# Only config files carry them. The resolved form (/private/var on macOS) goes
# first, as it contains the other. Patterns and replacement are escaped for sed.
sed_esc() { printf '%s' "$1" | sed 's/[][\\.*^$|&/]/\\&/g'; }
STAGE_REAL="$(cd "$STAGE" && pwd -P)"
rx_real="$(sed_esc "$STAGE_REAL")"; rx_stage="$(sed_esc "$STAGE")"; rx_home="$(sed_esc "$HOME")"
while IFS= read -r f; do
  sed -e "s|$rx_real|$rx_home|g" -e "s|$rx_stage|$rx_home|g" "$f" > "$STAGE/.rewrite"
  cat "$STAGE/.rewrite" > "$f"
done < <(grep -rlF -e "$STAGE" -e "$STAGE_REAL" --include='*.json' --include='*.toml' --include='*.rules' "$STAGE" || true)
rm -f "$STAGE/.rewrite"
ok "generated for:$TARGET_NAMES"

# ── Merge helpers ─────────────────────────────────────────────
# install_file <rel>: copy $STAGE/<rel> over $HOME/<rel> when it differs,
# backing up the old copy. Prints the name when it changed.
install_file() {
  local src="$STAGE/$1" dest="$HOME/$1"
  if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then return 0; fi
  backup "$dest"
  mkdir -p "$(dirname "$dest")"
  if [[ -f "$dest" ]]; then cat "$src" > "$dest"; else cp "$src" "$dest"; fi
  echo "  → $1"
}

# install_tree <rel dir>: install_file every file rulesync generated under it.
# Files you added there yourself are left alone.
install_tree() {
  [[ -d "$STAGE/$1" ]] || return 0
  local f
  while IFS= read -r f; do
    install_file "${f#"$STAGE"/}"
  done < <(find "$STAGE/$1" -type f | sort)
}

# merge_json <rel> <jq filter file>: merge the generated file into the user's
# (filter gets it as $tpl). Creates it when missing or empty; writes through the
# path so symlinks and modes survive.
merge_json() {
  local src="$STAGE/$1" dest="$HOME/$1" filter="$2" tmp before
  [[ -f "$src" ]] || return 0
  mkdir -p "$(dirname "$dest")"
  if [[ ! -s "$dest" ]]; then
    backup "$dest"
    if [[ -e "$dest" ]]; then cat "$src" > "$dest"; else cp "$src" "$dest"; fi
    ok "$1 created"
    return 0
  fi
  before="$(cksum < "$dest")"
  tmp="$(mktemp "$STAGE/merge.XXXXXX")"
  if ! jq --indent 2 --slurpfile tpl "$src" -f "$filter" "$dest" > "$tmp"; then
    rm -f "$tmp"
    err "merge of $1 failed — $dest left untouched"
  fi
  # Compare content, not bytes: rewriting a file only to reformat it (e.g.
  # ~/.claude.json, which Claude Code updates constantly) is a needless race.
  if cmp -s <(jq -S . "$tmp") <(jq -S . "$dest"); then
    rm -f "$tmp"
    ok "$1 already up to date"
    return 0
  fi
  # A running agent may have rewritten the file meanwhile (~/.claude.json): don't drop its change.
  [[ "$(cksum < "$dest")" == "$before" ]] || err "$dest changed while merging — close the agent and re-run (later files not changed)"
  backup "$dest"
  cat "$tmp" > "$dest"
  rm -f "$tmp"
  ok "$1 merged"
}

# set_block <file> <block file>: replace the fran-setup block in <file> with the
# contents of <block file> (markers included), append it when absent, or remove
# it when <block file> is empty. Text outside the markers is never touched.
set_block() {
  local file="$1" blockfile="$2" tmp
  if [[ ! -f "$file" ]]; then
    [[ -s "$blockfile" ]] || return 0
    mkdir -p "$(dirname "$file")"
    cp "$blockfile" "$file"
    ok "${file#"$HOME"/} created"
    return 0
  fi
  tmp="$(mktemp "$STAGE/block.XXXXXX")"
  if grep -qxF "$MD_START" "$file"; then
    awk -v s="$MD_START" -v e="$MD_END" -v bf="$blockfile" '
      $0 == s { while ((getline l < bf) > 0) print l; skip = 1; next }
      skip && $0 == e { skip = 0; next }
      !skip { print }' "$file" > "$tmp"
  elif [[ -s "$blockfile" ]]; then
    { cat "$file"; printf '\n'; cat "$blockfile"; } > "$tmp"
  else
    cp "$file" "$tmp"
  fi
  if cmp -s "$tmp" "$file"; then
    rm -f "$tmp"
    ok "${file#"$HOME"/} already up to date"
    return 0
  fi
  backup "$file"
  cat "$tmp" > "$file"
  rm -f "$tmp"
  ok "${file#"$HOME"/} block updated"
}

# remove_legacy <file>: back up and delete a file an older setup installed.
remove_legacy() {
  [[ -f "$1" ]] || return 0
  backup "$1"
  rm "$1"
  info "removed legacy ${1#"$HOME"/} (backed up)"
}

# ── Claude Code ───────────────────────────────────────────────
# warn_stale_text: report session-memory text in CLAUDE.md outside the markers (never edited).
STALE_WARNED=0
warn_stale_text() {
  [[ -f "$CLAUDE_MD" ]] || return 0
  local hits
  hits="$(awk -v s="$MD_START" -v e="$MD_END" '
    $0 == s { inb = 1; next }
    $0 == e { inb = 0; next }
    !inb && /docs\/sessions|save-session.*\.md|QMD.*session/ { print "line " NR ": " $0 }' "$CLAUDE_MD")"
  [[ -z "$hits" ]] && return 0
  STALE_WARNED=1
  while IFS= read -r l; do
    warn "stale session-memory instructions outside fran-setup block: $l"
  done <<< "$hits"
}

install_claude() {
  printf '\n%s\n' "── Claude Code ──"
  install_tree .claude/agents
  install_tree .claude/skills
  install_tree .claude/rules
  # Drop the pre-SKILL.md layout so a stale <name>.md can't shadow the live skill.
  local d name
  for d in "$STAGE/.claude/skills"/*/; do
    name="$(basename "$d")"
    remove_legacy "$HOME/.claude/skills/$name/$name.md"
  done
  # run-tasks used to be a command; it is a skill now.
  remove_legacy "$HOME/.claude/commands/run-tasks.md"
  merge_json .claude/settings.json "$REPO_DIR/config/merge-settings.jq"
  merge_json .claude.json "$REPO_DIR/config/merge-json.jq"
  # The rules now live in ~/.claude/rules/delilah.md: drop the block older
  # versions put in CLAUDE.md so they aren't loaded twice.
  local empty; empty="$(mktemp "$STAGE/empty.XXXXXX")"
  set_block "$CLAUDE_MD" "$empty"
  rm -f "$empty"
  warn_stale_text
  run_install init_rtk_hook
}

# ── Antigravity ───────────────────────────────────────────────
install_agy() {
  printf '\n%s\n' "── Antigravity ──"
  install_tree .gemini/config/agents
  install_tree .gemini/config/rules
  install_tree .gemini/antigravity-cli/skills
  merge_json .gemini/config/mcp_config.json "$REPO_DIR/config/merge-json.jq"
  merge_json .gemini/antigravity-cli/settings.json "$REPO_DIR/config/merge-json.jq"
  # rulesync owns the "rulesync" hook set in hooks.json; other sets stay as they are.
  merge_json .gemini/config/hooks.json "$REPO_DIR/config/merge-hookset.jq"
  run_install init_rtk_agy
}

init_rtk_agy() {
  command -v rtk &>/dev/null || return 0
  if rtk init -g --agent antigravity --auto-patch </dev/null >/dev/null 2>&1; then ok "RTK plugin configured for Antigravity"; else info "could not configure the RTK plugin for Antigravity"; fi
}

# ── Codex ─────────────────────────────────────────────────────
CODEX_CONFIG_DIFF=0
install_codex() {
  printf '\n%s\n' "── Codex ──"
  install_tree .codex/agents
  install_tree .codex/rules
  install_tree .agents/skills
  merge_json .codex/hooks.json "$REPO_DIR/config/merge-json.jq"
  # Codex reads one AGENTS.md: keep ours in a managed block.
  local blockfile; blockfile="$(mktemp "$STAGE/block.XXXXXX")"
  { echo "$MD_START"; cat "$STAGE/.codex/AGENTS.md"; echo "$MD_END"; } > "$blockfile"
  set_block "$HOME/.codex/AGENTS.md" "$blockfile"
  rm -f "$blockfile"
  # config.toml is TOML and holds the user's own settings: create it, never rewrite it.
  if [[ ! -f "$HOME/.codex/config.toml" ]]; then
    install_file .codex/config.toml
  elif ! cmp -s "$STAGE/.codex/config.toml" "$HOME/.codex/config.toml"; then
    # Warn loudly only when what we ship changed since the last run; after that a
    # quiet reminder, so a config merged by hand doesn't warn forever.
    if cmp -s "$STAGE/.codex/config.toml" "$HOME/.codex/config.delilah.toml"; then
      info "Codex: config.toml still differs from config.delilah.toml (unchanged since last run)"
    else
      cp "$STAGE/.codex/config.toml" "$HOME/.codex/config.delilah.toml"
      CODEX_CONFIG_DIFF=1
      # shellcheck disable=SC2088  # literal ~ for display
      warn "~/.codex/config.toml exists and was left untouched; merge MCP servers and permissions from ~/.codex/config.delilah.toml by hand"
    fi
  fi
  run_install init_rtk_codex
}

init_rtk_codex() {
  command -v rtk &>/dev/null || return 0
  if rtk init -g --codex </dev/null >/dev/null 2>&1; then ok "RTK hook configured for Codex"; else info "could not configure the RTK hook for Codex"; fi
}

[[ "$DO_CLAUDE" == "1" ]] && install_claude
[[ "$DO_AGY" == "1" ]] && install_agy
[[ "$DO_CODEX" == "1" ]] && install_codex


# ── QMD daemon ────────────────────────────────────────────────
printf '\n%s\n' "── QMD daemon ──"
setup_qmd_daemon() {
  QMD_BIN=$(which qmd 2>/dev/null || echo "")

  if [[ -z "$QMD_BIN" ]]; then
    info "qmd binary not found — skipping daemon setup"
  elif [[ "$OS" == "Darwin" ]]; then
    # macOS — launchd
    PLIST="$HOME/Library/LaunchAgents/com.qmd.mcp.plist"
    mkdir -p "$HOME/Library/LaunchAgents"
    sed "s|/usr/local/bin/qmd|$QMD_BIN|g" "$REPO_DIR/config/com.qmd.mcp.plist" > "$PLIST"
    launchctl unload "$PLIST" 2>/dev/null || true
    launchctl load "$PLIST"
    sleep 2
    if curl -s http://localhost:8181/mcp &>/dev/null; then
      ok "QMD daemon running at http://localhost:8181/mcp (launchd)"
    else
      ok "QMD daemon configured — starts at next login (launchd)"
    fi
  elif command -v systemctl &>/dev/null; then
    # Linux — systemd user service
    SERVICE_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SERVICE_DIR"
    sed "s|/usr/bin/env qmd|$QMD_BIN|g" "$REPO_DIR/config/qmd-mcp.service" > "$SERVICE_DIR/qmd-mcp.service"
    systemctl --user daemon-reload
    systemctl --user enable qmd-mcp
    systemctl --user restart qmd-mcp
    sleep 2
    if curl -s http://localhost:8181/mcp &>/dev/null; then
      ok "QMD daemon running at http://localhost:8181/mcp (systemd)"
    else
      ok "QMD daemon configured — starts at next login (systemd)"
    fi
  else
    # Fallback — add to shell profile
    SHELL_RC="$HOME/.zshrc"
    [[ -f "$HOME/.bashrc" ]] && SHELL_RC="$HOME/.bashrc"
    DAEMON_LINE="# QMD daemon"$'\n'"pgrep -f 'qmd mcp' &>/dev/null || $QMD_BIN mcp --http --daemon &>/dev/null &"
    if ! grep -q "qmd mcp" "$SHELL_RC" 2>/dev/null; then
      printf '\n%s\n' "$DAEMON_LINE" >> "$SHELL_RC"
      ok "QMD daemon added to $SHELL_RC (starts on new shell)"
    else
      ok "QMD daemon already in $SHELL_RC"
    fi
  fi
}
run_install setup_qmd_daemon

# ── Done ──────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Setup complete                         ║"
echo "╚══════════════════════════════════════════╝"
echo ""
if [[ "$STALE_WARNED" == "1" ]]; then
  warn "stale session-memory text found in ~/.claude/CLAUDE.md — see docs/migration.md"
  echo ""
fi
if [[ "$CLAUDE_MISSING" == "1" ]]; then
  warn "claude CLI not found: the Engram plugin/MCP were NOT registered. Install Claude Code and re-run ./setup.sh"
  echo ""
fi
if [[ "$CODEX_CONFIG_DIFF" == "1" ]]; then
  warn "Codex: file denies and MCP servers from this setup are NOT active until you merge ~/.codex/config.delilah.toml into ~/.codex/config.toml"
  echo ""
fi
echo "Next steps:"
echo ""
echo "  1. Restart the agents you set up:$TARGET_NAMES"
echo "  2. cd into a project"
echo "  3. /setup-qmd indexes reference docs (docs/, specs/, ADRs; sessions/ is ignored)"
echo "  4. /recall loads context from Engram (QMD is only for docs)"
echo "  5. Check:  claude mcp list   ·   agy mcp list   ·   agy agents"
echo ""
echo "  After editing .rulesync/, re-run ./setup.sh: files are copied, not linked."
echo ""
if [[ -n "$BACKUP_DIR" ]]; then
  echo "Backups of overwritten files: $BACKUP_DIR"
else
  echo "Backups: nothing needed a backup"
fi
echo ""
echo "Useful commands:"
echo "  qmd collection list   — indexed collections"
echo "  codegraph status      — code graph status"
echo "  rtk gain              — token savings"
echo "  engram tui            — browse saved memories"
echo ""
