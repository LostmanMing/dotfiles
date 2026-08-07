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
| `prefix + a` | **AI 会话选择器** —— 跨所有会话只列正在跑的 AI，模糊搜索 + 右侧实时预览 |
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

四处可见：

1. **窗口名旁** —— 只反映**当前会话**，且取窗口的**活动 pane**；分屏且 AI pane 非活动时不显示
2. **`prefix + w` / `prefix + s` 选择器行首** —— 跨会话，**会话行 / 窗口行 / pane 行都有**。会话行是该会话内所有 pane 的**聚合**，取最严重的一个（等你确认 > 进行中 > 已完成），所以会话里只要有一个窗口在等你确认，`prefix + s` 折叠着也能看到 `⚑`（聚合值由 `scripts/ai-status.sh` 每 `status-interval` 写进会话选项 `@ai_sess`）
3. **底部状态条右侧** —— 形如 `⚑2 ✦1 ✓3`，**跨所有会话逐 pane 统计**，是唯一不受上面两条作用域限制的视图；没有 AI pane 时不显示
4. **`prefix + a` 的 AI 会话选择器** —— 只列 AI，扁平一张表，`⚑` 自动置顶，右侧实时预览对方屏幕。见下

状态来源：qodercli 把状态写在它自己的 `pane_title` 里；Claude Code 不写，但它自己维护 `~/.claude/sessions/*.json`（就是它 fleetview 用的那份）。`scripts/ai-status.sh` 每 `status-interval`（2 秒）把两边归一化后写进 pane 选项 `@ai_state`，上面四处读的都是它。两个 CLI 都**零配置**，不需要挂任何 hook。

图标最多滞后 2 秒。**tmux 的 format 故意不直接读 `pane_title`** —— 标题是 CLI 自己的地盘（Claude 运行时会不停改写），我们插手就会互相覆盖，图标每 2 秒闪一次。

### AI 会话选择器（`prefix + a`）

满屏打开（不是弹窗），一行一个正在跑的 AI：

```
⚑ 等你确认   3d  work:1.1     ~/proj/api               改登录流程
✓ 已就绪    16h  0:2.1        ~/proj/web               翻译上界与瓶颈分析
✦ 进行中     0m  nvim:2.1     ~/dotfiles               AI 会话选择器
```

列依次是：状态 · 距上次活动多久 · `会话:窗口.面板` · 工作目录 · CLI 自己写的摘要。

排序是**等你确认 → 已就绪 → 进行中**：被你卡着的排最前，还在跑的不用管所以垫底；同级按最近活动排。

**vim 双模式**，进去是浏览态，不会一上来就抢你的按键：

| 按键 | 浏览（normal） | 搜索（insert） |
|------|---------------|---------------|
| `j` / `k` | 上下移动 | 输入字符 |
| `g` / `G` | 跳到首 / 尾 | 输入字符 |
| `a` / `i` / `/` | **进搜索** | 输入字符 |
| `esc` | 空操作（和 vim 一致） | **回浏览**，并清掉已输入的过滤词 |
| `enter` | 跳到那个 pane | 同左 |
| `q` | 退出 | 输入字符 |
| `ctrl-c` | 退出 | 退出 |

只有搜索态才会出现输入行；按键提示钉在最后一行，跟着模式变。右侧预览是对方 pane 的实时画面。

需要 `fzf >= 0.59`（`apt` 上 Ubuntu 22.04 的 0.29 不够用，装法见 `AGENTS.md`）。

### Copy Mode

| 操作 | 快捷键 |
|------|--------|
| 进入复制模式 | `prefix + Esc` / `Enter` |
| 退出 | `i` / `a` / `q` / `Esc` / `Enter` |
| 开始选择 | `v` |
| 行选择 | `V` |
| 块选择 | `Ctrl+v` |
| 复制 | `y` —— **复制后留在 copy-mode**，滚动位置不变，可以接着选下一段 |
| 粘贴 | `prefix + P` |

### 剪贴板互通

本地机器（Mac/Win）SSH 到远程、远程开 tmux、tmux 里开 nvim，三者互通。全靠 OSC 52，tmux buffer 当中转站：

```
     nvim yank ──OSC52──┐
                        ├─→ tmux 截获入 buffer ──OSC52 转发──→ 本地机器剪贴板
     tmux 里按 y ───────┘         │
                                  └──→ nvim 里 p 读 tmux buffer
```

| 在哪复制 | 本地 Cmd+V | tmux `prefix + P` | nvim `p` |
|---------|-----------|------------------|---------|
| nvim 里 `y` | ✅ | ✅ | ✅ |
| tmux 里 `y` | ✅ | ✅ | ✅ |
| 本地机器上复制 | — | ❌ | ❌ |

**唯一的限制**：本地复制的内容，远程 normal 模式下 `p` 拿不到——那需要 OSC 52 **读**，绝大多数终端出于安全默认拒绝（iTerm2 有开关、WezTerm 可配、Windows Terminal 不支持）。直接按终端的 Cmd+V 即可，shell 和 nvim 插入模式都正常。

不需要装 `xclip` / `pbcopy`，也不需要 X11 转发。

### Other

| 快捷键 | 功能 |
|--------|------|
| `prefix + ?` | 显示所有快捷键 |
| `prefix + R` | 重载配置 |

### 状态栏提示

左侧状态块随当前按键状态变化：按下 `prefix` 显示暗黄底 `PREFIX`；进入自定义 key-table（如 `prefix + Space` 后的 `jump` 子表）显示该表名字；平时蓝底显示 session 名。
