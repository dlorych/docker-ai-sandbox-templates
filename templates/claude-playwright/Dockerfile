# syntax=docker/dockerfile:1
FROM docker/sandbox-templates:claude-code@sha256:62cff3be5ec78dbabc82b02ec36f89a2ece4809855063889e37dae747f1f6296

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ARG PROXY_CA_CERT=""
RUN if [ -n "$PROXY_CA_CERT" ]; then \
    echo "$PROXY_CA_CERT" | base64 -d > /usr/local/share/ca-certificates/proxy-ca.crt && \
    update-ca-certificates; \
fi

# Install Chromium
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers

# Install MCP servers globally; PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD prevents duplicate browser downloads
# (browsers are installed explicitly below via playwright install)
RUN PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install -g --no-save \
    @playwright/mcp \
    @upstash/context7-mcp \
    mcp-deepwiki && \
    npm cache clean --force

RUN npx --yes playwright install chromium --with-deps && \
    chmod -R o+rX /opt/playwright-browsers && \
    rm -rf /tmp/*

# Configure Claude Code MCP settings as a build-time fallback (for plain docker run without mounts).
# The entrypoint re-applies these at runtime so they survive when ~/.claude is mounted from the host.
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

# Install entrypoint script that ensures MCP config survives runtime volume mounts
# and enables Claude Code native telemetry when OTEL_EXPORTER_OTLP_ENDPOINT is set
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER agent

CMD ["/usr/local/bin/entrypoint.sh", "claude", "--dangerously-skip-permissions"]
