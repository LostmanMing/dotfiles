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

本仓库只保存个人追加配置，不全量覆盖。使用时**追加**到本地已有配置：

```bash
# .zshrc / .bashrc 追加到本地
cat ~/dotfiles/.zshrc >> ~/.zshrc
cat ~/dotfiles/.bashrc >> ~/.bashrc

# .aliases 直接软链
ln -sf ~/dotfiles/.aliases ~/.aliases
```

---

## 3. Neovim

> 详见 `.config/nvim/README.md`

```bash
ln -sf ~/dotfiles/.config/nvim ~/.config/nvim
nvim  # 首次启动自动安装插件和 LSP
```

---

## 4. iTerm2 (macOS)

```bash
ln -sf ~/dotfiles/iterm2/iterm2.json \
  ~/Library/Application\ Support/iTerm2/DynamicProfiles/iterm2.json
```

---

## 5. Aerospace & SketchyBar (macOS)

```bash
ln -sf ~/dotfiles/.config/aerospace ~/.config/aerospace
ln -sf ~/dotfiles/.config/sketchybar ~/.config/sketchybar
bash ~/dotfiles/.config/install.sh
```

---

## 6. SSH

`~/.ssh/config` 手动管理，不包含在 dotfiles 中。

免密登录：
```bash
ssh-copy-id -i ~/.ssh/id_rsa.pub <host>
```
