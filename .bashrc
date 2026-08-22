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

# ── Shared Aliases ──────────────────────────────────
[[ -f ~/.aliases ]] && . ~/.aliases

# ── Completion ──────────────────────────────────────
[[ -r /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion
[[ -r /usr/share/bash-completion/completions/fzf ]] && . /usr/share/bash-completion/completions/fzf

# ── Directory Jumping ───────────────────────────────
command -v zoxide >/dev/null && eval "$(zoxide init bash)"

# ── Prompt ──────────────────────────────────────────
# starship 提示符（配置在 ~/.config/starship.toml）；未安装的机器用默认 PS1
command -v starship >/dev/null && eval "$(starship init bash)"

# ── Bash Line Editor ────────────────────────────────
[[ $- == *i* && -r ~/.local/share/blesh/ble.sh ]] && . ~/.local/share/blesh/ble.sh
