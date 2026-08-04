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
| vim-tmux-navigator | Neovim | nvim 侧装 `christoomey/vim-tmux-navigator`；tmux 侧是 tmux.conf 原生绑定，不依赖 TPM |

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

# 7. AI 状态指示：给两个脚本加可执行位（软链过来后权限可能丢）
chmod +x ~/.config/tmux/scripts/ai-status.sh ~/.config/tmux/scripts/ai-state.sh
```

### AI 状态指示的两个脚本

- `scripts/ai-status.sh` —— 由 `status-right` 经 `#()` 调用，跨所有会话统计并输出 `⚑2 ✦1 ✓3`
- `scripts/ai-state.sh` —— 由 **Claude Code 的 hooks** 调用，把状态写进 `pane_title`

Claude Code 侧需在 `~/.claude/settings.json` 的 `hooks` 里挂 6 个事件（给已有事件**追加同级 group**，不要覆盖原有条目）：

| 事件 | 参数 |
|------|------|
| `SessionStart` | `idle` |
| `UserPromptSubmit` | `busy` |
| `Notification` | `wait` |
| `PostToolUse` | `busy` —— **必须有**，批准权限后 Claude 不会重新触发 `UserPromptSubmit`，缺了会一直停在 `⚑` 直到 `Stop` |
| `Stop` | `idle` |
| `SessionEnd` | `clear` |

命令形如 `AI_STATE_LABEL=Claude /path/to/scripts/ai-state.sh busy`，`timeout: 5`，**不要加 `async`**（脚本约 10ms，async 会引入竞态）。

**qodercli 不要挂 hooks**：它原生的 `pane_title` 带任务摘要（如 `✦ 优化配置 | Working`），选择器里能直接看出会话在干什么；挂了 hooks 会把摘要覆盖成 `✦ qoder | Working`。代价只是状态刷新最多滞后一个 `status-interval`（2s）。

## 排错

- **tmux-jump 报 `returned 127`**：多为 `ruby` 未安装，或插件未 `prefix + I` 安装到 `~/.tmux/plugins/tmux-jump`。先 `command -v ruby` 和 `ls ~/.tmux/plugins/tmux-jump`。
- **TPM 插件全部静默不生效**：检查 `TMUX_PLUGIN_MANAGER_PATH`。配置在 XDG 路径（`~/.config/tmux/`）时 TPM 默认装到 `~/.config/tmux/plugins/`，与实际的 `~/.tmux/plugins/` 不一致会导致全部插件不加载。本配置已在 tmux.conf 里显式指定为 `~/.tmux/plugins/`。
- **`git status` 里出现 tmux 插件文件**：老机器上若在显式指定 `TMUX_PLUGIN_MANAGER_PATH` 之前装过插件，`.config/tmux/plugins/` 会留下残留；而 `.config/tmux` 软链到本仓库，于是这些文件出现在 `git status` 里，并可能被 `ga`（`git add --all`）误提交。这些插件从未进入仓库历史，属于纯本地残留，直接删即可：`rm -rf <dotfiles>/.config/tmux/plugins`。仓库 `.gitignore` 已加 `.config/tmux/plugins/` 兜底。
- **AI 状态图标不显示**：图标靠解析 `pane_title` 里的 `| Working` / `| Action Required` / `| Ready`。qodercli 若在未来版本改了这个格式，所有 pane 都会被判为非 AI，三处**静默**退回原样（不报错，所以不容易察觉）。排查顺序：
  1. `tmux list-panes -a -F '#{pane_title}'` —— 看格式是否还是 `<图标> <摘要> | <状态>`
  2. `tmux list-windows -a -F '#{E:window-status-format}'` —— 看三态判定是否还生效
  3. 直接跑 `~/.config/tmux/scripts/ai-status.sh` —— 看聚合器输出
  
  若 `status-right` 显示 `<'...' not ready>`，说明聚合脚本卡住了（它里面不该有 `sleep`/网络/`tmux wait-for`）。注意：从一次性 CLI 客户端求值 `#()`（如 `tmux display -p '#{E:status-right}'`）**永远**返回 `not ready`，那是正常的——`#()` 的结果按客户端缓存，必须在真实附着的客户端上看。
- **快捷键/配置改动**：`tmux source ~/.config/tmux/tmux.conf` 重载；部分选项（`set-clipboard`、`default-terminal`）对已存在 pane 不完全生效，可新开 pane 或 `tmux kill-server` 重启。

## 配置文档

用法、快捷键详见 `README.md`。
