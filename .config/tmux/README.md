# Tmux Config — LostmanMing

## Install

```bash
# 软链配置（tmux 3.1+ 读 XDG 路径）
ln -sf ~/dotfiles/.config/tmux ~/.config/tmux

# 装 TPM 插件管理器
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# 加载配置
tmux source ~/.config/tmux/tmux.conf

# 在 tmux 内 prefix + I 拉取插件，然后：
cd ~/.tmux/plugins/tmux-thumbs && cargo build --release   # tmux-thumbs 需构建
command -v ruby || echo "tmux-jump 需要 ruby"              # tmux-jump 需 ruby
```

> 完整依赖清单见 `AGENTS.md`。改完配置用 `tmux source ~/.config/tmux/tmux.conf` 重载。

## Prefix: `Ctrl+z`

## Plugins

| 插件 | 作用 |
|------|------|
| vim-tmux-navigator | `Ctrl+hjkl` nvim ↔ tmux 无缝导航（tmux 侧为原生绑定，不依赖 TPM；nvim 侧装 christoomey/vim-tmux-navigator） |
| tmux-thumbs | `prefix + f` 屏幕词/路径/URL 标字母一键复制（需 cargo 构建） |
| tmux-jump | `prefix + Space` 再按 `s`，easymotion 式跳转光标（需 ruby） |

### 插件用法

- **tmux-thumbs**：`prefix + f` → 屏幕上的词/路径/URL/hash 标上字母 → 按对应字母即复制（经 `set-clipboard on` + OSC52 进系统剪贴板）。
- **tmux-jump**：`prefix + Space` 进入 `jump` 子表（状态栏左侧会显示 `jump`）→ 按 `s` → 输入一个目标字符 → 屏幕上该字符处标字母 → 按字母把光标跳过去；`Esc` 退出子表。

## Clipboard

tmux 内 nvim 通过 OSC 52 + tmux passthrough 写入系统剪贴板（服务端开 tmux 时生效）。

## Keybindings

### Pane

| 快捷键 | 功能 |
|--------|------|
| `prefix + h/j/k/l` | 面板导航（vim 风格） |
| `prefix + \` | 垂直分屏 |
| `prefix + -` | 水平分屏 |
| `prefix + ;` | 上一个面板（默认） |
| `prefix + z` | 全屏/还原面板（默认） |
| `prefix + x` | 关闭面板（默认） |

### Window

| 快捷键 | 功能 |
|--------|------|
| `prefix + t` | 新建窗口 |
| `prefix + n/p` | 下一个/上一个窗口 |
| `prefix + 1-9` | 切到窗口 1-9 |
| `prefix + ,` | 重命名窗口 |
| `prefix + &` | 关闭窗口 |

### Session

| 快捷键 | 功能 |
|--------|------|
| `prefix + S` | 新建 session |
| `prefix + s` | session/窗口选择器（行首带 AI 状态图标） |
| `prefix + w` | 窗口选择器（行首带 AI 状态图标） |
| `prefix + N` | 下一个 session |
| `prefix + .` | 重命名 session |
| `prefix + d` | detach |

### AI 状态指示

在跑 qodercli / Claude Code 的 pane 会显示状态图标：

| 图标 | 含义 |
|------|------|
| `⚑` 黄（加粗） | **等你确认** —— 在问你问题或等权限批准 |
| `✦` 蓝 | 进行中 |
| `✓` 绿 | 已完成 / 空闲 |

三处可见：

1. **窗口名旁** —— 只反映**当前会话**，且取窗口的**活动 pane**；分屏且 AI pane 非活动时不显示
2. **`prefix + w` / `prefix + s` 选择器行首** —— 跨会话，**会话行 / 窗口行 / pane 行都有**。会话行是该会话内所有 pane 的**聚合**，取最严重的一个（等你确认 > 进行中 > 已完成），所以会话里只要有一个窗口在等你确认，`prefix + s` 折叠着也能看到 `⚑`（聚合值由 `scripts/ai-status.sh` 每 `status-interval` 写进会话选项 `@ai_sess`）
3. **底部状态条右侧** —— 形如 `⚑2 ✦1 ✓3`，**跨所有会话逐 pane 统计**，是唯一不受上面两条作用域限制的视图；没有 AI pane 时不显示

状态来源：qodercli 原生就把状态写进 `pane_title`（还带任务摘要，所以选择器里能看出那个会话在干什么），刷新跟随 `status-interval`，最多滞后 2 秒；Claude Code 没有原生 title，由 hooks 调 `scripts/ai-state.sh` 写入，并立即刷新状态栏。

### Copy Mode

| 操作 | 快捷键 |
|------|--------|
| 进入复制模式 | `prefix + Esc` / `Enter` |
| 退出 | `i` / `a` / `q` / `Esc` / `Enter` |
| 开始选择 | `v` |
| 行选择 | `V` |
| 块选择 | `Ctrl+v` |
| 复制 | `y` |
| 粘贴 | `prefix + P` |

### Other

| 快捷键 | 功能 |
|--------|------|
| `prefix + ?` | 显示所有快捷键 |
| `prefix + R` | 重载配置 |

### 状态栏提示

左侧状态块随当前按键状态变化：按下 `prefix` 显示暗黄底 `PREFIX`；进入自定义 key-table（如 `prefix + Space` 后的 `jump` 子表）显示该表名字；平时蓝底显示 session 名。
