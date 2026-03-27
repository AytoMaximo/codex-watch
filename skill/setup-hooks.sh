#!/bin/bash
# Codex Watch — Install Codex CLI hooks so sessions stream to the bridge.
#
# Usage:
#   ./setup-hooks.sh            # install to default bridge port 7860
#   ./setup-hooks.sh 7861       # install with custom bridge port
#   ./setup-hooks.sh --remove   # remove only hooks managed by this script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FORWARDER="${SCRIPT_DIR}/hook-forwarder.sh"
HOOKS_FILE="$HOME/.codex/hooks.json"
CONFIG_FILE="$HOME/.codex/config.toml"
PORT="${1:-7860}"
BRIDGE_URL="http://127.0.0.1:${PORT}"

if [ "${1:-}" = "--remove" ]; then
  mkdir -p "$(dirname "$HOOKS_FILE")"
  if [ ! -f "$HOOKS_FILE" ]; then
    echo "No hooks file found at $HOOKS_FILE"
    exit 0
  fi

  python3 - <<PY
import json
from pathlib import Path

hooks_file = Path("$HOOKS_FILE")
forwarder = str(Path("$FORWARDER").resolve())

with hooks_file.open("r", encoding="utf-8") as f:
    data = json.load(f)

hooks = data.get("hooks", [])
filtered = []
for hook in hooks:
    cmd = hook.get("command", [])
    if isinstance(cmd, list) and len(cmd) >= 2 and cmd[0] == "bash" and cmd[1] == forwarder:
        continue
    filtered.append(hook)

data["hooks"] = filtered

with hooks_file.open("w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print(f"Removed Codex Watch hooks from {hooks_file}")
PY

  exit 0
fi

mkdir -p "$(dirname "$HOOKS_FILE")"
if [ ! -f "$HOOKS_FILE" ]; then
  echo '{"hooks":[]}' > "$HOOKS_FILE"
fi

echo "Installing Codex Watch hooks..."
echo "  Bridge URL: ${BRIDGE_URL}"
echo "  Hooks file: ${HOOKS_FILE}"
echo "  Forwarder : ${FORWARDER}"
echo ""

if curl -s --connect-timeout 2 "${BRIDGE_URL}/status" > /dev/null 2>&1; then
  echo "  Bridge status: RUNNING"
else
  echo "  Bridge status: NOT RUNNING (hooks will send once the bridge is started)"
fi

python3 - <<PY
import json
from pathlib import Path

hooks_file = Path("$HOOKS_FILE")
bridge_url = "$BRIDGE_URL"
forwarder = str(Path("$FORWARDER").resolve())

events = [
    "SessionStart",
    "UserPromptSubmit",
    "PreToolUse",
    "PostToolUse",
    "Stop",
]

with hooks_file.open("r", encoding="utf-8") as f:
    data = json.load(f)

if "hooks" not in data or not isinstance(data["hooks"], list):
    data["hooks"] = []

data["hooks"] = [
    h for h in data["hooks"]
    if not (
        isinstance(h.get("command"), list)
        and len(h["command"]) >= 2
        and h["command"][0] == "bash"
        and h["command"][1] == forwarder
    )
]

for event in events:
    data["hooks"].append({
        "event": event,
        "matcher": ".*",
        "command": ["bash", forwarder, bridge_url, event],
    })

with hooks_file.open("w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\\n")

print(f"Installed hooks for: {', '.join(events)}")
PY

if [ ! -f "$CONFIG_FILE" ]; then
  mkdir -p "$(dirname "$CONFIG_FILE")"
  touch "$CONFIG_FILE"
fi

if ! rg -q "codex_hooks\\s*=\\s*true" "$CONFIG_FILE"; then
  {
    echo ""
    echo "[features]"
    echo "codex_hooks = true"
  } >> "$CONFIG_FILE"
fi

chmod +x "$FORWARDER"

echo ""
echo "Done! Codex CLI hooks are now configured."
echo "Start using:"
echo "  1. Run bridge:  cd skill/bridge && node server.js"
echo "  2. Run Codex:   codex"
echo "  3. Pair from iPhone/Watch using the bridge code"
echo ""
echo "Remove hooks: ./skill/setup-hooks.sh --remove"
