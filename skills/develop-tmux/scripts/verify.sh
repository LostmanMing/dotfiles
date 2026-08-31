#!/usr/bin/env bash
set -u

usage() {
    printf 'Usage: %s [--config PATH] [--interactive]\n' "$0"
}

source_path=${BASH_SOURCE[0]}
while [ -L "$source_path" ]; do
    source_dir=$(cd -P "$(dirname "$source_path")" >/dev/null 2>&1 && pwd)
    source_path=$(readlink "$source_path")
    [[ $source_path != /* ]] && source_path="$source_dir/$source_path"
done
script_dir=$(cd -P "$(dirname "$source_path")" >/dev/null 2>&1 && pwd)
root=$(cd "$script_dir/../../.." >/dev/null 2>&1 && pwd)
config="$root/.config/tmux/tmux.conf"
interactive=0

while [ "$#" -gt 0 ]; do
    case $1 in
        --config)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            config=$2
            shift 2
            ;;
        --interactive)
            interactive=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
done

[ -f "$config" ] || { printf 'FAIL  config not found: %s\n' "$config" >&2; exit 2; }
command -v tmux >/dev/null 2>&1 || { printf 'FAIL  tmux not found\n' >&2; exit 2; }
tmux_bin=$(command -v tmux)
config=$(cd "$(dirname "$config")" >/dev/null 2>&1 && printf '%s/%s' "$PWD" "$(basename "$config")")
config_dir=$(dirname "$config")

fail=0
mapfile -t shell_files < <(find "$config_dir/scripts" -maxdepth 1 -type f -name '*.sh' -print 2>/dev/null | sort)
for file in "${shell_files[@]}"; do
    if ! bash -n "$file"; then
        printf 'FAIL  shell syntax: %s\n' "$file"
        fail=1
    fi
done
[ "$fail" -eq 0 ] || exit 1
printf 'OK    shell syntax (%d scripts)\n' "${#shell_files[@]}"

tmp=$(mktemp -d)
socket="$tmp/tmux.sock"
home="$tmp/home"
mkdir -p "$home/.config" "$home/.tmux/plugins/tpm"
ln -s "$config_dir" "$home/.config/tmux"
printf '#!/usr/bin/env sh\nexit 0\n' > "$home/.tmux/plugins/tpm/tpm"
chmod +x "$home/.tmux/plugins/tpm/tpm"

cleanup() {
    HOME="$home" env -u TMUX "$tmux_bin" -S "$socket" kill-server 2>/dev/null || true
    rm -rf "$tmp"
}
trap cleanup EXIT INT TERM

tx() {
    HOME="$home" env -u TMUX "$tmux_bin" -S "$socket" "$@"
}

if ! tx -f /dev/null new-session -d -x 120 -y 40 -s verify 'while :; do sleep 3600; done'; then
    printf 'FAIL  could not start isolated tmux server\n' >&2
    exit 1
fi
if ! tx source-file "$config" || ! tx source-file "$config"; then
    printf 'FAIL  tmux configuration did not load twice\n' >&2
    exit 1
fi
printf 'OK    configuration loaded twice on isolated server %s\n' "$(tx display-message -p '#{version}')"

assert_equal() {
    local label=$1 expected=$2 actual=$3
    if [ "$actual" = "$expected" ]; then
        printf 'OK    %s=%s\n' "$label" "$actual"
    else
        printf 'FAIL  %s: expected %s, got %s\n' "$label" "$expected" "$actual"
        fail=1
    fi
}

assert_binding() {
    local key=$1 marker=$2 output
    output=$(tx list-keys -T prefix 2>/dev/null | awk -v key="$key" '$1 == "bind-key" && $2 == "-T" && $3 == "prefix" && $4 == key')
    if [[ $output == *"$marker"* ]]; then
        printf 'OK    prefix + %s\n' "$key"
    else
        printf 'FAIL  prefix + %s missing %s\n' "$key" "$marker"
        fail=1
    fi
}

assert_equal prefix C-z "$(tx show-options -gv prefix)"
assert_equal set-clipboard on "$(tx show-options -gv set-clipboard)"
assert_equal status-justify absolute-centre "$(tx show-options -gv status-justify)"
assert_binding R source-file
assert_binding c config-pick.sh
assert_binding f path-pick.sh
assert_binding p previous-window
assert_binding y yazi
assert_binding '?' tldr-popup.sh

features=$(tx show-options -gv terminal-features 2>/dev/null || true)
feature_count=$(printf '%s\n' "$features" | grep -Fo 'xterm*:RGB:usstyle' | wc -l | tr -d ' ')
assert_equal terminal-features-custom-count 1 "$feature_count"

if [ "$(tx display-message -p '#{>=:#{version},3.3}')" = 1 ]; then
    assert_equal popup-border-lines rounded "$(tx show-options -gv popup-border-lines)"
fi

for tool in fzf tldr nvim rg yazi ruby; do
    command -v "$tool" >/dev/null 2>&1 || printf 'WARN  optional command not found: %s\n' "$tool"
done

[ "$fail" -eq 0 ] || exit 1
printf 'PASS  isolated tmux verification\n'

if [ "$interactive" -eq 1 ]; then
    printf '\nInteractive checks: open the changed binding, exercise its normal/edge paths, resize, then detach with prefix+d.\n'
    tx attach-session -t verify
fi
