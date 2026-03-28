# Docker AI Sandbox Images

Custom Docker images for [Docker AI sandboxes](https://docs.docker.com/ai/sandboxes/), built on top of `docker/sandbox-templates`.

Images are published to GitHub Container Registry (`ghcr.io`) and automatically rebuilt on every push to `main`.

## Templates

| Template | Description | Image |
|----------|-------------|-------|
| [claude-playwright](./templates/claude-playwright/) | Claude Code + Playwright MCP server + Chromium | `ghcr.io/<owner>/claude-playwright` |

## Adding a New Template

1. Create `templates/<name>/Dockerfile` based on `docker/sandbox-templates:claude-code`
2. Add `<name>` to the `matrix.template` list in `.github/workflows/build-and-push.yml`
3. Add a `docker` entry for `/templates/<name>` in `.github/dependabot.yml`
4. Add a row to the table above and a `templates/<name>/README.md`

## Local Development

```bash
# Build a template locally
docker build --platform linux/amd64 -t <template>:local ./templates/<template>

# Run a shell in the built image
docker run --rm -it <template>:local bash
```

## CI/CD

The [build-and-push](./.github/workflows/build-and-push.yml) workflow:

- Runs on push to `main` and pull requests (path-filtered to `templates/**`)
- Builds for `linux/amd64` and `linux/arm64`
- Pushes to `ghcr.io` on merge to `main`; PRs build only (no push)
- Uses GitHub Actions cache per template for fast incremental builds

## Dependency Updates

[Dependabot](./.github/dependabot.yml) opens weekly PRs to update:

- Pinned GitHub Actions SHA versions
- Dockerfile base image digests (one entry per template directory)
