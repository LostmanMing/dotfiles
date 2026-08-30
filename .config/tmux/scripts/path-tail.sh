#!/usr/bin/env bash
set -euo pipefail

path=${1:-}
[ -n "$path" ] || exit 0

case $path in
    "$HOME"*) path="~${path#"$HOME"}" ;;
esac

IFS=/ read -r -a parts <<< "$path"
count=${#parts[@]}
if (( count > 3 )); then
    tail_path="${parts[count-3]}/${parts[count-2]}/${parts[count-1]}"
else
    tail_path="$path"
fi

if (( ${#tail_path} > 24 )); then
    printf '..%s\n' "${tail_path: -21}"
else
    printf '%s\n' "$tail_path"
fi
