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

Clone only the root repository over HTTPS; do not start with recursive submodules:

```bash
git clone https://github.com/LostmanMing/dotfiles.git ~/dotfiles
```

Use `/bootstrap-dotfiles` to activate a minimum usable tmux + Neovim environment. For Qoder, link the skill into its search path and reload skills:

```bash
mkdir -p ~/.qoder/skills
ln -s ~/dotfiles/skills/bootstrap-dotfiles ~/.qoder/skills/bootstrap-dotfiles
```

Then run `/skills reload` followed by `/bootstrap-dotfiles`. Other agent hosts can link the same directory into their own skill search path.

Without a skill host, run the bundled implementation directly:

```bash
~/dotfiles/skills/bootstrap-dotfiles/scripts/bootstrap.sh --check
~/dotfiles/skills/bootstrap-dotfiles/scripts/bootstrap.sh --apply
```

The bootstrap reuses a valid `~/dotfiles-nvim`, otherwise initializes only the pinned `.config/nvim` submodule over HTTPS. It refuses link collisions, validates tmux on a private socket, and does not launch Neovim or install plugins. Sourcing an active tmux server requires the explicit `--source-active-tmux` option.

After the base environment works, add only the components you want: TPM, fzf/tldr, ruby, yazi, shell extras, DAP tools, Claude configuration, or the remaining agent skills.

```bash
# Qoder examples for additional runtime-neutral skills
ln -s ~/dotfiles/skills/develop-dotfiles ~/.qoder/skills/develop-dotfiles
ln -s ~/dotfiles/skills/develop-neovim ~/.qoder/skills/develop-neovim
ln -s ~/dotfiles/skills/develop-tmux ~/.qoder/skills/develop-tmux
ln -s ~/dotfiles/skills/keep-weekly-notes ~/.qoder/skills/keep-weekly-notes
```

## Agent Skills

| Skill | Purpose |
|-------|---------|
| `/bootstrap-dotfiles` | 空机器或 clone 后安全激活最小可用 tmux + Neovim，不覆盖已有配置 |
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

Some configs live directly in this root repo; Neovim and Claude are submodules. On fresh machines, Neovim may also be linked directly from an existing `~/dotfiles-nvim` checkout instead of initializing the submodule immediately. Symlinks from `~/.config/<app>` point to whichever checked-out config you choose.

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

## Updating Submodules

```bash
cd ~/dotfiles

# Preferred: update only the component you are working on.
git submodule update --remote --merge .config/nvim
# or:
git submodule update --remote --merge .claude

# Only when intentionally updating everything:
git submodule update --remote --merge
git commit -m "chore: update submodules"
```
