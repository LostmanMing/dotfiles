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
# 所有 cmake 构建自动生成 compile_commands.json（clangd 找头文件用，CMake ≥3.17）
export CMAKE_EXPORT_COMPILE_COMMANDS=1

# ── Shared Aliases ──────────────────────────────────
[[ -f ~/.aliases ]] && . ~/.aliases

# ── Startup ─────────────────────────────────────────
# 新开终端显示系统信息（未安装 fastfetch 的机器静默跳过）
command -v fastfetch >/dev/null && fastfetch
