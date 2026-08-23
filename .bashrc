# ── History ─────────────────────────────────────────
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
shopt -s histappend
shopt -s cmdhist

# ── Shell Options ───────────────────────────────────
shopt -s checkwinsize
shopt -s globstar

# ── Colors ──────────────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'

# ── PATH ────────────────────────────────────────────
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# ── Env ─────────────────────────────────────────────
export EDITOR='nvim'
export VISUAL='nvim'

# 所有 cmake 构建自动生成 compile_commands.json（clangd 找头文件用，CMake ≥3.17）
export CMAKE_EXPORT_COMPILE_COMMANDS=1

# ── Colors ──────────────────────────────────────────
export LS_COLORS='di=38;5;75:ex=38;5;114:fi=0'
export EZA_COLORS='di=38;5;75:ex=38;5;114:fi=0:im=0:vi=0:mu=0:lo=0:cr=0:do=0:co=0:tm=0:cm=0:bu=0:sc=0:sp=0:da=38;5;244:sn=38;5;244:sb=38;5;244:uu=38;5;244:uR=38;5;244:un=38;5;244:gu=38;5;244:gR=38;5;244:gn=38;5;244:lc=38;5;244:lm=38;5;244:ur=38;5;179:uw=38;5;167:ux=38;5;143:ue=38;5;143:gr=38;5;179:gw=38;5;167:gx=38;5;143:tr=38;5;179:tw=38;5;167:tx=38;5;143:su=38;5;167:sf=38;5;167:xa=38;5;244:ga=38;5;244:gm=38;5;244:gd=38;5;244:gv=38;5;244:gt=38;5;244:gi=38;5;244:gc=38;5;244:hd=38;5;244:xx=38;5;244:lp=38;5;244:in=38;5;244:bl=38;5;244'

# ── Shared Aliases ──────────────────────────────────
[[ -f ~/.aliases ]] && . ~/.aliases

# ── Fuzzy Finder ────────────────────────────────────
if command -v batcat >/dev/null 2>&1; then
    export BAT_COMMAND='batcat'
elif command -v bat >/dev/null 2>&1; then
    export BAT_COMMAND='bat'
fi
export FZF_FILE_PREVIEW='if [ -d {} ]; then command tree -C -L 2 -- {}; elif [ -n "$BAT_COMMAND" ]; then file -- {}; "$BAT_COMMAND" --style=numbers --color=always --line-range :200 -- {}; else file -- {}; fi'
export FZF_COMPLETION_OPTS="--layout=reverse --preview '$FZF_FILE_PREVIEW' --preview-window=right:60%:wrap"
export FZF_CTRL_T_OPTS="--layout=reverse --preview '$FZF_FILE_PREVIEW' --preview-window=right:60%:wrap"
export FZF_ALT_C_OPTS="--layout=reverse --preview 'command tree -C -L 2 -- {}' --preview-window=right:60%:wrap"
export FZF_CTRL_R_OPTS="--layout=reverse --preview 'echo {}' --preview-window=right:60%:wrap"

# ── Completion ──────────────────────────────────────
[[ -r /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion
[[ ! -r ~/.local/share/blesh/ble.sh ]] && command -v fzf >/dev/null && eval "$(fzf --bash)"

# ── Directory Jumping ───────────────────────────────
command -v zoxide >/dev/null && eval "$(zoxide init bash)"

# ── Prompt ──────────────────────────────────────────
# starship 提示符（配置在 ~/.config/starship.toml）；未安装的机器用默认 PS1
command -v starship >/dev/null && eval "$(starship init bash)"

# ── Bash Line Editor ────────────────────────────────
[[ $- == *i* && -r ~/.local/share/blesh/ble.sh ]] && . ~/.local/share/blesh/ble.sh
