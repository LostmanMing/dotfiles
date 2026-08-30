#!/usr/bin/env bash

FZF_ONEDARK='fg:#abb2bf,fg+:#ffffff,bg:#21252b,bg+:#3e4451,hl:#61afef,hl+:#61afef,info:#61afef,marker:#98c379,prompt:#61afef,spinner:#e5c07b,pointer:#61afef,header:#e5c07b,border:#3e4451,label:#61afef,query:#abb2bf'
FZF_THEME=(--color="$FZF_ONEDARK")
FZF_POPUP_LAYOUT=(
    --height=100%
    --layout=reverse
    --margin=0
    --info=hidden
    --no-separator
    --gutter=' '
    --pointer='›'
)

fzf_require() {
    local minimum=$1 context=$2 current current_id minimum_id
    command -v fzf >/dev/null 2>&1 || {
        tmux display-message "$context 需要 fzf >= $minimum"
        return 1
    }

    current=$(fzf --version 2>/dev/null | awk '{print $1; exit}')
    current_id=$(awk -F. '{print ($1 + 0) * 1000000 + ($2 + 0) * 1000 + ($3 + 0)}' <<< "$current")
    minimum_id=$(awk -F. '{print ($1 + 0) * 1000000 + ($2 + 0) * 1000 + ($3 + 0)}' <<< "$minimum")
    if [ "${current_id:-0}" -lt "${minimum_id:-0}" ]; then
        tmux display-message "fzf $current 版本过低；$context 需要 >= $minimum"
        return 1
    fi

    export FZF_DEFAULT_OPTS=''
}
