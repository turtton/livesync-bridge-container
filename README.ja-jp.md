# livesync-bridge-container

[vrtmrz/livesync-bridge](https://github.com/vrtmrz/livesync-bridge) の Docker イメージを自動ビルドし、GHCR で配信するリポジトリです。

[English](README.md)

## イメージの取得

```sh
docker pull ghcr.io/turtton/livesync-bridge:latest
```

### イメージの種類

上流の各コミットに対して2種類のイメージをビルドしています:

| 種類 | タグ | 説明 |
|------|------|------|
| **upstream** | `latest`, `<sha>`, `<date>` | 上流 Dockerfile を Deno 2.x でビルドするための最小限の修正のみ (`fix-deno-install.patch`) |
| **patched** | `latest-patched`, `<sha>-patched`, `<date>-patched` | 全パッチ適用。依存関係を事前キャッシュし、起動時のダウンロードなしでコンテナが起動する |

### タグ

| タグ | 説明 |
|------|------|
| `latest` / `latest-patched` | 最新ビルド |
| `<commit-sha>` / `<commit-sha>-patched` | 上流コミットSHAの先頭12文字 (例: `abc123def456`) |
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

## 上流との差分 (パッチ)

ビルド時に `patches/` ディレクトリ内のパッチを上流ソースに適用しています。`fix-deno-install.patch` は両方のイメージに、それ以外は patched イメージのみに適用されます。上流にマージされたパッチは順次削除されます。

| パッチ | 対応PR | 適用先 | 内容 |
|--------|--------|--------|------|
| `fix-deno-install.patch` | [#33](https://github.com/vrtmrz/livesync-bridge/pull/33) | 両方 | `deno install -A` → `deno install -gA main.ts` (Deno 2.x ビルド修正) |
| `add-git.patch` | - | patched | Docker イメージに `git` と `ca-certificates` をインストール |
| `pre-cache-deps.patch` | - | patched | `deno install --entrypoint` で依存を事前キャッシュし、起動時のダウンロードを不要にする |

## 自動ビルドの仕組み

GitHub Actions が毎日 UTC 0:00 に上流リポジトリの最新コミットをチェックし、新しいコミットがあればイメージをビルドして GHCR に push します。同じコミットに対する重複ビルドはスキップされます。

手動でのリビルドは Actions タブの「Run workflow」から実行できます。
