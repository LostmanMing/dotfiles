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

### 依赖

Ubuntu/Debian：

```bash
apt-get update
apt-get install -y bash-completion fzf zoxide gawk git make fd-find ripgrep bat file tree
```

Ubuntu 22.04 apt 没有 `eza`，需要先有 Cargo/Rust 工具链，再用 Cargo 安装：

```bash
cargo install eza --locked
cargo install vivid --locked
```

`vivid` 可用于手动生成 `LS_COLORS`，但当前配置不用 vivid 主题，避免文件名颜色过多；只区分目录、普通文件、可执行文件三类。`EZA_COLORS` 也保持低对比度，避免 `ll` 的 metadata 列太花。默认 vivid 主题列表里没有 `eva`。Ubuntu 的 `bat` 命令名是 `batcat`，`.aliases` 会自动把 `bat` 和 `cat` 映射到可用命令。

Bash 的现代输入体验依赖 `ble.sh`（自动建议、语法高亮、补全增强），需要单独下载安装：

```bash
mkdir -p ~/Codes/repos
git clone --depth 1 https://github.com/akinomyoga/ble.sh.git ~/Codes/repos/ble.sh
make -C ~/Codes/repos/ble.sh install PREFIX="$HOME/.local"
```

`.bashrc` 已写成条件加载：如果 `~/.local/share/blesh/ble.sh` 不存在，不会影响 Bash 启动。启用 `ble.sh` 时，fzf 的 `**<Tab>` 补全和快捷键必须通过 `~/.blerc` 里的 `ble-import -d integration/fzf-completion` / `fzf-key-bindings` 接入；不要在这种情况下直接 `eval "$(fzf --bash)"`，否则会被 `ble.sh` 接管后失效。

`zoxide` 只初始化 `z` 命令，不把 `cd` 强制替换成函数；如需智能跳转用 `z <关键词>`。Ubuntu 22.04 apt 里的 `zoxide 0.4.3` 不要用 `zoxide init bash --cmd cd`，会导致 `cd` 递归卡住。

### 安装

先确认当前终端类型（`echo $SHELL`），选择对应文件：

```bash
# Zsh 用户：追加 .zshrc
cat ~/dotfiles/.zshrc >> ~/.zshrc

# Bash 用户：追加 .bashrc
cat ~/dotfiles/.bashrc >> ~/.bashrc

# 通用别名（软链，bash/zsh 共用）
ln -sf ~/dotfiles/.aliases ~/.aliases

# ble.sh 配色（bash 自动建议/补全菜单，灰色主题）
ln -sf ~/dotfiles/.blerc ~/.blerc

# starship 提示符配置（bash/zsh 统一使用，p10k 已移除）
ln -sf ~/dotfiles/.config/starship.toml ~/.config/starship.toml
# 需安装 starship 二进制（未安装则自动回落默认 PS1）：
# 从 GitHub Release 下载 starship-x86_64-unknown-linux-gnu.tar.gz，
# 解压后 install starship /usr/local/bin/（网络差走 ghfast.top 镜像）
```

---

## 3. Git

本仓库只保存个人追加配置，不全量覆盖。**追加**到本地已有的 `~/.gitconfig`：

```bash
cat ~/dotfiles/.gitconfig >> ~/.gitconfig
```

有意不收录、留在各机器本地的两段：

| 段 | 原因 |
|----|------|
| `[user]` name / email | 每人每机不同 |
| `[http]` version | 特定网络环境的兼容开关，不该无条件套用 |

配置内容是 delta（语法高亮 diff、词级差异、双栏、双列行号）。需要装二进制：

```bash
cargo install git-delta        # 或从 GitHub Release 下 delta 二进制
```

**没装也不会坏**：`core.pager` 写的是 `delta || less -FRX`，delta 缺失时回落到 less。
不加这个回落的话，git spawn 分页器失败后会静默降级成直接写终端——`git log`
把全部提交一次性倾泻出来、屏幕停在最老那条，且 git 不报任何错误。

追加后用 `git config --show-origin --get core.pager` 复核是否生效。

---

## 4. Neovim

> 详见 `.config/nvim/AGENTS.md`

```bash
ln -sf ~/dotfiles/.config/nvim ~/.config/nvim
nvim  # 首次启动自动安装插件和 LSP
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
