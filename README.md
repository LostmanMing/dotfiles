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

# Install runtime-neutral agent skills (Qoder path shown as one example)
# For another agent host, link the same skill directories into its skill search path.
mkdir -p ~/.qoder/skills
ln -s ~/dotfiles/skills/develop-dotfiles ~/.qoder/skills/develop-dotfiles
ln -s ~/dotfiles/skills/develop-neovim ~/.qoder/skills/develop-neovim
ln -s ~/dotfiles/skills/develop-tmux ~/.qoder/skills/develop-tmux
ln -s ~/dotfiles/skills/keep-weekly-notes ~/.qoder/skills/keep-weekly-notes

# Start Neovim (first launch installs everything)
nvim
```

## Agent Skills

| Skill | Purpose |
|-------|---------|
| `/develop-dotfiles` | 总入口；协调根仓库、子模块和跨模块修改 |
| `/develop-neovim` | Neovim 插件、Lua、键位、LSP/DAP 与真实启动验证 |
| `/develop-tmux` | tmux 配置、脚本、popup、状态和隔离 server 验证 |
| `/keep-weekly-notes` | 将对话中的核心工作按主题整理为每周离线 HTML，并维护优化路线与最终决策 |

安装后运行 `/skills reload`，再用 `/skills list` 确认所需技能可用。总入口在任务涉及 Neovim 或 tmux 时会调用对应子 skill。

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
