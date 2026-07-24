# AGENTS.md — tmux

本文件供 AI Agent 配置 tmux 环境时参考。

**重要**: 先询问用户需要哪些插件/功能，按需安装对应依赖，不要一次性全装。

## Requirements

### 系统依赖

| 软件 | 用途 | 备注 |
|------|------|------|
| tmux >= 3.2 | 终端复用器 | 需 3.1+ 才读 `~/.config/tmux/tmux.conf`；状态栏 `#{!=:...}` 等格式比较需 3.2+ |
| Git | TPM 拉取插件 | 必须 |
| TPM | 插件管理器 | `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm` |
| 剪贴板工具 | 复制到系统剪贴板 | 启动时自动探测：mac 用 `pbcopy`，X11 用 `xclip`，WSL 用 `clip.exe` |

### 插件依赖（按需）

| 插件 | 依赖 | 说明 |
|------|------|------|
| tmux-thumbs | Rust / `cargo` | Rust 二进制，装完需 `cargo build --release` 构建 |
| tmux-jump | `ruby` | 跳转脚本用 ruby 运行，PATH 里必须有 `ruby` |
| tmux.nvim | Neovim | 与 nvim 侧的 `aserowy/tmux.nvim` 配合，实现 `Ctrl+hjkl` 无缝导航 |

### 版本过旧时的处理

部分系统仓库 tmux 太旧（< 3.2），状态栏格式和 XDG 配置路径会失效。优先 `tmux -V` 检查，不满足则源码编译或用较新包源：

- **tmux**: 源码编译（需 `libevent`、`ncurses`），或用发行版 backports
- **ruby**: `apt install ruby` / `brew install ruby`
- **cargo**: `curl https://sh.rustup.rs -sSf | sh`

## Installation

```bash
# 1. 软链配置（tmux 3.1+ 读 XDG 路径）
ln -sf ~/dotfiles/.config/tmux ~/.config/tmux

# 2. 装 TPM
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# 3. 加载配置
tmux source ~/.config/tmux/tmux.conf

# 4. 在 tmux 内按 prefix + I 拉取插件（prefix = Ctrl+z）

# 5. 构建 tmux-thumbs 的 Rust 二进制
cd ~/.tmux/plugins/tmux-thumbs && cargo build --release

# 6. 确保 ruby 在 PATH（tmux-jump 需要）
command -v ruby || echo "请先安装 ruby"
```

## 排错

- **tmux-jump 报 `returned 127`**：多为 `ruby` 未安装，或插件未 `prefix + I` 安装到 `~/.tmux/plugins/tmux-jump`。先 `command -v ruby` 和 `ls ~/.tmux/plugins/tmux-jump`。
- **插件未生效**：改完 `@plugin` 后要先 `tmux source`，再 `prefix + I`。
- **快捷键/配置改动**：`tmux source ~/.config/tmux/tmux.conf` 重载；部分选项（`set-clipboard`、`default-terminal`）对已存在 pane 不完全生效，可新开 pane 或 `tmux kill-server` 重启。

## 配置文档

用法、快捷键详见 `README.md`。
