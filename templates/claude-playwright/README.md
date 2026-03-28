# claude-playwright

A Claude Code sandbox image with Playwright, DeepWiki, and Context7 MCP servers pre-installed.

## What's included

- [`docker/sandbox-templates:claude-code`](https://hub.docker.com/r/docker/sandbox-templates) base image (Ubuntu, Claude Code agent, Node.js, Python 3, Go, Docker CLI)
- Chromium browser + all OS-level dependencies pre-installed at build time

## MCP servers

All three servers are pre-installed globally and auto-started via `settings.json`.

| Server | Package | Description |
|--------|---------|-------------|
| `playwright` | [`@playwright/mcp`](https://github.com/microsoft/playwright-mcp) | Browser automation — navigate pages, click, fill forms, screenshot, scrape |
| `context7` | [`@upstash/context7-mcp`](https://github.com/upstash/context7) | Fetch up-to-date library documentation directly into context |
| `deepwiki` | [`mcp-deepwiki`](https://github.com/regenrek/deepwiki-mcp) | Query DeepWiki for repository and codebase documentation |

## Usage

Pull the image:

```bash
docker pull ghcr.io/<owner>/claude-playwright:latest
```

Use it as your sandbox template:

```bash
docker sandbox run -t ghcr.io/<owner>/claude-playwright:latest claude ~/my-project
```

## Local build

```bash
docker build --platform linux/amd64 \
  --build-arg PROXY_CA_CERT=$PROXY_CA_CERT_B64 \
  -t claude-playwright:local .
```

> The `PROXY_CA_CERT` build arg is only needed when building inside a Docker AI sandbox
> (which uses a TLS-intercepting proxy). It is a no-op in GitHub Actions.

## MCP settings persistence

MCP servers are configured at build time in `/home/agent/.claude/settings.json`. When running via `docker sandbox run`, Docker mounts the user's local `~/.claude` directory over `/home/agent/.claude`, which would normally hide the baked-in config.

The image uses an entrypoint script (`/usr/local/bin/entrypoint.sh`) that runs before Claude starts and injects the `mcpServers` block into `settings.json` if it isn't already present. This ensures MCP servers are available regardless of whether the directory is mounted from the host.

## Verification

```bash
# Confirm running as agent user
docker run --rm --platform linux/amd64 claude-playwright:local whoami

# Confirm MCP settings are in place
docker run --rm --platform linux/amd64 claude-playwright:local cat /home/agent/.claude/settings.json

# Confirm Chromium launches headlessly
docker run --rm --platform linux/amd64 claude-playwright:local node -e "
  const { chromium } = require('playwright');
  (async () => {
    const b = await chromium.launch({ headless: true });
    const p = await b.newPage();
    await p.goto('about:blank');
    console.log('Chromium OK, title:', await p.title());
    await b.close();
  })();
"
```
