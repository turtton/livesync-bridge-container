#!/bin/sh
set -eu

FILENAME="$1"
case "$(basename "$FILENAME")" in
    commit.md) ;;
    *) exit 0 ;;
esac

VAULT_DIR="${VAULT_DIR:?VAULT_DIR is not set}"
COMMIT_FILE="$VAULT_DIR/commit.md"
BRANCH="${GIT_BRANCH:-main}"
KUBE_NAMESPACE="$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace 2>/dev/null || echo default)"
KUBE_POD="$(hostname)"
GIT_ROOT="$(dirname "$VAULT_DIR")"
export GIT_DIR="$GIT_ROOT/.git"
export GIT_WORK_TREE="$VAULT_DIR"

DO_COMMIT=false
DO_PULL=false
if grep -q '^commit=true$' "$COMMIT_FILE" 2>/dev/null; then
    DO_COMMIT=true
fi
if grep -q '^pull=true$' "$COMMIT_FILE" 2>/dev/null; then
    DO_PULL=true
fi
if [ "$DO_COMMIT" = false ] && [ "$DO_PULL" = false ]; then
    exit 0
fi

ERROR_START='<!-- livesync-bridge git-error start -->'
ERROR_END='<!-- livesync-bridge git-error end -->'

clear_error_note() {
    if grep -Fqx "$ERROR_START" "$COMMIT_FILE" &&
       grep -Fqx "$ERROR_END" "$COMMIT_FILE"; then
        sed -i '/^<!-- livesync-bridge git-error start -->$/,/^<!-- livesync-bridge git-error end -->$/d' "$COMMIT_FILE"
    fi
}

report_failure() {
    STEP="$1"
    SUMMARY="$2"
    clear_error_note
    sed -i -e 's/^commit=true$/commit=false/' -e 's/^pull=true$/pull=false/' "$COMMIT_FILE"
    {
        if [ -n "$(tail -c 1 "$COMMIT_FILE")" ]; then
            printf '\n'
        fi
        printf '%s\n' "$ERROR_START"
        printf '## Git 同期エラー\n\n'
        printf -- '- 発生日時 (UTC): %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        printf -- '- 処理: %s\n' "$STEP"
        printf -- '- 状態: %s\n\n' "$SUMMARY"
        printf 'GitHub への同期は完了していません。Vault と Git の状態を確認してください。\n\n'
        printf '1. エラーの詳細を確認:\n'
        printf '       kubectl -n %s logs pod/%s --tail=100\n' "$KUBE_NAMESPACE" "$KUBE_POD"
        printf '2. Pod 内で Git の状態と未送信コミットを確認:\n'
        printf '       kubectl -n %s exec -it pod/%s -- sh\n' "$KUBE_NAMESPACE" "$KUBE_POD"
        printf '       export GIT_DIR=%s GIT_WORK_TREE=%s GIT_ASKPASS=/app/dat/script/git-askpass.sh\n' "$GIT_DIR" "$GIT_WORK_TREE"
        printf '       cd %s\n' "$VAULT_DIR"
        printf '       git status\n'
        printf '       git log --oneline --graph --decorate --all -10\n'
        printf '3. GitHub 側の変更と競合を確認して履歴を統合してください。強制 push はしないでください。\n'
        printf '   マージが途中で止まった場合は競合を解消して git add と git commit を行うか、\n'
        printf '   git merge --abort で中断します。共通祖先がない場合は両方の履歴を退避・比較してから\n'
        printf '   --allow-unrelated-histories を使って統合してください。\n'
        printf '4. 解決後、このファイルの commit=false を commit=true に変更して保存してください。\n'
        printf '   新しいファイル変更がなくても、未送信コミットの push を再試行します。\n'
        printf '%s\n' "$ERROR_END"
    } >> "$COMMIT_FILE"
    printf '[commit.sh] %s: %s\n' "$STEP" "$SUMMARY" >&2
}

cd "$VAULT_DIR"

if [ ! -d "$GIT_DIR" ]; then
    echo "[commit.sh] Initializing git repository..."
    git init -b "$BRANCH"
fi

git config user.name "${GIT_USER_NAME:-livesync-bridge}"
git config user.email "${GIT_USER_EMAIL:-livesync-bridge@localhost}"

REMOTE_URL="${GIT_REPO_URL:-}"
if [ -z "$REMOTE_URL" ]; then
    if ! git remote get-url origin >/dev/null 2>&1; then
        report_failure "remote" "GIT_REPO_URL が未設定で、origin もありません。"
        exit 1
    fi
else
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        export GIT_ASKPASS="/app/dat/script/git-askpass.sh"
        AUTH_URL="$(printf '%s\n' "$REMOTE_URL" | sed 's|https://|https://x-access-token@|')"
    else
        AUTH_URL="$REMOTE_URL"
    fi
    if git remote get-url origin >/dev/null 2>&1; then
        git remote set-url origin "$AUTH_URL"
    else
        git remote add origin "$AUTH_URL"
    fi
fi

if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
    report_failure "merge" "未完了のマージがあります。git status で競合を確認してください。"
    exit 1
fi

clear_error_note

if [ "$DO_PULL" = true ]; then
    echo "[commit.sh] pull=true detected, pulling remote changes..."
    sed -i 's/^pull=true$/pull=false/' "$COMMIT_FILE"
    if ! git fetch origin "$BRANCH"; then
        report_failure "pull/fetch" "GitHub からの fetch に失敗しました。"
        exit 1
    fi
    if git rev-parse HEAD >/dev/null 2>&1; then
        if ! git merge --no-edit --strategy-option=theirs "origin/$BRANCH"; then
            if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
                git merge --abort || echo "[commit.sh] Warning: merge --abort failed" >&2
            fi
            report_failure "pull/merge" "GitHub 側とのマージに失敗しました。git status を確認してください。"
            exit 1
        fi
    else
        if ! git reset --hard "origin/$BRANCH"; then
            report_failure "pull/reset" "GitHub 側の履歴の取得に失敗しました。"
            exit 1
        fi
    fi
    echo "[commit.sh] Pull complete"
fi

if [ "$DO_COMMIT" = true ]; then
    echo "[commit.sh] commit=true detected, starting commit..."
    sed -i 's/^commit=true$/commit=false/' "$COMMIT_FILE"
    if ! git add -A; then
        report_failure "commit/add" "変更のステージングに失敗しました。"
        exit 1
    fi
    if ! git diff --cached --quiet; then
        COMMIT_MSG="vault update: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        if ! git commit -m "$COMMIT_MSG"; then
            report_failure "commit" "ローカルコミットの作成に失敗しました。"
            exit 1
        fi
    else
        echo "[commit.sh] No new changes; checking for pending commits"
    fi

    echo "[commit.sh] Fetching remote before push..."
    if ! git fetch origin "$BRANCH"; then
        report_failure "push/fetch" "GitHub からの fetch に失敗しました。"
        exit 1
    fi
    if ! git merge --no-edit --strategy-option=ours "origin/$BRANCH"; then
        if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
            git merge --abort || echo "[commit.sh] Warning: merge --abort failed" >&2
        fi
        report_failure "push/merge" "GitHub 側とのマージに失敗しました。git status を確認してください。"
        exit 1
    fi
    if ! git push -u origin "$BRANCH"; then
        report_failure "push" "GitHub への push に失敗しました。"
        exit 1
    fi
    echo "[commit.sh] Push successful"
fi
