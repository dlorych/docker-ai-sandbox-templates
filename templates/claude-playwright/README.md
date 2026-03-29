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

## Environment variables

`docker sandbox run` does not support `-e`/`--env` flags. To inject environment variables into the sandbox, place a `.env` file in your workspace root:

```bash
# ~/my-project/.env
MY_API_KEY=secret
MY_CONFIG=value
```

The entrypoint sources this file automatically before launching Claude. All exported variables are available to Claude and any subprocesses it spawns.

> **Security note:** Keep `.env` in `.gitignore` to avoid committing secrets.

## OpenTelemetry / monitoring

The image enables [Claude Code's built-in OTLP telemetry](https://code.claude.com/docs/en/monitoring-usage) when you provide an OTLP endpoint. Set a single environment variable and point it at any OTLP-compatible collector:

```bash
docker run \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4318 \
  ghcr.io/<owner>/claude-playwright:latest
```

The entrypoint automatically sets the required Claude Code telemetry variables when the endpoint is configured. All other variables can be overridden.

### What is collected

**Metrics** (pushed every 60 s by default):

| Metric | Description |
|--------|-------------|
| `claude_code.session.count` | Session starts |
| `claude_code.token.usage` | Input / output / cache tokens consumed |
| `claude_code.cost.usage` | API cost in USD |
| `claude_code.lines_of_code.count` | Lines added / removed |
| `claude_code.pull_request.count` | PRs created |
| `claude_code.commit.count` | Git commits made |
| `claude_code.active_time.total` | Active usage time |
| `claude_code.code_edit_tool.decision` | File-edit permission decisions |

**Events / logs** (pushed every 5 s by default):

| Event | Description |
|-------|-------------|
| `claude_code.user_prompt` | User message submitted |
| `claude_code.api_request` | API call with timing and cost |
| `claude_code.api_error` | Failed API request |
| `claude_code.tool_result` | Tool execution completed |
| `claude_code.tool_decision` | Permission decision for a tool |

### Environment variables

**Trigger (one variable enables everything):**

| Variable | Description |
|---|---|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Base URL of your OTLP receiver, e.g. `http://host.docker.internal:4318`. Telemetry is fully disabled when unset. |

**Auto-set by entrypoint (overridable):**

| Variable | Auto value | Notes |
|---|---|---|
| `CLAUDE_CODE_ENABLE_TELEMETRY` | `1` | Master switch for native telemetry |
| `OTEL_METRICS_EXPORTER` | `otlp` | Set to `otlp,prometheus` to fan out |
| `OTEL_LOGS_EXPORTER` | `otlp` | Set to `otlp,console` to also print |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/json` | Override to `grpc` when using port 4317 |

**Optional:**

| Variable | Default | Description |
|---|---|---|
| `OTEL_SERVICE_NAME` | `claude-code-sandbox` | Service name attached to all telemetry |
| `OTEL_RESOURCE_ATTRIBUTES` | — | Extra attributes, e.g. `team=backend,env=prod` |
| `OTEL_LOG_USER_PROMPTS` | `0` | Set `1` to include prompt text in events |
| `OTEL_LOG_TOOL_DETAILS` | `0` | Set `1` to include tool parameters in events |
| `OTEL_METRIC_EXPORT_INTERVAL` | `60000` | Metrics flush interval (ms) |
| `OTEL_LOGS_EXPORT_INTERVAL` | `5000` | Events flush interval (ms) |

### Backend examples

> **Note for `docker sandbox run` users:** The LGTM and ADOT examples below use `host.docker.internal` and plain `docker run`. They are intended for local testing only — the sandbox microVM cannot reach the host's loopback, so `host.docker.internal` resolves to nothing inside a real sandbox. For sandbox deployments, use the Grafana Cloud direct endpoint instead.

**Grafana Cloud (direct OTLP — recommended for `docker sandbox run`):**

Get your credentials from the [Grafana Cloud portal](https://grafana.com/): select your stack → OpenTelemetry tile → **Configure** → generate an API token. The portal will display your instance ID and gateway URL.

```bash
# docker sandbox run — use a .env file in your workspace root
# ~/my-project/.env:
#   OTEL_EXPORTER_OTLP_ENDPOINT=https://otlp-gateway-<zone>.grafana.net/otlp
#   OTEL_EXPORTER_OTLP_HEADERS=Authorization=Basic <base64(instanceID:apiToken)>
#   OTEL_SERVICE_NAME=my-sandbox
docker sandbox run \
  -t ghcr.io/<owner>/claude-playwright:latest \
  claude ~/my-project
```

The gateway URL routes all signals automatically: metrics go to Mimir, logs go to Loki — no signal-specific path suffixes needed. The default `http/json` protocol works with Grafana Cloud; if you want a smaller payload you can override to `http/protobuf`:

```bash
  -e OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf \
```

> **Credentials:** Avoid committing the base64 token. Generate it once and store it in your `.env` file (which should be in `.gitignore`):
> ```bash
> echo "OTEL_EXPORTER_OTLP_HEADERS=Authorization=Basic $(echo -n 'instanceID:apiToken' | base64)" >> ~/my-project/.env
> ```
>
> **Sandbox lifecycle:** Environment variables cannot be hot-reloaded — to change them, edit the `.env` file and recreate the sandbox.

For local testing with `docker run` (not a sandbox):

```bash
docker run \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=https://otlp-gateway-<zone>.grafana.net/otlp \
  -e "OTEL_EXPORTER_OTLP_HEADERS=Authorization=Basic <base64(instanceID:apiToken)>" \
  -e OTEL_SERVICE_NAME=my-sandbox \
  ghcr.io/<owner>/claude-playwright:latest
```

**LGTM stack (Grafana Alloy on host):**

```bash
docker run \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4318 \
  -e OTEL_SERVICE_NAME=my-sandbox \
  ghcr.io/<owner>/claude-playwright:latest
```

Configure [Grafana Alloy](https://grafana.com/docs/alloy/) on the host to accept OTLP on port 4318 and forward to Loki (logs) and Mimir/Prometheus (metrics).

**AWS CloudWatch (ADOT Collector on host):**

```bash
docker run \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4318 \
  -e OTEL_SERVICE_NAME=my-sandbox \
  ghcr.io/<owner>/claude-playwright:latest
```

Run the [AWS Distro for OpenTelemetry Collector](https://aws-otel.github.io/docs/getting-started/collector) on the host configured with `awscloudwatchlogs` and `awsemf` exporters. AWS credentials stay on the collector, not in the sandbox image.

**Debug (otelcol printing to stdout):**

```bash
# Run a local collector that prints all received data
docker run --rm -p 4318:4318 \
  otel/opentelemetry-collector-contrib \
  --config='
receivers:
  otlp:
    protocols:
      http:
        endpoint: 0.0.0.0:4318
exporters:
  debug:
    verbosity: detailed
service:
  pipelines:
    logs:    {receivers: [otlp], exporters: [debug]}
    metrics: {receivers: [otlp], exporters: [debug]}
'

# Then run the sandbox pointing at it
docker run \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4318 \
  ghcr.io/<owner>/claude-playwright:latest
```

## Verification

```bash
# Confirm .env injection works (create a test .env in current directory)
echo "TEST_VAR=hello_from_env" > /tmp/test-env-dir/.env
docker run --rm --platform linux/amd64 \
  -w /tmp/test-env-dir \
  -v /tmp/test-env-dir:/tmp/test-env-dir \
  claude-playwright:local bash -c 'source /usr/local/bin/entrypoint.sh true && echo $TEST_VAR'
# Expected: hello_from_env

# Confirm running as agent user
docker run --rm --platform linux/amd64 claude-playwright:local whoami

# Confirm MCP settings are in place
docker run --rm --platform linux/amd64 claude-playwright:local cat /home/agent/.claude/settings.json

# Confirm telemetry env vars are set when endpoint is provided
docker run --rm --platform linux/amd64 \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4318 \
  claude-playwright:local env | grep -E 'CLAUDE_CODE|OTEL'

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
