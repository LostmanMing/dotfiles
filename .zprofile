
export HOMEBREW_PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple #ckbrew
export HOMEBREW_API_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api  #ckbrew
export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles #ckbrew
eval $(/opt/homebrew/bin/brew shellenv) #ckbrew

# ── SSH session: unlock keychain + clean stale Claude locks ──
if [ -n "$SSH_CONNECTION" ]; then
  # Unlock login keychain (needed for Claude Code auth)
  security unlock-keychain ~/Library/Keychains/login.keychain-db 2>/dev/null
  # Clean stale shell-snapshot locks from previous crashed sessions
  rm -f ~/.claude/shell-snapshots/*.lock 2>/dev/null
  # Clean stale update locks
  rm -rf ~/.local/state/claude/locks/ 2>/dev/null
fi
