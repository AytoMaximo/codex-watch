#!/bin/bash
set -euo pipefail

BRIDGE_URL="${1:?bridge url required}"
EVENT_NAME="${2:?event name required}"
ENDPOINT="${BRIDGE_URL}/hooks/codex-event"

PAYLOAD="$(cat)"

# Forward hook payload to the bridge. This script is intentionally silent:
# hooks should not print extra output unless they intend to affect Codex flow.
curl -sS -X POST \
  -H "Content-Type: application/json" \
  -d "{\"event\":\"${EVENT_NAME}\",\"payload\":${PAYLOAD:-{}}}" \
  "${ENDPOINT}" > /dev/null

exit 0
