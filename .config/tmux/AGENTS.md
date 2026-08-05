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

# 7. AI 状态指示与选择器：给脚本加可执行位（软链过来后权限可能丢）
chmod +x ~/.config/tmux/scripts/*.sh

# 8. prefix + a 的选择器需要 fzf >= 0.59。**不能用 apt**：Ubuntu 22.04 只有 0.29，
#    没有 vim 模式要的 --no-input。装上游静态二进制（会遮住 apt 的那个，不动系统包）
curl -fsSL https://github.com/junegunn/fzf/releases/download/v0.74.2/fzf-0.74.2-linux_amd64.tar.gz \
  | tar xz -C /usr/local/bin fzf && fzf --version
```

### 版本下限

所有硬性要求集中在这里。**改动前先看这张表**，别引入更高的下限而不记一笔。

| 依赖 | 下限 | 卡在哪个特性 | 不满足会怎样 |
|------|------|------------|------------|
| tmux | 3.2a（开发与验证版本） | `#{l:~}` 字面量修饰符、`choose-tree -Zw/-Zs` 的 `-F`、pane 作用域选项在 window 作用域解析到活动 pane | 图标全不显示，或 format 直接报错 |
| fzf | **0.59**（实测装的是 0.74.2） | `--no-input` / `show-input` / `hide-input` —— vim 的 normal/insert 切换。另外还要 `rebind`（0.30 引入）和 `change-header`（0.40 引入），都被 0.59 覆盖 | fzf 吐一句参数错误就退出、pane 瞬间关掉，等于静默失败。`ai-pick.sh` 里有显式版本检查挡住这种情况 |
| Claude Code | 实测 2.1.161 可用。`claude agents` 子命令的下限是 2.1.139，`sessions/*.json` 是它的后端，**推测**同批引入，未实测更早版本 | `~/.claude/sessions/<pid>.json` 的 `status` / `procStart` / `cwd` 字段 | Claude 的 pane 永远没图标，qodercli 不受影响 |
| 平台 | Linux | `procStart` 与 `/proc/<pid>/stat` 第 22 字段（starttime）对齐、从 `tty_nr` 解 `/dev/pts/N` | macOS 上 Claude 侧完全失效 |
| awk | mawk / gawk 均可 | 只用 POSIX 子集。但 mawk 的 `length`/`substr` 按**字节**算，所以代码里刻意不截断中文摘要、前导字形也显式列举而不用 `[^ ]` | 中文被截成半个字符 |
| ruby | 任意 | tmux-jump 插件 | `prefix + Space s` 报 `returned 127` |
| cargo | 任意 | 编译 tmux-thumbs | `prefix + Space f` 不可用 |

### AI 状态指示与选择器

三个脚本，一条数据流：

| 脚本 | 谁调 | 干什么 |
|------|------|--------|
| `scripts/ai-panes.sh` | 下面两个 | **唯一的判定逻辑**：遍历所有 pane，判定哪些在跑 AI、什么状态，输出 TSV。纯数据，不排版 |
| `scripts/ai-status.sh` | `status-right` 的 `#()`，每 `status-interval`（2s） | 输出 `⚑2 ✦1 ✓3` 计数；把状态写进 `@ai_state`（pane）和 `@ai_sess`（会话） |
| `scripts/ai-pick.sh` | `prefix + a` | fzf 界面 + 跳转 |

**两个 CLI 都零配置**，不需要在 Claude 或 qodercli 里挂任何 hook。

状态来源：

- **qodercli** 原生把状态写在 `pane_title` 里，后缀是 `| Working` / `| Action Required` / `| Ready`（还带任务摘要）
- **Claude Code** 不写 title，但维护 `~/.claude/sessions/<pid>.json`（`status` 字段是 `idle|busy|waiting`），这是它 fleetview 用的同一份数据

**铁律：我们绝不写 `pane_title`。** 曾经给 Claude 合成过标题，结果 Claude 自己也在写标题（设置项 `terminalTitleFromRename`），运行时每渲染一次就覆盖掉，我们每 2 秒抢回来 —— 底部标签的图标就一闪一闪。现在标题完全归 CLI 所有，我们只写自己的 `@ai_state`，没人能覆盖。tmux 的 format 也一律读 `@ai_state`，不读 `pane_title`。代价是图标最多滞后一个 `status-interval`。

`@ai_state` 是 pane 作用域选项，但在 **window 作用域会解析到该窗口的活动 pane**，所以 `window-status-format` 直接读得到。会话行读不到（只会解析到活动 pane，对「另一个窗口在等确认」的会话会报错状态），所以会话聚合由 `ai-status.sh` 预先算好写进 `@ai_sess`。

**Claude 的 pid 怎么对上 pane**：`sessions/<pid>.json` 里的 `procStart` 实测就是 `/proc/<pid>/stat` 第 22 字段（starttime），拿它挡 pid 复用——进程没了或 starttime 不匹配就是陈文件。连接键是 tty，直接从 stat 的 `tty_nr` 纯算术解出 `/dev/pts/N`，再和 `#{pane_tty}` join，不 fork `readlink`。

**为什么不用 hooks**：hook 有已证实的覆盖漏洞——按 `Esc` 打断、拒绝提问、关掉权限弹窗，这几种都不触发任何事件，状态会永久卡在 `⚑`。`sessions/*.json` 是 Claude UI 状态的镜像，没有事件缺口。

**选择器为什么不用 `display-popup`**：tmux 3.2a 的 popup 去不掉边框（`-B` 是 3.3 才有）。改用 `split-window -f` + `resize-pane -Z` 开一个满屏 zoom 的临时 pane，视觉上和 `choose-tree -Z` 一致，fzf 退出后 pane 自然消亡。也因此当前 client 就是要切的那个 client，不需要上游那套「把宿主 client 名存进全局选项」+ popup 拆除竞态重试。

**选择器的 vim 双模式**（两个坑都实测过）：

- `--no-input` 隐藏输入区、让按键只触发绑定，这就是 normal 模式；但**必须再配 `unbind`/`rebind`**——进 insert 后若 `j`/`k` 还绑着 `down`/`up`，就打不出 `j` 这个字符了。上游 CHANGELOG 的 0.59.0 示例正是这么写的。
- `esc` 的动作顺序里 **`clear-query` 必须排在 `hide-input` 之前**。反了的话输入区一藏起来，查询变更就不再触发重新过滤，回到 normal 时列表还停在过滤后的结果上。
- 列表行的可见内容拼成**一个** TSV 字段再 `--with-nth=4`。用多个字段会被 fzf 用原始分隔符拼回去，tab 按 8 列制表位展开，宽度全被吃掉、列也对不齐。

## 排错

- **tmux-jump 报 `returned 127`**：多为 `ruby` 未安装，或插件未 `prefix + I` 安装到 `~/.tmux/plugins/tmux-jump`。先 `command -v ruby` 和 `ls ~/.tmux/plugins/tmux-jump`。
- **TPM 插件全部静默不生效**：检查 `TMUX_PLUGIN_MANAGER_PATH`。配置在 XDG 路径（`~/.config/tmux/`）时 TPM 默认装到 `~/.config/tmux/plugins/`，与实际的 `~/.tmux/plugins/` 不一致会导致全部插件不加载。本配置已在 tmux.conf 里显式指定为 `~/.tmux/plugins/`。
- **`git status` 里出现 tmux 插件文件**：老机器上若在显式指定 `TMUX_PLUGIN_MANAGER_PATH` 之前装过插件，`.config/tmux/plugins/` 会留下残留；而 `.config/tmux` 软链到本仓库，于是这些文件出现在 `git status` 里，并可能被 `ga`（`git add --all`）误提交。这些插件从未进入仓库历史，属于纯本地残留，直接删即可：`rm -rf <dotfiles>/.config/tmux/plugins`。仓库 `.gitignore` 已加 `.config/tmux/plugins/` 兜底。
- **AI 状态图标不显示**：format 读的是 `@ai_state`，它由 `ai-status.sh` 每 2 秒写入；qodercli 那一侧的输入仍是 `pane_title` 里的 `| Working` / `| Action Required` / `| Ready`，它若在未来版本改了这个格式，所有 qodercli pane 都会被判为非 AI，四处**静默**退回原样（不报错，所以不容易察觉）。排查顺序：
  1. `~/.config/tmux/scripts/ai-panes.sh` —— 第一列该是 `wait`/`busy`/`idle`，全空说明判定挂了
  2. `tmux list-panes -a -F '#{pane_title}'` —— 看 qodercli 的格式是否还是 `<图标> <摘要> | <状态>`
  3. `tmux list-panes -a -F '#{pane_id} #{@ai_state}'` —— 看选项有没有被写进去
  4. `tmux list-windows -a -F '#{E:window-status-format}'` —— 看 format 是否还认得这个值
  5. `~/.config/tmux/scripts/ai-status.sh` —— 看计数输出

  Claude 那一侧单独查：`ls ~/.claude/sessions/` 应该有活着的 `<pid>.json`，且 `status` 是 `idle|busy|waiting`。

  若 `status-right` 显示 `<'...' not ready>`，说明聚合脚本卡住了（它里面不该有 `sleep`/网络/`tmux wait-for`）。注意：从一次性 CLI 客户端求值 `#()`（如 `tmux display -p '#{E:status-right}'`）**永远**返回 `not ready`，那是正常的——`#()` 的结果按客户端缓存，必须在真实附着的客户端上看。
- **`prefix + a` 没反应**：会弹一条 `display-message` 说明原因 —— 没装 fzf、fzf 版本低于 0.59（apt 的 0.29 就是），或确实没有 AI 在跑。若提示「没有正在运行的 AI 会话」但明明有，按上一条查 `ai-panes.sh`。
- **`prefix + a` 里 `j`/`k` 打出字符而不是移动**：说明 `rebind` 没生效，多半是 fzf 版本不对，`fzf --version` 确认走的是 `/usr/local/bin` 那个而不是 `/usr/bin` 的 0.29。
- **快捷键/配置改动**：`tmux source ~/.config/tmux/tmux.conf` 重载；部分选项（`set-clipboard`、`default-terminal`）对已存在 pane 不完全生效，可新开 pane 或 `tmux kill-server` 重启。

## 配置文档

用法、快捷键详见 `README.md`。
