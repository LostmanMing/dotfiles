# Tmux Config — LostmanMing

## Install

```bash
ln -sf ~/dotfiles/.config/tmux ~/.config/tmux
tmux source ~/.config/tmux/tmux.conf
```

## Prefix: `Ctrl+z`

## Dependencies

| 工具 | 用途 | 安装 |
|------|------|------|
| tmux >= 3.2 | 终端复用器 | 包管理器安装 |
| TPM | 插件管理器 | `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm` |

## Plugins

| 插件 | 作用 |
|------|------|
| tmux.nvim | `Ctrl+hjkl` nvim ↔ tmux 面板无缝导航 |
| tmux-thumbs | `prefix + f` 屏幕词/路径/URL 标字母一键复制（需 cargo 构建） |
| tmux-jump | `prefix + Space` 再按 `s`，easymotion 式跳转光标（需 ruby） |

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
| `prefix + s` | session/窗口选择器 |
| `prefix + N` | 下一个 session |
| `prefix + .` | 重命名 session |
| `prefix + d` | detach |

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
