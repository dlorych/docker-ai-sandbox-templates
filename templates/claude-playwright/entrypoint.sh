#!/bin/bash
# Ensure MCP servers are configured even if ~/.claude is mounted from the host at runtime.
# Only injects mcpServers if the settings file doesn't already define them.
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

exec "$@"
