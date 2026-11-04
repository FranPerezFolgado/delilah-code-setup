#!/usr/bin/env bash
# =============================================================
#  delilah-code-setup — Claude Code dev toolchain installer
#  Run from the repo root: ./setup.sh
#  Supports: macOS, Linux
# =============================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { printf '%b✓%b %s\n' "$GREEN" "$NC" "$1"; }
info() { printf '%b→%b %s\n' "$YELLOW" "$NC" "$1"; }
err()  { printf '%b✗%b %s\n' "$RED" "$NC" "$1" >&2; exit 1; }

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

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   delilah-code-setup                     ║"
echo "║   rtk · qmd · codegraph · spec-kit       ║"
echo "║   engram                                 ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  OS: $OS"
echo ""

# ── Preflight ─────────────────────────────────────────────────
# Runs before any write. Fails fast, naming the missing tool.
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

if [[ -f "$CLAUDE_SETTINGS" ]]; then
  jq -e 'type == "object"' "$CLAUDE_SETTINGS" >/dev/null 2>&1 \
    || err "$CLAUDE_SETTINGS is not a valid JSON object — fix or remove it and re-run (nothing was changed)"
fi
if [[ -f "$CLAUDE_MD" && "$(check_markers "$CLAUDE_MD")" != "ok" ]]; then
  err "$CLAUDE_MD has unbalanced or duplicate fran-setup markers — fix them by hand and re-run (nothing was changed)"
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
  out="$(claude mcp list 2>/dev/null || true)"
  if grep -qi engram <<< "$out"; then
    ok "Engram MCP already registered"
  elif command -v engram &>/dev/null; then
    if engram setup claude-code; then ok "Engram MCP registered"; else info "could not register the Engram MCP"; fi
  else
    info "engram binary missing — Engram MCP not registered"
  fi
}

printf '\n%s\n' "── Engram ──"
run_install install_engram

printf '\n%s\n' "── RTK hook ──"
run_install init_rtk_hook

# ── 6. MCP servers + permissions in ~/.claude/settings.json ───
# merge_settings: contracts/settings-merge.md. Backs up, merges via temp file + mv.
merge_settings() {
  local tpl="$REPO_DIR/config/settings.template.json" tmp
  mkdir -p "$HOME/.claude"
  if [[ ! -f "$CLAUDE_SETTINGS" ]]; then
    cp "$tpl" "$CLAUDE_SETTINGS"
    ok "settings.json created from template"
    return 0
  fi
  tmp="$(mktemp "$HOME/.claude/settings.json.XXXXXX")"
  if ! jq --indent 2 --slurpfile tpl "$tpl" -f "$REPO_DIR/config/merge-settings.jq" "$CLAUDE_SETTINGS" > "$tmp"; then
    rm -f "$tmp"
    err "settings merge failed — $CLAUDE_SETTINGS left untouched"
  fi
  if cmp -s "$tmp" "$CLAUDE_SETTINGS"; then
    rm -f "$tmp"
    ok "settings.json already up to date"
    return 0
  fi
  backup "$CLAUDE_SETTINGS"
  # Write through the path (not mv) so a symlinked file and its mode survive.
  cat "$tmp" > "$CLAUDE_SETTINGS"
  rm -f "$tmp"
  ok "settings.json merged"
}

printf '\n%s\n' "── MCP servers + permissions ──"
merge_settings

# ── 7. CLAUDE.md ──────────────────────────────────────────────
# shipped_block: the fran-setup block from config/CLAUDE.md (start..end inclusive).
shipped_block() {
  awk -v s="$MD_START" -v e="$MD_END" '$0 == s { on = 1 } on { print } $0 == e { on = 0 }' "$REPO_DIR/config/CLAUDE.md"
}

# manage_claude_md: create, append or replace the managed block; never touches
# text outside the markers. Backs up before writing.
manage_claude_md() {
  local src="$REPO_DIR/config/CLAUDE.md" block tmp blockfile
  mkdir -p "$HOME/.claude"
  if [[ ! -f "$CLAUDE_MD" ]]; then
    cp "$src" "$CLAUDE_MD"
    ok "CLAUDE.md installed"
    return 0
  fi
  block="$(shipped_block)"
  [[ -n "$block" ]] || err "managed block markers not found in $src — $CLAUDE_MD left untouched"
  tmp="$(mktemp "$HOME/.claude/CLAUDE.md.XXXXXX")"
  blockfile="$(mktemp)"
  printf '%s\n' "$block" > "$blockfile"
  if grep -qxF "$MD_START" "$CLAUDE_MD"; then
    awk -v s="$MD_START" -v e="$MD_END" -v bf="$blockfile" '
      $0 == s { while ((getline l < bf) > 0) print l; skip = 1; next }
      skip && $0 == e { skip = 0; next }
      !skip { print }' "$CLAUDE_MD" > "$tmp"
  else
    { cat "$CLAUDE_MD"; printf '\n'; cat "$blockfile"; } > "$tmp"
  fi
  rm -f "$blockfile"
  if cmp -s "$tmp" "$CLAUDE_MD"; then
    rm -f "$tmp"
    ok "CLAUDE.md already up to date"
    return 0
  fi
  backup "$CLAUDE_MD"
  cat "$tmp" > "$CLAUDE_MD"
  rm -f "$tmp"
  ok "CLAUDE.md block updated"
}

# warn_stale_text: report session-memory text outside the markers (never edited).
STALE_WARNED=0
warn_stale_text() {
  local hits
  hits="$(awk -v s="$MD_START" -v e="$MD_END" '
    $0 == s { inb = 1; next }
    $0 == e { inb = 0; next }
    !inb && /docs\/sessions|save-session.*\.md|QMD.*session/ { print "line " NR ": " $0 }' "$CLAUDE_MD")"
  [[ -z "$hits" ]] && return 0
  STALE_WARNED=1
  while IFS= read -r l; do
    printf '%b⚠%b stale session-memory instructions outside fran-setup block: %s\n' "$YELLOW" "$NC" "$l"
  done <<< "$hits"
}

printf '\n%s\n' "── CLAUDE.md ──"
manage_claude_md
warn_stale_text

# ── 8. Skills ─────────────────────────────────────────────────
printf '\n%s\n' "── Skills ──"
mkdir -p "$HOME/.claude/skills"
for skill_dir in "$REPO_DIR/skills/"/*/; do
  name=$(basename "$skill_dir")
  mkdir -p "$HOME/.claude/skills/$name"
  for f in "$skill_dir"*.md; do
    backup "$HOME/.claude/skills/$name/$(basename "$f")"
    cp "$f" "$HOME/.claude/skills/$name/"
  done
  echo "  → $name"
done
ok "skills installed"

# ── 9. Agents ─────────────────────────────────────────────────
printf '\n%s\n' "── Agents ──"
mkdir -p "$HOME/.claude/agents"
for agent in "$REPO_DIR/agents/"*.md; do
  name=$(basename "$agent")
  backup "$HOME/.claude/agents/$name"
  cp "$agent" "$HOME/.claude/agents/$name"
  echo "  → $name"
done
ok "agents installed"

# ── 9b. Commands ──────────────────────────────────────────────
printf '\n%s\n' "── Commands ──"
mkdir -p "$HOME/.claude/commands"
for cmd in "$REPO_DIR/commands/"*.md; do
  [ -e "$cmd" ] || continue
  name=$(basename "$cmd")
  backup "$HOME/.claude/commands/$name"
  cp "$cmd" "$HOME/.claude/commands/$name"
  echo "  → $name"
done
ok "commands installed"

# ── 9. QMD daemon ─────────────────────────────────────────────
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
  printf '%b⚠%b stale session-memory text found in ~/.claude/CLAUDE.md — see docs/migration.md\n\n' "$YELLOW" "$NC"
fi
if [[ "$CLAUDE_MISSING" == "1" ]]; then
  printf '%b⚠%b claude CLI not found: the Engram plugin/MCP were NOT registered. Install Claude Code and re-run ./setup.sh\n\n' "$YELLOW" "$NC"
fi
echo "Next steps:"
echo ""
echo "  1. Restart Claude Code"
echo "  2. cd into a project"
echo "  3. /setup-qmd indexes reference docs (docs/, specs/, ADRs; sessions/ is ignored)"
echo "  4. /recall loads context from Engram (QMD is only for docs)"
echo "  5. Check Engram: claude mcp list | grep engram   or   engram tui"
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
