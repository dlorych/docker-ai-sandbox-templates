#!/bin/bash
# Ensure MCP servers are configured even if ~/.claude is mounted from the host at runtime.
# Only injects mcpServers if the settings file doesn't already define them.
# Enables Claude Code's native OTLP telemetry when OTEL_EXPORTER_OTLP_ENDPOINT is set.
set -e

SETTINGS_FILE="/home/agent/.claude/settings.json"
mkdir -p "$(dirname "$SETTINGS_FILE")"

python3 - <<'PYEOF'
import json, os, sys

settings_file = "/home/agent/.claude/settings.json"

mcp_servers = {
    "playwright": {
        "command": "npx",
        "args": ["@playwright/mcp@latest", "--headless"]
    },
    "context7": {
        "command": "npx",
        "args": ["-y", "@upstash/context7-mcp"]
    },
    "deepwiki": {
        "command": "npx",
        "args": ["-y", "mcp-deepwiki"]
    }
}

try:
    with open(settings_file) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

if "mcpServers" not in settings:
    settings["mcpServers"] = mcp_servers
    with open(settings_file, "w") as f:
        json.dump(settings, f, indent=2)
    print("claude-playwright: injected MCP server config into settings.json", file=sys.stderr)
PYEOF

# Enable Claude Code's native OTLP telemetry when an endpoint is configured.
# All variables use ${VAR:-default} so users can override any of them.
if [ -n "${OTEL_EXPORTER_OTLP_ENDPOINT:-}" ]; then
    export CLAUDE_CODE_ENABLE_TELEMETRY=1
    export OTEL_METRICS_EXPORTER="${OTEL_METRICS_EXPORTER:-otlp}"
    export OTEL_LOGS_EXPORTER="${OTEL_LOGS_EXPORTER:-otlp}"
    # http/json matches the standard HTTP port 4318; set to grpc for port 4317
    export OTEL_EXPORTER_OTLP_PROTOCOL="${OTEL_EXPORTER_OTLP_PROTOCOL:-http/json}"
    echo "[otel] Claude Code native telemetry enabled → ${OTEL_EXPORTER_OTLP_ENDPOINT}" >&2
fi

# Load environment variables from .env file if present in the workspace root.
if [ -f "${PWD}/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "${PWD}/.env"
    set +a
    echo "[env] Loaded environment from ${PWD}/.env" >&2
fi

exec "$@"
