#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
BOOTSTRAP="$SCRIPT_DIR/bootstrap.sh"
DOTFILES_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd -P)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/verify-bootstrap-dotfiles.XXXXXX")
SENTINEL_SOCKET="$TMP/sentinel.sock"
ACTIVE_SOCKET="$TMP/active.sock"

cleanup() {
    TMUX= tmux -S "$SENTINEL_SOCKET" kill-server >/dev/null 2>&1 || true
    TMUX= tmux -S "$ACTIVE_SOCKET" kill-server >/dev/null 2>&1 || true
    rm -rf -- "$TMP"
}
trap cleanup EXIT

fail() {
    printf 'FAIL %s\n' "$*" >&2
    exit 1
}

pass() {
    printf 'OK %s\n' "$*"
}

same_dir() {
    local left right
    left=$(CDPATH= cd -- "$1" 2>/dev/null && pwd -P) || return 1
    right=$(CDPATH= cd -- "$2" 2>/dev/null && pwd -P) || return 1
    [[ "$left" == "$right" ]]
}

make_home() {
    local home=$1 repo="$1/dotfiles-nvim"
    mkdir -p "$repo"
    git -C "$repo" init -q
    git -C "$repo" remote add origin https://github.com/LostmanMing/dotfiles-nvim.git
    printf '%s\n' 'require("config.options")' > "$repo/init.lua"
}

expect_apply_failure() {
    local home=$1 label=$2
    if HOME="$home" TMUX= "$BOOTSTRAP" --apply >"$TMP/$label.out" 2>&1; then
        fail "$label collision was accepted"
    fi
}

command -v git >/dev/null 2>&1 || fail "git is required for verification"
command -v tmux >/dev/null 2>&1 || fail "tmux is required for verification"
command -v nvim >/dev/null 2>&1 || fail "nvim is required for verification"

bash -n "$BOOTSTRAP"
bash -n "$0"
pass "shell syntax"

if HOME= TMUX= "$BOOTSTRAP" --check >"$TMP/invalid-home.out" 2>&1; then
    fail "empty HOME was accepted"
fi
grep -Fq 'HOME must be an existing absolute directory' "$TMP/invalid-home.out" || fail "empty HOME failure was unclear"
pass "invalid HOME is rejected before activation"

MAIN_HOME="$TMP/main-home"
make_home "$MAIN_HOME"
HOME="$MAIN_HOME" TMUX= "$BOOTSTRAP" --check >"$TMP/check.out"
[[ ! -e "$MAIN_HOME/.config" ]] || fail "--check wrote ~/.config"
[[ ! -e "$MAIN_HOME/.local/share/nvim" ]] || fail "--check started Neovim"
pass "check mode is read-only"

PENDING_ROOT="$TMP/pending-root"
PENDING_HOME="$TMP/pending-home"
mkdir -p "$PENDING_ROOT/skills/bootstrap-dotfiles/scripts" "$PENDING_ROOT/.config/tmux" "$PENDING_ROOT/.config/nvim" "$PENDING_HOME"
cp "$BOOTSTRAP" "$PENDING_ROOT/skills/bootstrap-dotfiles/scripts/bootstrap.sh"
printf '%s\n' 'set -g prefix C-z' > "$PENDING_ROOT/.config/tmux/tmux.conf"
printf '%s\n' \
    '[submodule ".config/nvim"]' \
    $'\tpath = .config/nvim' \
    $'\turl = https://github.com/LostmanMing/dotfiles-nvim.git' \
    '[submodule "claude"]' \
    $'\tpath = .claude' \
    $'\turl = https://github.com/LostmanMing/dotfiles-claude.git' > "$PENDING_ROOT/.gitmodules"
git -C "$PENDING_ROOT" init -q
git -C "$PENDING_ROOT" config user.name bootstrap-test
git -C "$PENDING_ROOT" config user.email bootstrap-test@example.invalid
git -C "$PENDING_ROOT" add .gitmodules .config/tmux/tmux.conf skills/bootstrap-dotfiles/scripts/bootstrap.sh
git -C "$PENDING_ROOT" commit -qm base
pending_gitlink=$(git -C "$PENDING_ROOT" rev-parse HEAD)
git -C "$PENDING_ROOT" update-index --add --cacheinfo "160000,$pending_gitlink,.config/nvim"
git -C "$PENDING_ROOT" commit -qm gitlink
HOME="$PENDING_HOME" TMUX= "$PENDING_ROOT/skills/bootstrap-dotfiles/scripts/bootstrap.sh" --check >"$TMP/pending-check.out"
grep -Fq 'PLAN initialize only pinned .config/nvim over HTTPS' "$TMP/pending-check.out" || fail "uninitialized submodule was not planned"
[[ ! -e "$PENDING_HOME/.config" ]] || fail "pending submodule check wrote ~/.config"
pass "empty uninitialized submodule is recognized without mutation"

mkdir -p "$TMP/sentinel-home"
TMUX= HOME="$TMP/sentinel-home" tmux -S "$SENTINEL_SOCKET" -f /dev/null new-session -d -s sentinel 'sleep 120'
TMUX= HOME="$TMP/sentinel-home" tmux -S "$SENTINEL_SOCKET" set-option -g @bootstrap_sentinel alive

HOME="$MAIN_HOME" TMUX= "$BOOTSTRAP" --apply >"$TMP/apply.out"
same_dir "$MAIN_HOME/.config/tmux" "$DOTFILES_ROOT/.config/tmux" || fail "tmux link target is wrong"
same_dir "$MAIN_HOME/.config/nvim" "$MAIN_HOME/dotfiles-nvim" || fail "Neovim link target is wrong"
[[ "$(TMUX= HOME="$TMP/sentinel-home" tmux -S "$SENTINEL_SOCKET" show-option -gv @bootstrap_sentinel)" == alive ]] || fail "sentinel tmux server was changed"
[[ ! -e "$MAIN_HOME/.local/share/nvim" ]] || fail "apply started Neovim or created plugin data"
pass "apply creates links without touching another tmux server or Neovim data"

HOME="$MAIN_HOME" TMUX= "$BOOTSTRAP" --apply >"$TMP/apply-again.out"
same_dir "$MAIN_HOME/.config/tmux" "$DOTFILES_ROOT/.config/tmux" || fail "repeat apply changed tmux link"
same_dir "$MAIN_HOME/.config/nvim" "$MAIN_HOME/dotfiles-nvim" || fail "repeat apply changed Neovim link"
pass "apply is idempotent"

WRONG_HOME="$TMP/wrong-home"
make_home "$WRONG_HOME"
mkdir -p "$WRONG_HOME/.config" "$WRONG_HOME/other-tmux"
ln -s "$WRONG_HOME/other-tmux" "$WRONG_HOME/.config/tmux"
wrong_before=$(readlink "$WRONG_HOME/.config/tmux")
expect_apply_failure "$WRONG_HOME" wrong-link
[[ "$(readlink "$WRONG_HOME/.config/tmux")" == "$wrong_before" ]] || fail "wrong symlink was overwritten"
pass "wrong symlink collision is preserved"

DANGLING_HOME="$TMP/dangling-home"
make_home "$DANGLING_HOME"
mkdir -p "$DANGLING_HOME/.config"
ln -s "$DANGLING_HOME/missing-nvim" "$DANGLING_HOME/.config/nvim"
dangling_before=$(readlink "$DANGLING_HOME/.config/nvim")
expect_apply_failure "$DANGLING_HOME" dangling-link
[[ -L "$DANGLING_HOME/.config/nvim" && "$(readlink "$DANGLING_HOME/.config/nvim")" == "$dangling_before" ]] || fail "dangling symlink was overwritten"
pass "dangling symlink collision is preserved"

FILE_HOME="$TMP/file-home"
make_home "$FILE_HOME"
mkdir -p "$FILE_HOME/.config"
printf '%s\n' keep > "$FILE_HOME/.config/tmux"
expect_apply_failure "$FILE_HOME" real-file
[[ "$(<"$FILE_HOME/.config/tmux")" == keep ]] || fail "real file collision was overwritten"
pass "real file collision is preserved"

DIR_HOME="$TMP/dir-home"
make_home "$DIR_HOME"
mkdir -p "$DIR_HOME/.config/nvim"
printf '%s\n' keep > "$DIR_HOME/.config/nvim/marker"
expect_apply_failure "$DIR_HOME" real-directory
[[ "$(<"$DIR_HOME/.config/nvim/marker")" == keep ]] || fail "real directory collision was overwritten"
pass "real directory collision is preserved"

TMUX= HOME="$MAIN_HOME" tmux -S "$ACTIVE_SOCKET" -f /dev/null new-session -d -s active 'sleep 120'
[[ "$(TMUX= HOME="$MAIN_HOME" tmux -S "$ACTIVE_SOCKET" show-options -gv prefix)" == C-b ]] || fail "active fixture did not start with C-b"

ACTIVE_TMUX_ENV="$ACTIVE_SOCKET,0,0"
HOME="$MAIN_HOME" TMUX="$ACTIVE_TMUX_ENV" "$BOOTSTRAP" --apply >"$TMP/active-unapproved.out"
[[ "$(TMUX= HOME="$MAIN_HOME" tmux -S "$ACTIVE_SOCKET" show-options -gv prefix)" == C-b ]] || fail "active server was sourced without authorization"
pass "active tmux server is unchanged without explicit authorization"

HOME="$MAIN_HOME" TMUX="$ACTIVE_TMUX_ENV" "$BOOTSTRAP" --apply --source-active-tmux >"$TMP/active-approved.out"
[[ "$(TMUX= HOME="$MAIN_HOME" tmux -S "$ACTIVE_SOCKET" show-options -gv prefix)" == C-z ]] || fail "authorized active server was not sourced"
pass "explicit authorization sources active tmux with prefix=C-z"

[[ ! -e "$MAIN_HOME/.local/share/nvim" ]] || fail "verification created Neovim plugin data"
pass "bootstrap never launches configured Neovim"
printf 'OK bootstrap-dotfiles verification passed\n'
