# dotfiles

My dotfiles managed with git submodules.

## What's Included

| Config | Repo | Description |
|--------|------|-------------|
| Neovim | [dotfiles-nvim](https://github.com/LostmanMing/dotfiles-nvim) | Full Neovim IDE setup |
| Tmux | [dotfiles](https://github.com/LostmanMing/dotfiles) | Terminal multiplexer config |
| Lazygit | [dotfiles](https://github.com/LostmanMing/dotfiles) | Git TUI theme config |
| Claude Code | [dotfiles-claude](https://github.com/LostmanMing/dotfiles-claude) | AI assistant config |
| iTerm2 | [dotfiles](https://github.com/LostmanMing/dotfiles) | Terminal profile |
| Aerospace | [dotfiles](https://github.com/LostmanMing/dotfiles) | Tiling WM config |
| SketchyBar | [dotfiles](https://github.com/LostmanMing/dotfiles) | Status bar config |

## Installation

```bash
# Clone with all submodules
git clone --recurse-submodules git@github.com:LostmanMing/dotfiles.git ~/dotfiles

# Create symlinks
ln -s ~/dotfiles/.config/nvim ~/.config/nvim

# Start Neovim (first launch installs everything)
nvim
```

## Structure

```
~/dotfiles/
├── .config/
│   ├── nvim/       → LostmanMing/dotfiles-nvim (submodule)
│   ├── tmux/       → tmux config
│   ├── lazygit/    → lazygit theme
│   ├── aerospace/   → tiling WM
│   └── sketchybar/  → status bar
├── .claude/         → LostmanMing/dotfiles-claude (submodule)
├── iterm2/          → iTerm2 profile
├── .zshrc
├── .bashrc
├── .aliases
└── AGENTS.md
```

## How It Works

Each config app lives in its own git repo, added as a submodule under `.config/`. Symlinks from `~/.config/<app>` point into the dotfiles tree.

```
dotfiles/          ~/.config/
├── .config/      ├── nvim → ~/dotfiles/.config/nvim
│   └── nvim/  ←──┘
```

## Adding a New Config

```bash
cd ~/dotfiles
git submodule add <repo-url> .config/<app-name>
ln -s ~/dotfiles/.config/<app-name> ~/.config/<app-name>
git commit -m "feat: add <app-name> config"
```

## Updating All Submodules

```bash
cd ~/dotfiles
git submodule update --remote --merge
git commit -m "chore: update submodules"
```
