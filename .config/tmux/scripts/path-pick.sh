#!/usr/bin/env bash
set -euo pipefail

dir="${0%/*}"; [ "$dir" = "$0" ] && dir=.
# shellcheck source=fzf-common.sh
source "$dir/fzf-common.sh"
fzf_require 0.59 "prefix+p" || exit 0
command -v rg >/dev/null 2>&1 || {
    tmux display-message "rg not found"
    exit 1
}

selection=$(
    tmux list-panes -F '#{pane_id}' |
        while IFS= read -r pane; do
            tmux capture-pane -pJ -t "$pane"
        done |
        tr '[:space:]' '\n' |
        rg -o '((~|\.)?/?[A-Za-z0-9._@%+=,~-]+(/[A-Za-z0-9._@%+=,~-]+)+)' |
        sed "s/[][(){}\"',.;:]*$//" |
        sort -u |
        fzf "${FZF_POPUP_LAYOUT[@]}" "${FZF_THEME[@]}" \
            --input-border=rounded --input-label=' 路径搜索 ' --input-label-pos=2 \
            --list-border=rounded --list-label=' 可见路径 ' --list-label-pos=2 \
            --prompt='❯ '
) || exit 0

[ -n "$selection" ] || exit 0
printf '%s' "$selection" | tmux load-buffer -w -
tmux display-message "已复制路径: $selection"
