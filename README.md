# dotfiles

My dotfiles managed with git submodules.

## What's Included

| Config | Repo | Description |
|--------|------|-------------|
| Neovim | [dotfiles-nvim](https://github.com/LostmanMing/dotfiles-nvim) | Full Neovim IDE setup |
| Tmux | [dotfiles](https://github.com/LostmanMing/dotfiles) | Terminal multiplexer config |
| Lazygit | [dotfiles](https://github.com/LostmanMing/dotfiles) | Git TUI theme config |
| Claude Code | [dotfiles-claude](https://github.com/LostmanMing/dotfiles-claude) | AI assistant config |
| Agent Skills | [dotfiles](https://github.com/LostmanMing/dotfiles) | AI agent skills（`skills/`） |
| iTerm2 | [dotfiles](https://github.com/LostmanMing/dotfiles) | Terminal profile |
| Aerospace | [dotfiles](https://github.com/LostmanMing/dotfiles) | Tiling WM config |
| SketchyBar | [dotfiles](https://github.com/LostmanMing/dotfiles) | Status bar config |

## Installation

```bash
# Clone with all submodules
git clone --recurse-submodules git@github.com:LostmanMing/dotfiles.git ~/dotfiles

# Create config symlink
ln -s ~/dotfiles/.config/nvim ~/.config/nvim

# Install agent skills without replacing an existing ~/.qoder/skills directory
mkdir -p ~/.qoder/skills
ln -s ~/dotfiles/skills/develop-dotfiles ~/.qoder/skills/develop-dotfiles
ln -s ~/dotfiles/skills/develop-neovim ~/.qoder/skills/develop-neovim
ln -s ~/dotfiles/skills/develop-tmux ~/.qoder/skills/develop-tmux

# Start Neovim (first launch installs everything)
nvim
```

## Development Skills

| Skill | Purpose |
|-------|---------|
| `/develop-dotfiles` | 总入口；协调根仓库、子模块和跨模块修改 |
| `/develop-neovim` | Neovim 插件、Lua、键位、LSP/DAP 与真实启动验证 |
| `/develop-tmux` | tmux 配置、脚本、popup、状态和隔离 server 验证 |

安装后运行 `/skills reload`，再用 `/skills list` 确认三个技能可用。总入口在任务涉及 Neovim 或 tmux 时会调用对应子 skill。

## Structure

```
~/dotfiles/
├── .config/
│   ├── nvim/          → LostmanMing/dotfiles-nvim (submodule)
│   ├── tmux/          → tmux config
│   ├── clangd/        → clang-tidy 调整
│   ├── aerospace/     → tiling WM
│   ├── sketchybar/    → status bar
│   └── starship.toml  → prompt (bash/zsh 共用)
├── .claude/           → LostmanMing/dotfiles-claude (submodule)
├── skills/            → AI agent skills（软链到 ~/.qoder/skills/）
├── iterm2/            → iTerm2 profile
├── .zshrc
├── .zprofile
├── .bashrc
├── .aliases
├── .gitconfig         → git + delta（追加到本地）
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
