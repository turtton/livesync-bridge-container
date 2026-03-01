# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CI/CD wrapper repository that builds and distributes Docker images of [vrtmrz/livesync-bridge](https://github.com/vrtmrz/livesync-bridge) via GHCR. No application code — only CI configuration, patches, and a fork submodule.

Two image variants are produced:
- **upstream**: clones `vrtmrz/livesync-bridge`, applies `patches/fix-deno-install.patch`, builds
- **patched**: builds directly from `./livesync-bridge` submodule (fork at `turtton/livesync-bridge`), no patches needed

## Build Commands

```sh
# Build patched variant locally (fork submodule)
docker build ./livesync-bridge

# Build upstream variant locally (simulates CI)
git clone https://github.com/vrtmrz/livesync-bridge.git src
git -C src apply patches/fix-deno-install.patch
docker build ./src
```

## Architecture

### CI Pipeline (`.github/workflows/build.yml`)

Two independent pipelines, each with check → build stages:

```
check-upstream → build-upstream   (upstream HEAD SHA via git ls-remote)
check-patched  → build-patched    (submodule SHA via git rev-parse)
```

Both skip builds when the SHA-tagged image already exists in GHCR (unless `workflow_dispatch`).

Triggers: `push` to `main`, daily cron at UTC 00:00, manual `workflow_dispatch`.

### Submodule

`livesync-bridge/` is a git submodule pointing to `turtton/livesync-bridge` (fork). It contains a nested submodule `lib/` → `vrtmrz/livesync-commonlib`. When checking out, use `--recurse-submodules`.

Changes to the patched variant go into the fork repo, not as patch files. After pushing changes to the fork, update the submodule reference in this repo.

### Patches

`patches/fix-deno-install.patch` is the only patch, applied to the upstream variant only. It fixes `deno install` for Deno 2.x compatibility (upstream PR [#33](https://github.com/vrtmrz/livesync-bridge/pull/33)).

## Key Conventions

- Image tags follow the pattern: `latest`/`<sha_short>`/`<YYYYMMDD>` for upstream, same with `-patched` suffix for patched variant
- `sha_short` = first 12 characters of the commit SHA
- GHCR registry: `ghcr.io/turtton/livesync-bridge`
