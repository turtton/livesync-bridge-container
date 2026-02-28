# livesync-bridge-container

[vrtmrz/livesync-bridge](https://github.com/vrtmrz/livesync-bridge) の Docker イメージを自動ビルドし、GHCR で配信するリポジトリです。

[English](README.md)

## イメージの取得

```sh
docker pull ghcr.io/turtton/livesync-bridge:latest
```

### タグ

| タグ | 説明 |
|------|------|
| `latest` | 最新ビルド |
| `<commit-sha>` | 上流コミットSHAの先頭12文字 (例: `abc123def456`) |
| `<YYYYMMDD>` | ビルド日付 (例: `20260221`) |

## 使い方

設定ファイル (`config.json`) を用意し、以下のように実行します。設定の書き方は[上流リポジトリ](https://github.com/vrtmrz/livesync-bridge)を参照してください。

```yaml
# docker-compose.yml
services:
  bridge:
    image: ghcr.io/turtton/livesync-bridge:latest
    volumes:
      - ./dat:/app/dat   # config.json を配置
      - ./data:/app/data # 同期データの保存先
    restart: unless-stopped
```

```sh
docker compose up -d
```

## 上流との差分 (パッチ)

ビルド時に `patches/` ディレクトリ内のパッチを上流ソースに適用しています。上流でマージされたパッチは削除してください。

| パッチ | 対応PR | 内容 |
|--------|--------|------|
| `add-git.patch` | - | Docker イメージに `git` をインストール |
| `fix-deno-install.patch` | [#33](https://github.com/vrtmrz/livesync-bridge/pull/33) | `deno install -A` → `deno install -gA main.ts` (Deno 2.x ビルド修正) |

## 自動ビルドの仕組み

GitHub Actions が毎日 UTC 0:00 に上流リポジトリの最新コミットをチェックし、新しいコミットがあればイメージをビルドして GHCR に push します。同じコミットに対する重複ビルドはスキップされます。

手動でのリビルドは Actions タブの「Run workflow」から実行できます。
