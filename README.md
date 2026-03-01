# livesync-bridge-container

Auto-build and distribute Docker images of [vrtmrz/livesync-bridge](https://github.com/vrtmrz/livesync-bridge) via GHCR.

[日本語](README.ja-jp.md)

## Pulling the Image

```sh
docker pull ghcr.io/turtton/livesync-bridge:latest
```

### Image Variants

Two image variants are available:

| Variant | Tags | Description |
|---------|------|-------------|
| **upstream** | `latest`, `<sha>`, `<date>` | Minimal fix only (`fix-deno-install.patch`) to make the upstream Dockerfile build on Deno 2.x |
| **patched** | `latest-patched`, `<sha>-patched`, `<date>-patched` | Built from [turtton/livesync-bridge](https://github.com/turtton/livesync-bridge) fork. Dependencies are fully pre-cached so the container starts without downloading anything at runtime |

### Tags

| Tag | Description |
|-----|-------------|
| `latest` / `latest-patched` | Latest build |
| `<commit-sha>` / `<commit-sha>-patched` | First 12 characters of the commit SHA (upstream SHA for `latest`, fork SHA for `latest-patched`) |
| `<YYYYMMDD>` / `<YYYYMMDD>-patched` | Build date (e.g., `20260221`) |

## Usage

Prepare a config file (`config.json`) and run as follows. See the [upstream repository](https://github.com/vrtmrz/livesync-bridge) for configuration details.

```yaml
# docker-compose.yml
services:
  bridge:
    image: ghcr.io/turtton/livesync-bridge:latest-patched
    volumes:
      - ./dat:/app/dat   # Place config.json here
      - ./data:/app/data # Synced data storage
    restart: unless-stopped
```

```sh
docker compose up -d
```

## Patches & Fork

The **upstream** variant applies `fix-deno-install.patch` to the upstream source at build time to fix Deno 2.x compatibility.

The **patched** variant is built directly from the [turtton/livesync-bridge](https://github.com/turtton/livesync-bridge) fork (included as a git submodule). All additional modifications are maintained in the fork rather than as patch files, improving maintainability.

### Changes in the fork

| Change | Description |
|--------|-------------|
| Dockerfile improvements | Install `git` and `ca-certificates`, pre-cache dependencies with `deno install --entrypoint` |
| PeerCouchDB ready race fix | Add `await this.man.ready.promise` to `delete()`/`put()`/`get()`/`getMeta()` to prevent race conditions |

### Patches applied to upstream

| Patch | Upstream PR | Description |
|-------|-------------|-------------|
| `fix-deno-install.patch` | [#33](https://github.com/vrtmrz/livesync-bridge/pull/33) | `deno install -A` → `deno install -gA main.ts` (Deno 2.x build fix) |

## How It Works

GitHub Actions runs two independent build pipelines:

- **upstream**: Checks the upstream repository for new commits daily at UTC 00:00. If a new commit is found, it clones the upstream source, applies `fix-deno-install.patch`, builds the Docker image, and pushes it to GHCR.
- **patched**: Triggered on push to `main` (e.g., submodule updates) or on schedule/manual dispatch. Uses the fork submodule directly as the build context without any patch application.

Duplicate builds for the same commit are skipped in both pipelines. Manual rebuilds can be triggered from the Actions tab via "Run workflow".
