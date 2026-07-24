# AGENTS.md — LostmanMing dotfiles

本文件供 AI Agent 在配置环境时作为 Skill 参考。

**重要**: 不要一次性安装所有配置。先向用户列出可选配置清单，让用户自行选择需要哪些。每个配置独立安装，互不依赖。

---

## 1. Claude Code

### 配置清单

```
.claude/
├── settings.json              # 主配置（插件、主题）
├── settings.local.json        # 本地敏感配置（API key，不入 git）
├── CLAUDE.md                  # 自定义指令
├── providers/
│   ├── anthropic.json
│   ├── deepseek.json
│   └── qwen.json
├── integration.sh
├── integration-providers.sh
└── setup.sh                   # API Key 设置脚本
```

### 安装

```bash
cd ~/dotfiles && git submodule update --init --recursive
ln -sf ~/dotfiles/.claude ~/.claude
bash ~/.claude/setup.sh deepseek    # 输入 API Key
```

### Providers

| Provider | Model |
|----------|-------|
| `anthropic` | claude-sonnet-4-6 |
| `deepseek` | deepseek-v4-pro |
| `qwen` | qwen3-coder |

---

## 2. Shell

本仓库只保存个人追加配置，不全量覆盖。使用时**追加**到本地已有配置。

先确认当前终端类型（`echo $SHELL`），选择对应文件：

```bash
# Zsh 用户：追加 .zshrc
cat ~/dotfiles/.zshrc >> ~/.zshrc

# Bash 用户：追加 .bashrc
cat ~/dotfiles/.bashrc >> ~/.bashrc

# 通用别名（软链，bash/zsh 共用）
ln -sf ~/dotfiles/.aliases ~/.aliases
```

---

## 3. Neovim

> 详见 `.config/nvim/AGENTS.md`

```bash
ln -sf ~/dotfiles/.config/nvim ~/.config/nvim
nvim  # 首次启动自动安装插件和 LSP
```

## 4. Lazygit

主题 + 编辑行为配置，与 Neovim 联动：从 lazygit 打开文件会自动在宿主 nvim 中打开并触发 gitsigns diff。

```bash
ln -sf ~/dotfiles/.config/lazygit ~/.config/lazygit
```

## 5. Tmux

> 详见 `.config/tmux/README.md`

```bash
ln -sf ~/dotfiles/.config/tmux ~/.config/tmux
tmux source ~/.config/tmux/tmux.conf
```

Prefix: `Ctrl+z`，面板导航 `h/j/k/l`，分屏 `\`/`-`（对齐 nvim）。

---

## 6. clangd

用户级配置，关闭 clang-tidy 的命名风格检查（"invalid case style for variable ..."），其它检查保留。

```bash
ln -sf ~/dotfiles/.config/clangd ~/.config/clangd
```

---

## 7. iTerm2 (macOS)

```bash
ln -sf ~/dotfiles/iterm2/iterm2.json \
  ~/Library/Application\ Support/iTerm2/DynamicProfiles/iterm2.json
```

---

## 8. Aerospace & SketchyBar (macOS)

```bash
ln -sf ~/dotfiles/.config/aerospace ~/.config/aerospace
ln -sf ~/dotfiles/.config/sketchybar ~/.config/sketchybar
bash ~/dotfiles/.config/install.sh
```
