# syntax=docker/dockerfile:1
FROM docker/sandbox-templates:claude-code@sha256:6f3e7e9aefba722719eda4fe0c808b67fa98f54abc04464a2c5d8e489e740c9d

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
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER agent

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude", "--dangerously-skip-permissions"]
