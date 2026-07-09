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

# ── Shared Aliases ──────────────────────────────────
[[ -f ~/.aliases ]] && . ~/.aliases
