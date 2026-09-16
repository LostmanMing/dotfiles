#!/usr/bin/env bash
set -uo pipefail

usage() {
    cat <<'EOF'
Usage:
  bootstrap.sh --check
  bootstrap.sh --apply [--source-active-tmux]
  bootstrap.sh --help

--check               Inspect requirements, sources, and link collisions only.
--apply               Create missing links and verify tmux on a private socket.
--source-active-tmux  With --apply, also source the current tmux server.
EOF
}

MODE=""
SOURCE_ACTIVE_TMUX=0
for arg in "$@"; do
    case "$arg" in
        --check|--apply)
            if [[ -n "$MODE" ]]; then
                printf 'FAIL choose exactly one of --check or --apply\n' >&2
                exit 2
            fi
            MODE=${arg#--}
            ;;
        --source-active-tmux)
            SOURCE_ACTIVE_TMUX=1
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            printf 'FAIL unknown argument: %s\n' "$arg" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ -z "$MODE" ]]; then
    printf 'FAIL choose --check or --apply\n' >&2
    usage >&2
    exit 2
fi
if (( SOURCE_ACTIVE_TMUX )) && [[ "$MODE" != apply ]]; then
    printf 'FAIL --source-active-tmux requires --apply\n' >&2
    exit 2
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || exit 1
DOTFILES_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd -P) || exit 1
TMUX_SOURCE="$DOTFILES_ROOT/.config/tmux"
TMUX_CONFIG="$TMUX_SOURCE/tmux.conf"
NVIM_SUBMODULE="$DOTFILES_ROOT/.config/nvim"
NVIM_HTTPS_URL="https://github.com/LostmanMing/dotfiles-nvim.git"
CLAUDE_HTTPS_URL="https://github.com/LostmanMing/dotfiles-claude.git"
FAILURES=0
NVIM_SOURCE=""
NVIM_KIND=""
NVIM_NEEDS_INIT=0

ok() { printf 'OK %s\n' "$*"; }
plan() { printf 'PLAN %s\n' "$*"; }
warn() { printf 'WARN %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*" >&2; FAILURES=$((FAILURES + 1)); }

canonical_dir() {
    CDPATH= cd -- "$1" 2>/dev/null && pwd -P
}

check_version() {
    local label=$1 value=$2 minimum_major=$3 minimum_minor=$4
    if [[ "$value" =~ ([0-9]+)\.([0-9]+) ]]; then
        local major=${BASH_REMATCH[1]} minor=${BASH_REMATCH[2]}
        if (( major > minimum_major || (major == minimum_major && minor >= minimum_minor) )); then
            ok "$label $value"
            return 0
        fi
    fi
    fail "$label $value is too old; require >= ${minimum_major}.${minimum_minor}"
    return 1
}

is_expected_nvim_origin() {
    case "$1" in
        https://github.com/LostmanMing/dotfiles-nvim|https://github.com/LostmanMing/dotfiles-nvim.git|git@github.com:LostmanMing/dotfiles-nvim.git|ssh://git@github.com/LostmanMing/dotfiles-nvim.git)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

valid_nvim_worktree() {
    local path=$1 top origin canonical_path canonical_top
    [[ -d "$path" && -f "$path/init.lua" ]] || return 1
    top=$(git -C "$path" rev-parse --show-toplevel 2>/dev/null) || return 1
    canonical_path=$(canonical_dir "$path") || return 1
    canonical_top=$(canonical_dir "$top") || return 1
    [[ "$canonical_path" == "$canonical_top" ]] || return 1
    origin=$(git -C "$path" remote get-url origin 2>/dev/null) || return 1
    is_expected_nvim_origin "$origin"
}

report_nvim_state() {
    local path=$1 commit dirty
    commit=$(git -C "$path" rev-parse --short HEAD 2>/dev/null || true)
    if [[ -n "$commit" ]]; then
        ok "Neovim source: $path ($NVIM_KIND, commit $commit)"
    else
        warn "Neovim source has no commit yet: $path"
    fi
    dirty=$(git -C "$path" status --porcelain 2>/dev/null || true)
    if [[ -n "$dirty" ]]; then
        warn "Neovim source is dirty; it will be preserved unchanged"
    fi
}

select_nvim_source() {
    local standalone="$HOME/dotfiles-nvim" submodule_top submodule_real top_real
    NVIM_SOURCE=""
    NVIM_KIND=""
    NVIM_NEEDS_INIT=0

    if valid_nvim_worktree "$standalone"; then
        NVIM_SOURCE=$(canonical_dir "$standalone")
        NVIM_KIND="standalone"
        return 0
    fi
    if [[ -e "$standalone" || -L "$standalone" ]]; then
        warn "$standalone exists but is not a valid LostmanMing/dotfiles-nvim root worktree; ignoring it"
    fi

    if valid_nvim_worktree "$NVIM_SUBMODULE"; then
        NVIM_SOURCE=$(canonical_dir "$NVIM_SUBMODULE")
        NVIM_KIND="submodule"
        return 0
    fi

    submodule_top=$(git -C "$NVIM_SUBMODULE" rev-parse --show-toplevel 2>/dev/null || true)
    if [[ -n "$submodule_top" && -d "$NVIM_SUBMODULE" ]]; then
        submodule_real=$(canonical_dir "$NVIM_SUBMODULE" 2>/dev/null || true)
        top_real=$(canonical_dir "$submodule_top" 2>/dev/null || true)
        if [[ -n "$submodule_real" && "$submodule_real" == "$top_real" ]]; then
            fail "$NVIM_SUBMODULE is an initialized but invalid Neovim worktree; refusing to modify it"
            return 1
        fi
    fi
    if [[ -d "$NVIM_SUBMODULE" ]] && [[ -n "$(ls -A "$NVIM_SUBMODULE" 2>/dev/null)" ]]; then
        fail "$NVIM_SUBMODULE is non-empty but is not a valid Neovim worktree"
        return 1
    fi

    NVIM_SOURCE="$NVIM_SUBMODULE"
    NVIM_KIND="submodule"
    NVIM_NEEDS_INIT=1
    return 0
}

check_link() {
    local link=$1 expected=$2 label=$3 actual expected_real
    if [[ -L "$link" ]]; then
        if [[ ! -e "$link" ]]; then
            fail "$label link is dangling: $link -> $(readlink "$link")"
            return 1
        fi
        if [[ ! -d "$expected" ]]; then
            fail "$label expected target is not available: $expected"
            return 1
        fi
        actual=$(canonical_dir "$link") || return 1
        expected_real=$(canonical_dir "$expected") || return 1
        if [[ "$actual" == "$expected_real" ]]; then
            ok "$label link already correct: $link"
            return 0
        fi
        fail "$label link points elsewhere: $link -> $(readlink "$link")"
        return 1
    fi
    if [[ -e "$link" ]]; then
        fail "$label path already exists and will not be replaced: $link"
        return 1
    fi
    plan "create $label link: $link -> $expected"
}

create_link() {
    local link=$1 expected=$2 label=$3
    if [[ -L "$link" ]]; then
        ok "$label link unchanged: $link"
        return 0
    fi
    if ln -s "$expected" "$link"; then
        ok "$label link created: $link -> $expected"
        return 0
    fi
    fail "could not create $label link: $link"
    return 1
}

verify_private_tmux() {
    local temp socket prefix pass
    temp=$(mktemp -d "${TMPDIR:-/tmp}/bootstrap-dotfiles.XXXXXX") || {
        fail "could not create private tmux test directory"
        return 1
    }
    socket="$temp/tmux.sock"
    mkdir -p "$temp/home"
    pass=1

    if ! TMUX= HOME="$temp/home" tmux -S "$socket" -f "$TMUX_CONFIG" new-session -d -s bootstrap 'sleep 60' >/dev/null 2>&1; then
        fail "tmux configuration did not start on the private socket"
        pass=0
    fi
    if (( pass )); then
        for _ in 1 2; do
            if ! TMUX= HOME="$temp/home" tmux -S "$socket" source-file "$TMUX_CONFIG" >/dev/null 2>&1; then
                fail "tmux configuration could not be sourced twice on the private socket"
                pass=0
                break
            fi
        done
    fi
    if (( pass )); then
        prefix=$(TMUX= HOME="$temp/home" tmux -S "$socket" show-options -gv prefix 2>/dev/null || true)
        if [[ "$prefix" != C-z ]]; then
            fail "private tmux server prefix is '$prefix', expected C-z"
            pass=0
        fi
    fi

    TMUX= HOME="$temp/home" tmux -S "$socket" kill-server >/dev/null 2>&1 || true
    rm -rf -- "$temp"
    if (( pass )); then
        ok "tmux configuration loads repeatedly on a private socket with prefix=C-z"
        return 0
    fi
    return 1
}

source_active_tmux() {
    local prefix
    if [[ -z "${TMUX:-}" ]]; then
        fail "--source-active-tmux was requested, but TMUX is not set"
        return 1
    fi
    if ! tmux display-message -p '#{socket_path}' >/dev/null 2>&1; then
        fail "TMUX does not identify a reachable active server"
        return 1
    fi
    if ! tmux source-file "$TMUX_CONFIG"; then
        fail "could not source the active tmux server"
        return 1
    fi
    prefix=$(tmux show-options -gv prefix 2>/dev/null || true)
    if [[ "$prefix" != C-z ]]; then
        fail "active tmux server prefix is '$prefix', expected C-z"
        return 1
    fi
    ok "active tmux server sourced without restart; prefix=C-z"
}

if [[ -z "${HOME:-}" || "$HOME" != /* || ! -d "$HOME" ]]; then
    fail "HOME must be an existing absolute directory"
    printf 'FAIL preflight found %d blocking problem(s)\n' "$FAILURES" >&2
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    fail "git is required"
fi
if ! command -v tmux >/dev/null 2>&1; then
    fail "tmux >= 3.2 is required"
else
    tmux_output=$(tmux -V 2>/dev/null || true)
    check_version tmux "$tmux_output" 3 2 || true
fi
if ! command -v nvim >/dev/null 2>&1; then
    fail "Neovim >= 0.12 is required"
else
    nvim_output=$(nvim --version 2>/dev/null || true)
    nvim_first_line=${nvim_output%%$'\n'*}
    check_version Neovim "$nvim_first_line" 0 12 || true
fi
if ! command -v rg >/dev/null 2>&1; then
    warn "ripgrep is not installed; base activation can continue, but Neovim search will be limited"
fi

if command -v git >/dev/null 2>&1; then
    root_top=$(git -C "$DOTFILES_ROOT" rev-parse --show-toplevel 2>/dev/null || true)
    if [[ -z "$root_top" || "$(canonical_dir "$root_top" 2>/dev/null || true)" != "$DOTFILES_ROOT" ]]; then
        fail "$DOTFILES_ROOT is not the root of a Git worktree"
    else
        ok "dotfiles worktree: $DOTFILES_ROOT"
    fi

    nvim_module_url=$(git config --file "$DOTFILES_ROOT/.gitmodules" --get 'submodule..config/nvim.url' 2>/dev/null || true)
    claude_module_url=$(git config --file "$DOTFILES_ROOT/.gitmodules" --get 'submodule.claude.url' 2>/dev/null || true)
    [[ "$nvim_module_url" == "$NVIM_HTTPS_URL" ]] || fail ".config/nvim submodule URL must be $NVIM_HTTPS_URL"
    [[ "$claude_module_url" == "$CLAUDE_HTTPS_URL" ]] || fail ".claude submodule URL must be $CLAUDE_HTTPS_URL"
    if [[ "$nvim_module_url" == "$NVIM_HTTPS_URL" && "$claude_module_url" == "$CLAUDE_HTTPS_URL" ]]; then
        ok "public submodule URLs use HTTPS"
    fi

    gitlink=$(git -C "$DOTFILES_ROOT" ls-files --stage -- .config/nvim 2>/dev/null || true)
    [[ "$gitlink" == 160000\ * ]] || fail ".config/nvim is not recorded as a Git submodule"
fi

[[ -f "$TMUX_CONFIG" ]] || fail "tmux configuration is missing: $TMUX_CONFIG"

if (( FAILURES == 0 )); then
    select_nvim_source || true
fi
if [[ -n "$NVIM_SOURCE" && $NVIM_NEEDS_INIT -eq 0 ]]; then
    report_nvim_state "$NVIM_SOURCE"
elif [[ -n "$NVIM_SOURCE" ]]; then
    plan "initialize only pinned .config/nvim over HTTPS (non-recursive, non-remote)"
fi

CONFIG_HOME="$HOME/.config"
if [[ -n "$NVIM_SOURCE" ]]; then
    check_link "$CONFIG_HOME/tmux" "$TMUX_SOURCE" "tmux" || true
    check_link "$CONFIG_HOME/nvim" "$NVIM_SOURCE" "Neovim" || true
fi

if (( FAILURES > 0 )); then
    printf 'FAIL preflight found %d blocking problem(s)\n' "$FAILURES" >&2
    exit 1
fi

if [[ "$MODE" == check ]]; then
    if [[ -n "${TMUX:-}" ]]; then
        plan "active tmux server was not changed; rerun --apply --source-active-tmux after approval"
    else
        ok "no active tmux server will be touched"
    fi
    ok "check complete; no configuration links or submodules were changed"
    exit 0
fi

if ! mkdir -p "$CONFIG_HOME"; then
    fail "could not create $CONFIG_HOME"
    exit 1
fi

create_link "$CONFIG_HOME/tmux" "$TMUX_SOURCE" "tmux" || exit 1
verify_private_tmux || exit 1

if (( SOURCE_ACTIVE_TMUX )); then
    source_active_tmux || exit 1
elif [[ -n "${TMUX:-}" ]]; then
    warn "active tmux server was not sourced; rerun with --source-active-tmux only after approval"
else
    ok "no active tmux server was touched"
fi

if (( NVIM_NEEDS_INIT )); then
    if ! git -C "$DOTFILES_ROOT" -c "submodule..config/nvim.url=$NVIM_HTTPS_URL" submodule update --init --checkout -- .config/nvim; then
        fail "targeted Neovim submodule initialization failed"
        exit 1
    fi
    if ! valid_nvim_worktree "$NVIM_SUBMODULE"; then
        fail "initialized Neovim submodule failed worktree validation"
        exit 1
    fi
    NVIM_SOURCE=$(canonical_dir "$NVIM_SUBMODULE")
    ok "initialized pinned .config/nvim submodule over HTTPS"
fi

create_link "$CONFIG_HOME/nvim" "$NVIM_SOURCE" "Neovim" || exit 1
[[ -f "$CONFIG_HOME/nvim/init.lua" ]] || {
    fail "Neovim link does not expose init.lua"
    exit 1
}
report_nvim_state "$NVIM_SOURCE"
ok "Neovim binary was version-checked without starting the configuration"
warn "deferred: TPM, fzf/tldr, ruby, yazi, plugins, LSP/DAP, Claude, and shell extras"
ok "base dotfiles activation complete"
