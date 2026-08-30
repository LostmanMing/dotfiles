#!/usr/bin/env bash
set -euo pipefail

dir="${0%/*}"; [ "$dir" = "$0" ] && dir=.

if [ "${1:-}" = "--copy" ]; then
    line=${2-}
    line=${line%$'\r'}
    printf '%s' "$line" | tmux load-buffer -w - || true
    clipboard_cmd=$(tmux show-options -gqv @clipboard_cmd 2>/dev/null || true)
    if [ -n "$clipboard_cmd" ]; then
        printf '%s' "$line" | sh -c "$clipboard_cmd" || true
    fi
    exit 0
fi

command -v tldr >/dev/null 2>&1 || {
    tmux display-message "tldr 未安装"
    exit 1
}

if [ "${1:-}" = "--render" ]; then
    query=${2:-}
    read -r -a words <<< "$query"
    page=$(IFS=-; printf '%s' "${words[*]}")
    if [ -z "$page" ]; then
        printf '\033[38;5;244m输入命令后按 Enter 查询，例如：git stage、docker compose、tar\033[0m\n'
        exit 0
    fi
    tldr -- "$page" 2>&1 || true
    exit 0
fi

if [ "${1:-}" = "--jump" ]; then
    direction=${2:-next}
    query=${3:-}
    current=${4:-0}
    "$0" --render "$query" | awk -v direction="$direction" -v current="$current" '
        {
            line = $0
            gsub(/\033\[[0-9;]*[[:alpha:]]/, "", line)
            idx = NR - 1
            if (line ~ /^[[:space:]]*$/) {
                if (direction == "next" && idx > current) {
                    print "pos(" NR ")"
                    found = 1
                    exit
                }
                if (direction == "prev" && idx < current) previous = NR
            }
        }
        END {
            if (!found && direction == "prev" && previous) print "pos(" previous ")"
            else if (!found) print "ignore"
        }
    '
    exit 0
fi

# shellcheck source=fzf-common.sh
source "$dir/fzf-common.sh"
fzf_require 0.59 "prefix+?" || exit 0

cache_dir=${XDG_DATA_HOME:-$HOME/.local/share}/tldr/tldr
if [ ! -d "$cache_dir/pages" ]; then
    printf '首次使用，正在下载 tldr 页面缓存…\n'
    tldr --update
fi

script=${BASH_SOURCE[0]}
printf -v script_q '%q' "$script"

browse_keys='j,k,g,G,ctrl-d,ctrl-u,ctrl-b,ctrl-f,[,],y,a,i,q'
result_hint=' 结果 · j/k 移动 · [/] 分段 · g/G 首尾 · C-u/d 半页 · y 复制 · a/i 查询 · q/Esc 退出 '
to_result="reload-sync($script_q --render {q})+first+hide-input+unbind(enter)+rebind($browse_keys)+change-list-label($result_hint)"
to_query="show-input+change-query()+reload-sync($script_q --render '')+rebind(enter)+unbind($browse_keys)+change-list-label( 结果 )"
copy_line="execute-silent($script_q --copy {})+change-list-label( 已复制当前行 · j/k 移动 · [/] 分段 · a/i 查询 · q/Esc 退出 )"

"$script" --render '' | fzf \
    "${FZF_POPUP_LAYOUT[@]}" \
    "${FZF_THEME[@]}" \
    --disabled --no-sort --no-multi \
    --ansi --wrap=word --no-hscroll --no-scrollbar \
    --prompt='❯ ' \
    --input-border=rounded \
    --input-label=' 命令 · Enter 查询 · Esc 退出 ' \
    --input-label-pos=2 \
    --list-border=rounded \
    --list-label=' 结果 ' \
    --list-label-pos=2 \
    --bind="start:unbind($browse_keys)" \
    --bind="enter:$to_result" \
    --bind='j:down,k:up,g:first,G:last,ctrl-d:half-page-down,ctrl-u:half-page-up,ctrl-f:page-down,ctrl-b:page-up' \
    --bind="[:transform($script_q --jump prev {q} {n}),]:transform($script_q --jump next {q} {n})" \
    --bind="y:$copy_line" \
    --bind='q:abort,esc:abort' \
    --bind="a:$to_query" \
    --bind="i:$to_query"
