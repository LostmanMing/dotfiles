---
name: bootstrap-dotfiles
description: Safely activate the minimum usable tmux and Neovim setup after cloning this dotfiles repository. Use on fresh machines, after clone, when tmux prefix bindings are not active, when reusing ~/dotfiles-nvim, or when recursive SSH submodules are slow or blocked.
argument-hint: [check or activate the base environment]
---

# Bootstrap Dotfiles

Activate tmux and Neovim without overwriting existing configuration or installing optional plugins.

## Workflow

1. Run `<SKILL_DIR>/scripts/bootstrap.sh --check`.
2. If `git`, tmux, or Neovim is missing or below the required version, report the exact gap and ask before installing packages or downloading binaries.
   - Accept tmux >= 3.2a for the base configuration; the standard install target is tmux 3.8 (build from the `release_3.8` branch — steps in `.config/tmux/AGENTS.md`). tmux 3.3+ only improves popup styling.
   - Require Neovim >= 0.12. On Ubuntu systems with an older package, install a versioned upstream build under `~/.local/opt` and link its executable into `~/.local/bin`; do not replace the system binary.
   - Treat ripgrep, TPM, fzf, tldr, ruby, yazi, tree-sitter-cli, LSP/DAP tools, Claude configuration, and shell decoration as optional follow-up work.
3. Resolve every reported collision before activation. Never overwrite, move, or delete an existing link, file, or directory on the user's behalf.
4. After `--check` passes, run `<SKILL_DIR>/scripts/bootstrap.sh --apply`.
5. If the user is currently inside tmux, ask whether to reload that active server. Explain that `--source-active-tmux` only sources the configuration and verifies `prefix=C-z`; it does not restart or kill the server. Add the flag only after approval.
6. Report which Neovim checkout was selected and whether the active tmux server was sourced.
7. Offer optional components only after the base activation succeeds, and install only what the user chooses.

## Safety Rules

- Use the bundled script instead of handwritten symlink or blanket submodule commands.
- Never start with recursive submodule initialization. The script may initialize only `.config/nvim`, pinned to the root repository's recorded commit, over HTTPS.
- Prefer a valid `~/dotfiles-nvim` worktree. Preserve its branch, commit, dirty state, and remote configuration.
- Never fetch, pull, reset, clean, or check out an existing worktree.
- Never change global Git configuration.
- Never launch configured Neovim during base activation; doing so may bootstrap plugins.
- Never source or kill an active tmux server unless the user explicitly approved `--source-active-tmux`.

## Commands

```bash
# Inspect only; no links or submodules are changed.
<SKILL_DIR>/scripts/bootstrap.sh --check

# Create missing safe links and verify with a private tmux socket.
<SKILL_DIR>/scripts/bootstrap.sh --apply

# Explicitly also source the current tmux server.
<SKILL_DIR>/scripts/bootstrap.sh --apply --source-active-tmux
```
