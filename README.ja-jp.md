# livesync-bridge-container

[vrtmrz/livesync-bridge](https://github.com/vrtmrz/livesync-bridge) の Docker イメージを自動ビルドし、GHCR で配信するリポジトリです。

[English](README.md)

## イメージの取得

```sh
docker pull ghcr.io/turtton/livesync-bridge:latest
```

### イメージの種類

2種類のイメージを提供しています:

| 種類 | タグ | 説明 |
|------|------|------|
| **upstream** | `latest`, `<sha>`, `<date>` | 上流 Dockerfile を Deno 2.x でビルドするための最小限の修正のみ (`fix-deno-install.patch`) |
| **patched** | `latest-patched`, `<sha>-patched`, `<date>-patched` | [turtton/livesync-bridge](https://github.com/turtton/livesync-bridge) fork からビルド。依存関係を事前キャッシュし、起動時のダウンロードなしでコンテナが起動する |

### タグ

| タグ | 説明 |
|------|------|
| `latest` / `latest-patched` | 最新ビルド |
| `<commit-sha>` / `<commit-sha>-patched` | コミットSHAの先頭12文字 (`latest` は上流SHA、`latest-patched` は fork SHA) |
| `<YYYYMMDD>` / `<YYYYMMDD>-patched` | ビルド日付 (例: `20260221`) |

## 使い方

設定ファイル (`config.json`) を用意し、以下のように実行します。設定の書き方は[上流リポジトリ](https://github.com/vrtmrz/livesync-bridge)を参照してください。

```yaml
# docker-compose.yml
services:
  bridge:
    image: ghcr.io/turtton/livesync-bridge:latest-patched
    volumes:
      - ./dat:/app/dat   # config.json を配置
      - ./data:/app/data # 同期データの保存先
    restart: unless-stopped
```

```sh
docker compose up -d
```

## パッチ & Fork

**upstream** イメージは Deno 2.x 互換のため `fix-deno-install.patch` を上流ソースに適用してビルドしています。

**patched** イメージは [turtton/livesync-bridge](https://github.com/turtton/livesync-bridge) fork (git submodule として管理) から直接ビルドしています。追加の変更はパッチファイルではなく fork 側で管理することで、メンテナンス性を改善しています。

### Fork での変更内容

| 変更 | 内容 |
|------|------|
| Dockerfile の改善 | `git` と `ca-certificates` のインストール、`deno install --entrypoint` で依存を事前キャッシュ |
| PeerCouchDB レースコンディション修正 | `delete()`/`put()`/`get()`/`getMeta()` の先頭に `await this.man.ready.promise` を追加 |

### 上流に適用しているパッチ

| パッチ | 対応PR | 内容 |
|--------|--------|------|
| `fix-deno-install.patch` | [#33](https://github.com/vrtmrz/livesync-bridge/pull/33) | `deno install -A` → `deno install -gA main.ts` (Deno 2.x ビルド修正) |

## 自動ビルドの仕組み

GitHub Actions で2つの独立したビルドパイプラインを実行しています:

- **upstream**: 毎日 UTC 0:00 に上流リポジトリの最新コミットをチェックし、新しいコミットがあれば clone → `fix-deno-install.patch` 適用 → ビルド → GHCR に push します。
- **patched**: `main` ブランチへの push (submodule 更新時など) またはスケジュール/手動実行で発火します。fork submodule をビルドコンテキストとして直接使用し、パッチ適用は不要です。

いずれのパイプラインでも、同じコミットに対する重複ビルドはスキップされます。手動でのリビルドは Actions タブの「Run workflow」から実行できます。
