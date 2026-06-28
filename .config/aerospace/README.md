# AeroSpace — 快捷键参考

## 窗口 & 工作区管理

| 快捷键 | 功能 |
|--------|------|
| `Alt + 1~0` | 切换到工作区 1~10 |
| `Alt + ←` / `Alt + →` | 上一个 / 下一个工作区（循环） |
| `Alt + Tab` | 切回上一个工作区 |
| `Alt + Cmd + 1~0` | 将当前窗口移到工作区 1~10 并跟随过去 |
| `Ctrl + Cmd + 1~0` | 将当前窗口移到工作区 1~10（不跟随） |
| `Alt + Cmd + C` | 将当前工作区移到下一个显示器 |

## 焦点 & 移动

| 快捷键 | 功能 |
|--------|------|
| `Shift + Alt + H/J/K/L` | 向 左/下/上/右 切换焦点（跨显示器循环） |
| `Cmd + Shift + H/J/K/L` | 向 左/下/上/右 移动窗口 |
| `Ctrl + W` | 关闭窗口 |
| `Alt + Shift + Enter` | 展平工作区布局树 |

## 调整窗口大小

| 快捷键 | 功能 |
|--------|------|
| `Ctrl + Shift + H` | 宽度 -50（智能调整） |
| `Ctrl + Shift + L` | 宽度 +50（智能调整） |

## 布局模式

| 快捷键 | 功能 |
|--------|------|
| `Alt + /` | 切换 tiling 方向（水平和垂直） |
| `Alt + ,` | 切换 accordion 方向（水平和垂直） |
| `Shift + Alt + F` | 将当前窗口切换为浮动模式 |

## 应用启动

| 快捷键 | 应用 |
|--------|------|
| `Alt + K` | Kitty |
| `Alt + I` | iTerm |
| `Alt + G` | Ghostty |
| `Alt + C` | VS Code |
| `Alt + F` | Finder |
| `Alt + A` | Arc |
| `Alt + W` | 微信 |
| `Alt + Q` | QQ |
| `Alt + S` | Spotify |
| `Alt + Z` | Zotero |

## Tmux 窗口切换

| 快捷键 | 功能 |
|--------|------|
| `Ctrl + 1~9` | 切换到 tmux 窗口 1~9（不含 6） |

## 浮动模式（按 `Shift + Alt + F` 进入）

| 快捷键 | 功能 |
|--------|------|
| `H/J/K/L` | 移动浮动窗口 ←/↓/↑/→（32px 步长） |
| `Shift + H/J/K/L` | 调整浮动窗口尺寸（128px 步长） |
| `Alt + T` | 居中当前窗口 |
| `Esc` | 退出浮动模式 |

## 模式快捷键

| 快捷键 | 模式 | 说明 |
|--------|------|------|
| `Cmd + Shift + S` | Service | 配置管理模式 |
| `Cmd + Shift + D` | RDP | 远程桌面模式 |
| `Cmd + Shift + B` | SBAR | 状态栏配置模式 |

### Service 模式

| 快捷键 | 功能 |
|--------|------|
| `Esc` | 重载配置，退出 |
| `Backspace` | 关闭当前工作区除焦点外的所有窗口 |
| `Cmd + Shift + H/J/K/L` | 将窗口 join 到 左/下/上/右 |

### SBAR 模式（状态栏控制）

| 快捷键 | 功能 |
|--------|------|
| `Esc` | 退出 SBAR 模式 |
| `Cmd + Shift + S` | 开关 Cava 频谱 |
| `Cmd + Shift + R` | 重启 sketchybar |
| `Cmd + Shift + Backspace` | 关闭壁纸背景 |
| `Cmd + Shift + W` | 开启壁纸背景 |
| `Cmd + Shift + ↑/↓` | 切换壁纸上一张/下一张 |
| `Cmd + Shift + ←` | 取消选中壁纸 |
| `Cmd + Shift + →/Enter` | 选中当前壁纸 |
| `Shift + Ctrl + C` | 切换亮/暗主题 |
| `Shift + Ctrl + B` | 切换黑色/模糊背景 |
| `Shift + Ctrl + T` | 切换整体主题 |

### RDP 模式

| 快捷键 | 功能 |
|--------|------|
| `Shift + Cmd + Q` | 退出 RDP 模式 |

## 杂项

| 快捷键 | 功能 |
|--------|------|
| `Shift + Ctrl + S` | 保存当前窗口布局 |
| `Shift + Ctrl + R` | 恢复保存的窗口布局 |
| `Shift + Ctrl + W` | 随机切换壁纸 |
| `Alt + Shift + P` | 全屏切换 |

## 窗口自动规则

- **浮动**: Finder、微信/QQ 聊天子窗口、Blender 子窗口、系统应用（Maps/短信/App Store/照片/日历/天气/提醒事项）、IINA、CrossOver、Bandizip、画中画、Clash Verge、MATLAB 子窗口、小红书、明日方舟、Shadowrocket、MuMu 模拟器、exe 标题窗口
- **自动分配工作区**: Arc(1)、Mail(1)、微信(2)、QQ(2)、Kitty(3)、VS Code(4)、Sioyek(5)

> 详见 [AeroSpace 官方文档](https://nikitabobko.github.io/AeroSpace/guide)
