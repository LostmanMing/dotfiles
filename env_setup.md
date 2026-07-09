# Environment Setup Guide

本指南用于在新机器上从零配置开发环境。也作为 AI Skill 参考，AI 可以按照本文自动执行环境配置。

---

## 1. Claude Code

### 1.1 前置条件

- Node.js >= 18
- Claude Code CLI 已安装（`claude` 命令可用）

### 1.2 配置清单

dotfiles 仓库中 `.claude/` 目录包含完整 Claude Code 配置：

```
.claude/
├── settings.json              # 主配置（hooks、插件、主题）
├── settings.local.json        # 本地敏感配置（API key，不入 git）
├── CLAUDE.md                  # 自定义指令（每次会话注入）
├── providers/
│   ├── anthropic.json         # Anthropic 官方 API
│   ├── deepseek.json          # DeepSeek API
│   └── qwen.json              # 通义千问 API
├── integration.sh             # Claude Code 集成环境变量
├── integration-providers.sh   # 第三方 Provider 配置
└── setup.sh                   # API Key 设置脚本
```

### 1.3 安装步骤

```bash
# 1. 拉取子模块
cd ~/dotfiles && git submodule update --init --recursive

# 2. 创建 Claude 配置软链
ln -sf ~/dotfiles/.claude ~/.claude

# 3. 设置 API Key（以 deepseek 为例）
bash ~/.claude/setup.sh deepseek
# 输入 API Key

# 4. 验证
claude --version
```

### 1.4 Providers

内置三个 Provider 配置模板，通过 `setup.sh` 激活：

| Provider | Model | URL |
|----------|-------|-----|
| `anthropic` | claude-sonnet-4-6 | api.anthropic.com |
| `deepseek` | deepseek-v4-pro | api.deepseek.com |
| `qwen` | qwen3-coder | dashscope.aliyuncs.com |

---

## 2. Shell

本仓库只保存个人追加配置，不全量覆盖。使用时**追加**到本地已有配置：

```bash
# .zshrc / .bashrc 包含个人 + 通用部分，追加到本地
cat ~/dotfiles/.zshrc >> ~/.zshrc
cat ~/dotfiles/.bashrc >> ~/.bashrc

# .aliases 
ln -sf ~/dotfiles/.aliases ~/.aliases
```

> `.zshrc`: Oh My Zsh + p10k + znap + source aliases  
> `.bashrc`: history + colors + source aliases  
> `.aliases`: 通用 git/shell 别名（bash/zsh 共享）

### 2.3 别名

所有别名在 `.aliases` 中，以 git 操作为主（`gs`、`ga`、`gc`、`gp`、`gl` 等），详见文件内注释。

---

## 3. Neovim

> 详见 `.config/nvim/README.md`

```bash
ln -sf ~/dotfiles/.config/nvim ~/.config/nvim
nvim  # 首次启动自动安装插件和 LSP
```

---

## 4. iTerm2

> 配置文件: `iterm2/iterm2.json`

```bash
ln -sf ~/dotfiles/iterm2/iterm2.json \
  ~/Library/Application\ Support/iTerm2/DynamicProfiles/iterm2.json
```

重启 iTerm2，Profiles 菜单中出现 `iterm2` 配置（AtomOneDark 暗色主题 + JetBrainsMono 字体 + 15% 透明度）。

---

## 5. Aerospace & SketchyBar

> 详见各自的 README

```bash
ln -sf ~/dotfiles/.config/aerospace ~/.config/aerospace
ln -sf ~/dotfiles/.config/sketchybar ~/.config/sketchybar
```

依赖安装: `bash ~/dotfiles/.config/install.sh`

---

## 6. SSH

### 6.1 配置

SSH 别名在 `~/.ssh/config` 中手动管理，dotfiles 不包含私有 IP。

常用别名示例：

```
Host ali
    HostName <your-server-ip>
    User admin
```

### 6.2 免密登录

```bash
ssh-copy-id -i ~/.ssh/id_rsa.pub ali
```

---

## 7. 完整安装脚本（新机器一键）

```bash
# 1. 拉取子模块
cd ~/dotfiles && git submodule update --init --recursive

# 2. Shell
cat ~/dotfiles/.zshrc >> ~/.zshrc
cat ~/dotfiles/.bashrc >> ~/.bashrc
ln -sf ~/dotfiles/.aliases ~/.aliases

# 3. Configs
ln -sf ~/dotfiles/.config/nvim ~/.config/nvim
ln -sf ~/dotfiles/.config/aerospace ~/.config/aerospace
ln -sf ~/dotfiles/.config/sketchybar ~/.config/sketchybar

# 4. Claude Code
ln -sf ~/dotfiles/.claude ~/.claude
bash ~/.claude/setup.sh deepseek

# 5. iTerm2 (macOS only)
ln -sf ~/dotfiles/iterm2/iterm2.json \
  ~/Library/Application\ Support/iTerm2/DynamicProfiles/iterm2.json

# 6. Reload
source ~/.zshrc
```
