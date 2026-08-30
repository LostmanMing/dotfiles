# AGENTS.md — tmux

本文件供 AI Agent 配置 tmux 环境时参考。

**重要**: 先询问用户需要哪些插件/功能，按需安装对应依赖，不要一次性全装。

## Requirements

### 系统依赖

| 软件 | 用途 | 备注 |
|------|------|------|
| tmux >= 3.3 | 终端复用器 | 圆角和统一配色的 `display-popup` 需要 3.3+；配置对 3.2a 有条件保护，可继续使用但 popup 外框保持方角 |
| fzf >= 0.59 | popup/选择器界面 | Ubuntu 22.04 apt 的 0.29 太旧，安装步骤见下 |
| tldr | `prefix + ?` 命令速查 | 首次运行需 `tldr --update` 下载页面缓存 |
| yazi | `prefix + y` 浮窗文件管理器 | 可选；未安装时只显示提示，不影响其他功能。安装步骤见下 |
| Git | TPM 拉取插件 | 必须 |
| TPM | 插件管理器 | `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm` |
| 剪贴板工具 | 视终端而定 | 复制走**两条并行**的路：`set-clipboard on` 的 OSC 52，加上探到的本地工具（`pbcopy`/`wl-copy`/`xclip`/`clip.exe`）。终端支持 OSC 52 就不需要工具；**不支持的话就得靠 SSH X11 转发 + `xclip`**（实测有这样的机器） |

### 插件依赖（按需）

| 插件 | 依赖 | 说明 |
|------|------|------|
| tmux-thumbs | Rust / `cargo` | Rust 二进制，装完需 `cargo build --release` 构建 |
| tmux-jump | `ruby` | 跳转脚本用 ruby 运行，PATH 里必须有 `ruby` |
| vim-tmux-navigator | Neovim | nvim 侧装 `christoomey/vim-tmux-navigator`；tmux 侧是 tmux.conf 原生绑定，不依赖 TPM |

### Ubuntu 22.04 升级 tmux

Ubuntu 22.04 apt 只有 3.2a。完整 popup 样式需要 3.3+；当前验证版本是 3.7c。安装到版本化目录，不覆盖 `/usr/bin/tmux`：

```bash
apt-get install -y build-essential libevent-dev libncurses-dev bison pkg-config
curl -fL -o /tmp/tmux-3.7c.tar.gz https://github.com/tmux/tmux/releases/download/3.7c/tmux-3.7c.tar.gz
printf '7c60cae9a0e25288e2e24750aafc9e8800fc7fd4555e447e1b29ee4201cfb3bf  /tmp/tmux-3.7c.tar.gz\n' | sha256sum -c -
tar -xzf /tmp/tmux-3.7c.tar.gz -C /tmp
mkdir -p ~/.local/opt/tmux-3.7c
(cd /tmp/tmux-3.7c && ./configure --prefix="$HOME/.local/opt/tmux-3.7c" && make -j2 && make install)
ln -sfn ~/.local/opt/tmux-3.7c/bin/tmux ~/.local/bin/tmux
```

新版 client 可连接现有 3.2a server，但 `tmux -V` 只显示 client 版本；服务端版本用 `tmux display-message -p '#{version}'`。不要为了升级强杀仍有工作的 server：现有会话全部自然结束后，下次启动会自动使用 3.7c，圆角 popup 才真正生效。

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

# 8. prefix + a 的 AI 选择器和 prefix + ? 的 tldr 界面都需要 fzf >= 0.59。
#    **不能用 apt**：Ubuntu 22.04 只有 0.29，没有双模式要用的输入区切换动作。
#    装上游静态二进制（会遮住 apt 的那个，不动系统包）
curl -fsSL https://github.com/junegunn/fzf/releases/download/v0.74.2/fzf-0.74.2-linux_amd64.tar.gz \
  | tar xz -C /usr/local/bin fzf && fzf --version

# 9. prefix + ? 的命令速查
apt-get install -y tldr
tldr --update

# 10. 可选：prefix + y 的浮窗文件管理器
# Ubuntu 22.04 没有合适的 apt 包；从 Yazi 官方 Releases 下载与架构匹配的预编译包，
# 解压后把其中的 yazi 和 ya 安装到 ~/.local/bin/。
# 不要使用旧命令 `cargo install yazi-fm yazi-cli`：当前发布包缺少内置插件文件，会编译失败。
```

### 开发与隔离验证

修改 tmux 配置时使用 `/develop-tmux`。先运行隔离验证，不要把用户正在工作的 server 当测试环境：

```bash
~/dotfiles/skills/develop-tmux/scripts/verify.sh
~/dotfiles/skills/develop-tmux/scripts/verify.sh --interactive
```

第一条检查 shell 语法、配置连续加载和关键绑定；第二条附着到私有 server，用于实际操作 popup、copy-mode、状态栏和快捷键。只有隔离验证通过后，才按用户许可在活跃 server 执行 `tmux source`。

### 版本下限

所有硬性要求集中在这里。**改动前先看这张表**，别引入更高的下限而不记一笔。

| 依赖 | 下限 | 卡在哪个特性 | 不满足会怎样 |
|------|------|------------|------------|
| tmux | **3.3**（完整样式；当前 client 3.7c） | `popup-border-lines rounded`、`popup-style`、`popup-border-style`；其余状态栏/选择器功能仍兼容 3.2a，配置用服务端版本条件保护。另一台 next-3.8 也兼容，且 `passthrough` 选项不存在（`tmux.conf` 有记） | 3.2a 下功能可用，但 popup 外框仍是方角且不能统一着色 |
| `tmux-256color` terminfo | 可选 | `default-terminal` 优先用它（有 `Smulx` undercurl 和斜体）；`if-shell` 探不到会自动退回 `xterm-256color` | 只是失去 undercurl / 斜体，其余照常 |
| fzf | **0.59**（实测装的是 0.74.2） | `--no-input` / `show-input` / `hide-input` —— `prefix+a` 与 `prefix+?` 的 vim 双模式。另外还要 `rebind`（0.30 引入）和 `change-header`（0.40 引入），都被 0.59 覆盖 | fzf 吐一句参数错误就退出、pane/popup 瞬间关掉，等于静默失败；两个脚本都有显式版本检查 |
| Claude Code | 实测 2.1.161 / 2.1.220 可用。`claude agents` 子命令的下限是 2.1.139，`sessions/*.json` 是它的后端，**推测**同批引入，未实测更早版本 | `~/.claude/sessions/<pid>.json` 的 `status` / `procStart` / `cwd` / `kind` 字段。**`kind` 缺失的记录会被整条丢弃**（照抄 Claude 自己的行为），所以更早版本若不写 `kind` 就全都不认 | Claude 的 pane 永远没图标，qodercli 不受影响 |
| 平台 | Linux | `procStart` 与 `/proc/<pid>/stat` 第 22 字段（starttime）对齐、从 `tty_nr` 解 `/dev/pts/N` | macOS 上 Claude 侧完全失效 |
| awk | mawk / gawk 均可 | 只用 POSIX 子集。但 mawk 的 `length`/`substr` 按**字节**算，所以代码里刻意不截断中文摘要、前导字形也显式列举而不用 `[^ ]` | 中文被截成半个字符 |
| ruby | 任意 | tmux-jump 插件 | `prefix + Space s` 报 `returned 127` |
| cargo | 任意 | 编译 tmux-thumbs | `prefix + Space f` 不可用 |

### 剪贴板互通

本地机器 ↔ 远程 tmux ↔ 远程 nvim 三方互通。复制走**两条并行**的路，谁通算谁的；tmux buffer 当内部中转站：

```
  nvim yank ─┬─OSC52──→ tmux 截获入 buffer ──转发──→ 支持 OSC 52 的终端
             └─工具───→ xclip/pbcopy/...（给不支持 OSC 52 的终端兜底）
  tmux 按 y ─┬────────→ tmux buffer ──→ nvim 的 p 读 `tmux save-buffer -`
             └─工具───→ 同上
```

实测依据（都在隔离 socket 上用 `script` 录终端输出流验过）：

| 验证项 | 结果 |
|--------|------|
| `set-clipboard on` 时内层程序发的 OSC 52 | **被 tmux 截获写进自己 buffer** |
| `set-clipboard external` 时 | 只透传，**不入 buffer** —— nvim ↔ tmux 那条腿会断，**所以不能改成 external** |
| `copy-selection`（不带 pipe） | 既入 buffer **又**往外发 OSC 52 |
| `copy-pipe` 到一个必然失败的命令 | buffer **照样被填**、也照样留在 copy-mode —— 所以挂工具是纯增量，零代价 |
| 某台机器的本地终端 | **不接受 OSC 52**，`printf '\033]52;...'` 到本地按 Cmd+V 拿不到东西 |

**为什么 `@clipboard_cmd` 探测必须留着**：曾经删过一次，理由是「`copy-selection` 单独就能发 OSC 52，外部工具多余」。结果那台终端不认 OSC 52 的机器**直接复制不出去**——它一直靠 SSH X11 转发 + `xclip`。**不要再删，也不要按 SSH 排除**（远程恰恰是最需要这条兜底的场景）。

判断上唯一要小心的是：**别拿 `DISPLAY` 做二选一**。以前 nvim 侧看到 `DISPLAY` 有值就只走 `xclip`、不发 OSC 52，那样两头都可能落空。现在两条并行，不再二选一。

**`terminal-features` 必须先 `-gu` 再 `-as`**：`-as` 是追加，每次 `prefix + R` / `tmux source` 都再加一份，实测不加 `-gu` 连按两次就攒到 5 条（`terminal-overrides` 同理，历史上攒到过 `xterm*:Tc` ×19）。`-gu` 会恢复 tmux 自带的两条默认（`xterm*:clipboard:...` 和 `screen*:title`，其中 `clipboard` 正是 OSC 52 外发所需），要留着。

**本地 → 远程方向的限制**：normal 模式 `p` 拿不到本地剪贴板，那需要 OSC 52 **读**，绝大多数终端出于安全默认拒绝。用终端的 Cmd+V 即可（shell 和 nvim 插入模式正常）。nvim 侧刻意**不用** `vim.ui.clipboard.osc52` 的 `paste`——它等终端回应，runtime 源码里写死先等 1s 再等 9s，每次 `p` 都会卡住。

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
- **Claude Code** 不写 title，但维护 `~/.claude/sessions/<pid>.json`，这是它 fleetview 用的同一份数据。两个字段的处理都**照抄 Claude bundle 里它自己的逻辑**，别自己发明：

  | 字段 | 全集 | 我们怎么处理 |
  |------|------|------------|
  | `status` | `["busy","shell","idle","waiting"]` | 只有 `idle` 和 `waiting` 是特例，**其余一律算「进行中」**（含 `shell`，即在 Claude 里跑 shell）。抄的是它的 `e==="idle"?"idle":e==="waiting"?"waiting":"busy"`。这样将来新增状态只会退化成进行中，不会整个 pane 没图标——`shell` 就曾这么漏掉过 |
  | `kind` | `["interactive","bg","daemon","daemon-worker"]` | 只收 `interactive` 和**没有 `jobId` 的 `bg`**；`daemon` / `daemon-worker` 和**缺 `kind` 字段**的记录都丢。抄的是它列 agents 时的 `if (d.kind !== "interactive" && d.kind !== "bg") continue; if (d.kind === "bg" && d.jobId) continue;` |

  不过滤 `kind` 的后果：一个 busy 的后台进程只要 tty 落在同一个 pane 上，就会盖掉那个 pane 里已经答完的交互会话——我们是按最严重聚合的。

**铁律：我们绝不写 `pane_title`。** 曾经给 Claude 合成过标题，结果 Claude 自己也在写标题（设置项 `terminalTitleFromRename`），运行时每渲染一次就覆盖掉，我们每 2 秒抢回来 —— 底部标签的图标就一闪一闪。现在标题完全归 CLI 所有，我们只写自己的 `@ai_state`，没人能覆盖。tmux 的 format 也一律读 `@ai_state`，不读 `pane_title`。代价是图标最多滞后一个 `status-interval`。

`@ai_state` 是 pane 作用域选项，但在 **window 作用域会解析到该窗口的活动 pane**，所以 `window-status-format` 直接读得到。会话行读不到（只会解析到活动 pane，对「另一个窗口在等确认」的会话会报错状态），所以会话聚合由 `ai-status.sh` 预先算好写进 `@ai_sess`。

**Claude 的 pid 怎么对上 pane**：`sessions/<pid>.json` 里的 `procStart` 实测就是 `/proc/<pid>/stat` 第 22 字段（starttime），拿它挡 pid 复用——进程没了或 starttime 不匹配就是陈文件。连接键是 tty，直接从 stat 的 `tty_nr` 纯算术解出 `/dev/pts/N`，再和 `#{pane_tty}` join，不 fork `readlink`。

**为什么不用 hooks**：hook 有已证实的覆盖漏洞——按 `Esc` 打断、拒绝提问、关掉权限弹窗，这几种都不触发任何事件，状态会永久卡在 `⚑`。`sessions/*.json` 是 Claude UI 状态的镜像，没有事件缺口。

**为什么 AI 选择器仍不用 `display-popup`**：它设计成和 `choose-tree -Z` 一样的无边框满屏界面，并且需要直接切换当前 client。`split-window -f` + `resize-pane -Z` 退出后会自然恢复原布局，也无需处理 popup 拆除与 client 切换竞态；因此即使 tmux 升到 3.3+ 也保留这套结构。

**选择器的 vim 双模式**（两个坑都实测过）：

- `--no-input` 隐藏输入区、让按键只触发绑定，这就是 normal 模式；但**必须再配 `unbind`/`rebind`**——进 insert 后若 `j`/`k` 还绑着 `down`/`up`，就打不出 `j` 这个字符了。上游 CHANGELOG 的 0.59.0 示例正是这么写的。
- `esc` 的动作顺序里 **`clear-query` 必须排在 `hide-input` 之前**。反了的话输入区一藏起来，查询变更就不再触发重新过滤，回到 normal 时列表还停在过滤后的结果上。
- 列表行的可见内容拼成**一个** TSV 字段再 `--with-nth=4`。用多个字段会被 fzf 用原始分隔符拼回去，tab 按 8 列制表位展开，宽度全被吃掉、列也对不齐。

### 统一 fzf 层与 TLDR popup

`scripts/fzf-common.sh` 是四个 fzf 界面的共享层：统一版本检查、清空 `FZF_DEFAULT_OPTS`、零 margin 布局和 OneDark 配色。`config-pick.sh`、`path-pick.sh`、`tldr-popup.sh` 共享 popup 基线；`ai-pick.sh` 只共享版本/颜色，保留自己的满屏 `reverse-list` 布局。各工具的数据生成、键位和 preview 不要塞进公共文件。

`scripts/tldr-popup.sh` 在 `prefix + ?` 的 popup 里运行单个 fzf。输入时所有字符键都必须可录入；Enter 用 `reload-sync` 调脚本自己的 `--render` 模式刷新结果并隐藏输入栏。结果中 `j/k`、`g/G`、半页/整页移动，`a/i` 清空并恢复输入，`q/Esc` 退出；`[`/`]` 调 `--jump` 重新计算上一/下一空行的 `pos(N)`，不要改回依赖 fzf 临时搜索状态的写法。`y` 调 `--copy` 复制当前完整逻辑行到 tmux buffer/OSC52 和可用的本地剪贴板工具。

模式切换必须配套 `unbind`/`rebind`；否则输入栏里的 `j/k/a/i/q/y` 会被当作浏览键。查询只经 fzf `{q}` 作为单参数传给 renderer，renderer 再把空格规范化为连字符（`git stage` → `git-stage`），禁止用 `eval` 拼接用户输入。

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

  Claude 那一侧单独查：`ls ~/.claude/sessions/` 应该有活着的 `<pid>.json`，且 `status` 是 `busy|shell|idle|waiting` 之一。

  若 `status-right` 显示 `<'...' not ready>`，说明聚合脚本卡住了（它里面不该有 `sleep`/网络/`tmux wait-for`）。注意：从一次性 CLI 客户端求值 `#()`（如 `tmux display -p '#{E:status-right}'`）**永远**返回 `not ready`，那是正常的——`#()` 的结果按客户端缓存，必须在真实附着的客户端上看。
- **`prefix + a` 没反应**：会弹一条 `display-message` 说明原因 —— 没装 fzf、fzf 版本低于 0.59（apt 的 0.29 就是），或确实没有 AI 在跑。若提示「没有正在运行的 AI 会话」但明明有，按上一条查 `ai-panes.sh`。
- **`prefix + a` 里 `j`/`k` 打出字符而不是移动**：说明 `rebind` 没生效，多半是 fzf 版本不对，`fzf --version` 确认走的是 `/usr/local/bin` 那个而不是 `/usr/bin` 的 0.29。
- **快捷键/配置改动**：`tmux source ~/.config/tmux/tmux.conf` 重载；部分选项（`set-clipboard`、`default-terminal`）对已存在 pane 不完全生效，可新开 pane 或 `tmux kill-server` 重启。

## 配置文档

用法、快捷键详见 `README.md`。
