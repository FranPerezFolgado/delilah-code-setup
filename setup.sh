#!/usr/bin/env zsh
# =============================================================
#  delilah-code-setup — Claude Code dev toolchain installer
#  Run from the repo root: ./setup.sh
#  Supports: macOS, Linux
# =============================================================

set -euo pipefail

REPO_DIR="${0:A:h}"
OS="$(uname -s)"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo "${GREEN}✓${NC} $1" }
info() { echo "${YELLOW}→${NC} $1" }
err()  { echo "${RED}✗${NC} $1"; exit 1 }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   delilah-code-setup                     ║"
echo "║   rtk · qmd · codegraph · spec-kit       ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  OS: $OS"
echo ""

# ── Prerequisites ─────────────────────────────────────────────
if ! command -v bun &>/dev/null; then
  info "Installing bun..."
  curl -fsSL https://bun.sh/install | bash
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
  ok "bun installed"
fi

# ── 1. RTK ────────────────────────────────────────────────────
echo "\n── RTK ──"
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

# ── 2. QMD ────────────────────────────────────────────────────
echo "\n── QMD ──"
if command -v qmd &>/dev/null; then
  ok "qmd already installed"
else
  info "Installing qmd..."
  npm install -g @tobilu/qmd && ok "qmd installed"
fi

# ── 3. Codegraph ──────────────────────────────────────────────
echo "\n── Codegraph ──"
if command -v codegraph &>/dev/null; then
  ok "codegraph already installed"
else
  info "Installing codegraph via bun..."
  bun install -g @colbymchenry/codegraph && ok "codegraph installed"
fi

# ── 4. Spec-kit ───────────────────────────────────────────────
echo "\n── Spec-kit ──"
if command -v claude &>/dev/null; then
  info "Installing spec-kit plugin..."
  claude plugin install github/spec-kit 2>/dev/null && ok "spec-kit installed" || ok "spec-kit already installed"
else
  info "Claude Code CLI not found — install spec-kit manually later:"
  info "  claude plugin install github/spec-kit"
fi

# ── 5. RTK hook ───────────────────────────────────────────────
echo "\n── RTK hook ──"
if command -v rtk &>/dev/null; then
  rtk init -g --auto-patch 2>/dev/null && ok "RTK hook configured" || ok "RTK hook already configured"
fi

# ── 6. MCP servers + permissions in ~/.claude/settings.json ───
echo "\n── MCP servers + permissions ──"
mkdir -p "$HOME/.claude"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

python3 - "$CLAUDE_SETTINGS" <<'PYEOF'
import json, sys

path = sys.argv[1]
try:
    with open(path) as f:
        config = json.load(f)
except:
    config = {}

mcp = config.setdefault("mcpServers", {})
if "qmd" not in mcp:
    mcp["qmd"] = {"url": "http://localhost:8181/mcp"}
    print("  → qmd MCP added")
else:
    print("  ✓ qmd MCP already configured")

if "codegraph" not in mcp:
    mcp["codegraph"] = {"type": "stdio", "command": "codegraph", "args": ["serve", "--mcp"]}
    print("  → codegraph MCP added")
else:
    print("  ✓ codegraph MCP already configured")

perms = config.setdefault("permissions", {})
allow = perms.setdefault("allow", [])
tools = [
    "mcp__codegraph__codegraph_search", "mcp__codegraph__codegraph_context",
    "mcp__codegraph__codegraph_callers", "mcp__codegraph__codegraph_callees",
    "mcp__codegraph__codegraph_impact", "mcp__codegraph__codegraph_node",
    "mcp__codegraph__codegraph_status", "mcp__codegraph__codegraph_files",
    "mcp__qmd__query", "mcp__qmd__get", "mcp__qmd__multi_get", "mcp__qmd__status",
]
added = [t for t in tools if t not in allow]
allow.extend(added)

with open(path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")

print(f"  → {len(added)} tools added to auto-allow" if added else "  ✓ permissions already configured")
PYEOF

ok "MCP servers and permissions configured"

# ── 7. CLAUDE.md ──────────────────────────────────────────────
echo "\n── CLAUDE.md ──"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
if [[ -f "$CLAUDE_MD" ]] && grep -q "Codegraph" "$CLAUDE_MD" 2>/dev/null; then
  ok "CLAUDE.md already configured"
else
  cp "$REPO_DIR/config/CLAUDE.md" "$CLAUDE_MD"
  ok "CLAUDE.md installed"
fi

# ── 8. Skills ─────────────────────────────────────────────────
echo "\n── Skills ──"
mkdir -p "$HOME/.claude/skills"
for skill_dir in "$REPO_DIR/skills/"/*/; do
  name=$(basename "$skill_dir")
  mkdir -p "$HOME/.claude/skills/$name"
  cp "$skill_dir"*.md "$HOME/.claude/skills/$name/"
  echo "  → $name"
done
ok "skills installed"

# ── 9. Agents ─────────────────────────────────────────────────
echo "\n── Agents ──"
mkdir -p "$HOME/.claude/agents"
for agent in "$REPO_DIR/agents/"*.md; do
  name=$(basename "$agent")
  cp "$agent" "$HOME/.claude/agents/$name"
  echo "  → $name"
done
ok "agents installed"

# ── 9. QMD daemon ─────────────────────────────────────────────
echo "\n── QMD daemon ──"
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
  DAEMON_LINE="# QMD daemon\npgrep -f 'qmd mcp' &>/dev/null || $QMD_BIN mcp --http --daemon &>/dev/null &"
  if ! grep -q "qmd mcp" "$SHELL_RC" 2>/dev/null; then
    echo "\n$DAEMON_LINE" >> "$SHELL_RC"
    ok "QMD daemon added to $SHELL_RC (starts on new shell)"
  else
    ok "QMD daemon already in $SHELL_RC"
  fi
fi

# ── Done ──────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Setup complete                         ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo ""
echo "  1. Restart Claude Code"
echo "  2. cd into a project"
echo "  3. Run /setup-qmd to index docs"
echo "  4. Run /recall to load context"
echo ""
echo "Useful commands:"
echo "  qmd collection list   — indexed collections"
echo "  codegraph status      — code graph status"
echo "  rtk gain              — token savings"
echo ""
