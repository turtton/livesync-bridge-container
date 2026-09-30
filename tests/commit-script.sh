#!/bin/sh
set -eu

SCRIPT="$(CDPATH= cd -- "$(dirname "$0")/../chart/livesync-bridge/files" && pwd)/commit.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

local_git() {
    GIT_DIR="$CASE_DIR/vault/.git" GIT_WORK_TREE="$CASE_DIR/vault/private" git "$@"
}

setup_case() {
    CASE_DIR="$TEST_ROOT/$1"
    mkdir -p "$CASE_DIR/seed" "$CASE_DIR/vault/private"
    git init -q --bare "$CASE_DIR/remote.git"
    git init -q -b main "$CASE_DIR/seed"
    git -C "$CASE_DIR/seed" config user.name test
    git -C "$CASE_DIR/seed" config user.email test@example.invalid
    printf 'commit=false\npull=false\n' > "$CASE_DIR/seed/commit.md"
    printf 'remote content\n' > "$CASE_DIR/seed/note.md"
    git -C "$CASE_DIR/seed" add -A
    git -C "$CASE_DIR/seed" commit -qm "Remote initial snapshot"
    git -C "$CASE_DIR/seed" push -q "$CASE_DIR/remote.git" main
    GIT_DIR="$CASE_DIR/vault/.git" GIT_WORK_TREE="$CASE_DIR/vault/private" git init -q -b main
    local_git config user.name test
    local_git config user.email test@example.invalid
    local_git remote add origin "$CASE_DIR/remote.git"
}

run_script() {
    VAULT_DIR="$CASE_DIR/vault/private" GIT_REPO_URL="$CASE_DIR/remote.git" \
        GIT_BRANCH=main GIT_USER_NAME=test GIT_USER_EMAIL=test@example.invalid \
        sh "$SCRIPT" "$CASE_DIR/vault/private/commit.md" modified
}

remote_head() {
    git --git-dir="$CASE_DIR/remote.git" rev-parse refs/heads/main
}

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

# A retry must push a local commit even when commit.md returns to its tracked state.
setup_case pending-commit
local_git fetch -q origin main
local_git reset -q --hard origin/main
printf 'local update\n' > "$CASE_DIR/vault/private/note.md"
local_git add -A
local_git commit -qm "Local pending commit"
sed -i 's/^commit=false$/commit=true/' "$CASE_DIR/vault/private/commit.md"
run_script > "$CASE_DIR/run.log" 2>&1 || { cat "$CASE_DIR/run.log" >&2; fail "Pending commit was not pushed"; }
[ "$(remote_head)" = "$(local_git rev-parse HEAD)" ] || fail "Remote does not contain pending commit"
grep -q '^commit=false$' "$CASE_DIR/vault/private/commit.md" || fail "Commit flag was not reset"

# An unrelated history must stop before push and leave actionable guidance.
setup_case unrelated-history
printf 'commit=false\npull=false\nUser note stays here\n' > "$CASE_DIR/vault/private/commit.md"
printf 'local content\n' > "$CASE_DIR/vault/private/note.md"
local_git add -A
local_git commit -qm "Independent local root"
REMOTE_BEFORE="$(remote_head)"
sed -i 's/^commit=false$/commit=true/' "$CASE_DIR/vault/private/commit.md"
if run_script > "$CASE_DIR/run.log" 2>&1; then
    fail "Unrelated histories were silently accepted"
fi
[ "$(remote_head)" = "$REMOTE_BEFORE" ] || fail "Remote changed after failed merge"
grep -q '^commit=false$' "$CASE_DIR/vault/private/commit.md" || fail "Commit flag was not stopped"
grep -q 'Git 同期エラー' "$CASE_DIR/vault/private/commit.md" || fail "Recovery note was not written"
grep -q '強制 push はしない' "$CASE_DIR/vault/private/commit.md" || fail "Recovery guidance is missing"
grep -q 'User note stays here' "$CASE_DIR/vault/private/commit.md" || fail "Existing note was overwritten"
if local_git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
    fail "Failed merge was left in progress"
fi

# After the operator joins both histories, the same trigger clears the note and pushes.
local_git merge -q --allow-unrelated-histories -s ours -m "Join histories" refs/remotes/origin/main
sed -i 's/^commit=false$/commit=true/' "$CASE_DIR/vault/private/commit.md"
run_script > "$CASE_DIR/retry.log" 2>&1 || { cat "$CASE_DIR/retry.log" >&2; fail "Retry did not push"; }
[ "$(remote_head)" = "$(local_git rev-parse HEAD)" ] || fail "Remote did not advance after retry"
[ "$(local_git log -1 --format=%s)" = "Join histories" ] || fail "Retry created an unnecessary commit"
if grep -q 'livesync-bridge git-error' "$CASE_DIR/vault/private/commit.md"; then
    fail "Recovery note was not cleared"
fi


# The pull path must report the same history error rather than claim success.
setup_case unrelated-pull
printf 'commit=false\npull=false\n' > "$CASE_DIR/vault/private/commit.md"
printf 'local content\n' > "$CASE_DIR/vault/private/note.md"
local_git add -A
local_git commit -qm "Independent local root"
REMOTE_BEFORE="$(remote_head)"
sed -i 's/^pull=false$/pull=true/' "$CASE_DIR/vault/private/commit.md"
if run_script > "$CASE_DIR/pull.log" 2>&1; then
    fail "Unrelated pull was silently accepted"
fi
[ "$(remote_head)" = "$REMOTE_BEFORE" ] || fail "Remote changed after failed pull"
grep -q '^pull=false$' "$CASE_DIR/vault/private/commit.md" || fail "Pull flag was not stopped"
grep -q 'Git 同期エラー' "$CASE_DIR/vault/private/commit.md" || fail "Pull recovery note was not written"

printf '%s\n' "commit.sh integration tests passed"
