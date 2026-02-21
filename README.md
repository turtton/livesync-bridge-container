# livesync-bridge-container

Auto-build and distribute Docker images of [vrtmrz/livesync-bridge](https://github.com/vrtmrz/livesync-bridge) via GHCR.

[日本語](README.ja-jp.md)

## Pulling the Image

```sh
docker pull ghcr.io/turtton/livesync-bridge:latest
```

### Tags

| Tag | Description |
|-----|-------------|
| `latest` | Latest build |
| `<commit-sha>` | First 12 characters of the upstream commit SHA (e.g., `abc123def456`) |
| `<YYYYMMDD>` | Build date (e.g., `20260221`) |

## Usage

Prepare a config file (`config.json`) and run as follows. See the [upstream repository](https://github.com/vrtmrz/livesync-bridge) for configuration details.

```yaml
# docker-compose.yml
services:
  bridge:
    image: ghcr.io/turtton/livesync-bridge:latest
    volumes:
      - ./dat:/app/dat   # Place config.json here
      - ./data:/app/data # Synced data storage
    restart: unless-stopped
```

```sh
docker compose up -d
```

## Patches

Patches in the `patches/` directory are applied to the upstream source at build time. Remove patches once they are merged upstream.

| Patch | Upstream PR | Description |
|-------|-------------|-------------|
| `fix-deno-install.patch` | [#33](https://github.com/vrtmrz/livesync-bridge/pull/33) | `deno install -A` → `deno install -gA main.ts` (Deno 2.x build fix) |

## How It Works

GitHub Actions checks the upstream repository for new commits daily at UTC 00:00. If a new commit is found, it builds the Docker image and pushes it to GHCR. Duplicate builds for the same commit are skipped.

Manual rebuilds can be triggered from the Actions tab via "Run workflow".
