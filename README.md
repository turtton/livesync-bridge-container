# livesync-bridge-container

Auto-build and distribute Docker images of [vrtmrz/livesync-bridge](https://github.com/vrtmrz/livesync-bridge) via GHCR.

[日本語](README.ja-jp.md)

## Pulling the Image

```sh
docker pull ghcr.io/turtton/livesync-bridge:latest
```

### Image Variants

Two image variants are built from each upstream commit:

| Variant | Tags | Description |
|---------|------|-------------|
| **upstream** | `latest`, `<sha>`, `<date>` | Minimal fix only (`fix-deno-install.patch`) to make the upstream Dockerfile build on Deno 2.x |
| **patched** | `latest-patched`, `<sha>-patched`, `<date>-patched` | All patches applied. Dependencies are fully pre-cached so the container starts without downloading anything at runtime |

### Tags

| Tag | Description |
|-----|-------------|
| `latest` / `latest-patched` | Latest build |
| `<commit-sha>` / `<commit-sha>-patched` | First 12 characters of the upstream commit SHA (e.g., `abc123def456`) |
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

## Patches

Patches in the `patches/` directory are applied to the upstream source at build time. `fix-deno-install.patch` is applied to both variants; the remaining patches are applied only to the patched variant. These patches will be removed once they are merged upstream.

| Patch | Upstream PR | Applied to | Description |
|-------|-------------|------------|-------------|
| `fix-deno-install.patch` | [#33](https://github.com/vrtmrz/livesync-bridge/pull/33) | both | `deno install -A` → `deno install -gA main.ts` (Deno 2.x build fix) |
| `add-git.patch` | - | patched | Install `git` and `ca-certificates` in the Docker image |
| `pre-cache-deps.patch` | - | patched | Pre-cache dependencies with `deno install --entrypoint` so the container starts without network access |

## How It Works

GitHub Actions checks the upstream repository for new commits daily at UTC 00:00. If a new commit is found, it builds the Docker image and pushes it to GHCR. Duplicate builds for the same commit are skipped.

Manual rebuilds can be triggered from the Actions tab via "Run workflow".
