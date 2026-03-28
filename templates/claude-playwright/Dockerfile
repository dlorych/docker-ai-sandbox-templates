# syntax=docker/dockerfile:1
FROM docker/sandbox-templates:claude-code@sha256:6f3e7e9aefba722719eda4fe0c808b67fa98f54abc04464a2c5d8e489e740c9d

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Optional: install a proxy CA certificate for builds behind a TLS-intercepting proxy
# (e.g. Docker AI sandbox). Pass as base64-encoded PEM via --build-arg PROXY_CA_CERT=...
# No-op when the arg is empty (e.g. in GitHub Actions).
ARG PROXY_CA_CERT=""
RUN if [ -n "$PROXY_CA_CERT" ]; then \
    echo "$PROXY_CA_CERT" | base64 -d > /usr/local/share/ca-certificates/proxy-ca.crt && \
    update-ca-certificates; \
fi

# Install MCP servers globally (readable by all users via /usr/local/lib)
RUN npm install -g \
    @playwright/mcp \
    @upstash/context7-mcp \
    mcp-deepwiki && \
    rm -rf /root/.npm

# Install Chromium to a shared path accessible by the agent user.
# PLAYWRIGHT_BROWSERS_PATH overrides the default ~/.cache/ms-playwright location.
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
RUN npx playwright install chromium --with-deps && \
    chmod -R o+rX /opt/playwright-browsers && \
    rm -rf /tmp/*

# Configure Claude Code MCP settings for the agent user
RUN mkdir -p /home/agent/.claude && \
    cat > /home/agent/.claude/settings.json <<'EOF'
{
  "mcpServers": {
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
}
EOF

RUN chown -R agent:agent /home/agent/.claude

USER agent
