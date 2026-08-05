#!/usr/bin/env bash
# ai-status.sh —— 汇总所有 session 里 AI CLI pane 的状态。三件事：
#   1. 采集 Claude Code 状态：读 ~/.claude/sessions/*.json，把 pid 映射到 pane，
#      合成与 qodercli 同语法的 pane_title（见下「线格式」）
#   2. 输出全局计数给 status-right（由 #() 调用），形如  ⚑2 ✦1 ✓3
#      没有 AI pane 时输出空串（状态栏退回原样，无占位符）
#   3. 把每个会话的聚合状态写进会话作用域选项 @ai_sess，
#      供 prefix+s（choose-tree -Zs，只显示会话行）读取
#
# 线格式：pane_title 是唯一的状态载体，三个展示面（window-status / choose-tree /
# status-right）都只解析它的 "| Working" / "| Action Required" / "| Ready" 后缀。
# qodercli 原生就这么写 title，Claude 不写，所以由本脚本代它写成同样的语法。
#
# 为什么读 sessions 而不挂 hooks：hook 有**已证实的覆盖漏洞**——按 Esc 打断、
# 拒绝一个提问、关掉权限弹窗，这几种都不触发任何事件，状态会永久卡住。
# sessions/*.json 是 Claude 自己 UI 状态的镜像（它 fleetview 用的同一份数据），
# 没有事件缺口。代价是最多滞后一个 status-interval（2s），与 qodercli 一致。
#
# 为什么会话状态要靠这里算：tmux 3.2a 的 format 无法遍历 pane，而 #{pane_title}
# 在会话作用域只解析到活动 pane——会对「另一个窗口在等确认」的会话报错状态。
# 本脚本反正每 status-interval 就要遍历一遍所有 pane，顺手聚合几乎零成本，
# 比给 choose-tree 每行挂一个 #() 便宜得多。
#
# 约束（违反任一条都会让状态栏坏掉）：
#   1. tmux 调用次数必须是常数 —— 每 pane 调一次会让开销随 pane 数线性增长。
#      所有写回（会话选项 / pane 选项 / pane 标题）用 \; 串成**一次**调用。
#   2. 绝不阻塞 —— 挂住时 tmux 会在状态栏显示 <'...' not ready>，所以不得有
#      sleep / 网络 / tmux wait-for，且每个 tmux 调用都要能失败退出
#   3. 只输出自己构造的数字和图标 —— #() 的输出会被 tmux 再解析一遍 #[...]，
#      若把任务摘要回显出去，摘要里的 #[ 会污染甚至被求值
#   4. 样式块写成 #[fg=X]#[bold] 分开的形式 —— 条件表达式内的 #[fg=X,bold]
#      会被逗号截断成 #[fg=X（实测）
set -u

command -v tmux >/dev/null 2>&1 || exit 0

claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# ---- 1. Claude Code: sessions/*.json -> "tty 状态 目录名" ----
#
# 每个交互式 Claude 进程写一个 <pid>.json，正常退出时自删。字段：
#   pid / status(idle|busy|waiting) / procStart / cwd
# procStart 实测就是 /proc/<pid>/stat 的第 22 字段（starttime，时钟节拍），
# 所以拿它做 pid 复用的判据：进程没了或者 starttime 不对，就是陈文件，丢掉。
#
# pid -> pane 的连接键是 tty。不 fork readlink /proc/pid/fd/0（stdin 可能被
# 重定向，而且每个会话多一次 fork），直接解 stat 的 tty_nr：
#   major = (t>>8)&0xff        -> 纯算术 int(t/256)%256
#   minor = (t&0xff) | ((t>>12)&0xfff00)
#          注意掩码是移位**之后**的 0xfff00，不是 0xfff —— 写成 0xfff 会把
#          /dev/pts/14 算成 2062（踩过）
# 只认 major 136（pts）：tty1 之类的物理终端不可能是 tmux pane。
claude_states=$(awk '
  function jnum(s, k,   v) {
    if (match(s, "\"" k "\"[ ]*:[ ]*-?[0-9]+")) {
      v = substr(s, RSTART, RLENGTH); sub(/^.*:[ ]*/, "", v); return v
    }
    return ""
  }
  function jstr(s, k,   v) {
    if (match(s, "\"" k "\"[ ]*:[ ]*\"[^\"]*\"")) {
      v = substr(s, RSTART, RLENGTH)
      sub(/^.*:[ ]*"/, "", v); sub(/"$/, "", v); return v
    }
    return ""
  }
  function emit(buf,   pid, ps, raw, path, line, F, t, min, st, base) {
    pid = jnum(buf, "pid");   if (pid == "") return
    ps  = jstr(buf, "procStart")
    raw = jstr(buf, "status")
    if      (raw == "waiting") st = "wait"
    else if (raw == "busy")    st = "busy"
    else if (raw == "idle")    st = "idle"
    else                       return
    path = "/proc/" pid "/stat"
    if ((getline line < path) <= 0) { close(path); return }
    close(path)
    sub(/^[^ ]+ \(.*\) /, "", line)     # comm 可能含空格，整段剥掉；字段左移 2
    split(line, F, " ")
    if (ps != "" && F[20] != ps) return
    t = F[5] + 0
    if (int(t / 256) % 256 != 136) return
    min = t % 256 + (int(t / 1048576) % 4096) * 256
    base = jstr(buf, "cwd"); sub(/.*\//, "", base)
    gsub(/[^A-Za-z0-9._-]/, "", base)   # 目录名会进 pane_title，只留安全字符
    printf "/dev/pts/%d %s %s\n", min, st, base
  }
  FNR == 1 && buf != "" { emit(buf); buf = "" }
  { buf = buf $0 }
  END { if (buf != "") emit(buf) }
' "$claude_dir"/sessions/*.json 2>/dev/null)

# ---- 2. 遍历所有 pane，定状态、算计数、决定要写回什么 ----
#
# 用 ~ 作字段分隔符：pane_title 里不会出现（qodercli 用的是 " | "）
# host_short 带上是为了 pane 清理时能还原标题，免去一次 tmux display 调用
panes=$(tmux list-panes -a -F '#{session_name}#{l:~}#{pane_id}#{l:~}#{pane_tty}#{l:~}#{@ai_state}#{l:~}#{host_short}#{l:~}#{pane_title}' 2>/dev/null) || exit 0
[ -n "$panes" ] || exit 0

# 输出行的第一个字段之后必须是定长 token，可变长的（会话名、标题）放在行尾，
# 因为 shell 侧用 `read -r tag tok rest` 取，只有最后一个变量能吃空格。
parsed=$(printf '%s\n' "$panes" | awk -F'~' -v cmap="$claude_states" '
  function rk(s) { return (s == "wait" ? 3 : (s == "busy" ? 2 : (s == "idle" ? 1 : 0))) }
  # 合成 Claude 的线格式。字形刻意与 qodercli 原生一致（▲/✦/◇），属于线格式，
  # 不要改成显示层那套 ⚑/✦/✓ —— 判定只看 "| xxx" 后缀，字形不参与。
  # 带上 cwd 目录名，好让 choose-tree 里能看出那个会话在哪个项目上。
  function wire(s, b,   lbl) {
    lbl = "Claude"; if (b != "") { lbl = lbl " " b }
    if (s == "wait") { return "▲ " lbl " | Action Required" }
    if (s == "busy") { return "✦ " lbl " | Working" }
    return "◇ " lbl " | Ready"
  }
  BEGIN {
    n = split(cmap, L, "\n")
    for (i = 1; i <= n; i++) {
      if (split(L[i], A, " ") < 2) { continue }
      # 同一 tty 上有多个 Claude（嵌套）时取最严重的
      if (rk(A[2]) > crank[A[1]]) { crank[A[1]] = rk(A[2]); cst[A[1]] = A[2]; cwd[A[1]] = A[3] }
    }
  }
  {
    sess = $1; pid = $2; tty = $3; old = $4; hn = $5; title = $6
    if (tty in cst) {
      s = cst[tty]
      want = wire(s, cwd[tty])
      # 只在有变化时才写，稳态下这两行都不产生输出
      if (old != s)     { printf "PSET %s %s\n", s, pid }
      if (title != want) { printf "PTITLE %s %s\n", pid, want }
    } else if (old != "") {
      # 有 @ai_state 但没有活的 Claude —— 进程已退出（或 hook 时代的残留）。
      # 标题还挂着旧状态，清掉并还原成主机名，否则会永远虚增计数。
      printf "PCLR %s %s\n", pid, hn
      s = "none"
    } else {
      # 匹配带竖线的 "| Working" 而非裸 Working：任务摘要里含该词不会误判
      if      (title ~ /\| Action Required/) { s = "wait" }
      else if (title ~ /\| Working/)         { s = "busy" }
      else if (title ~ /\| Ready/)           { s = "idle" }
      else                                   { s = "none" }
    }
    c[s]++
    if (rk(s) > rank[sess]) { rank[sess] = rk(s) }
    seen[sess] = 1
  }
  END {
    printf "COUNT %d %d %d\n", c["wait"] + 0, c["busy"] + 0, c["idle"] + 0
    for (s in seen) {
      st = (rank[s] == 3 ? "wait" : (rank[s] == 2 ? "busy" : (rank[s] == 1 ? "idle" : "-")))
      printf "SESS %s %s\n", st, s
    }
  }
')

read -r _ wait busy idle <<EOF
$(printf '%s\n' "$parsed" | grep '^COUNT ')
EOF

# ---- 3. 写回，全部串成一次 tmux 调用 ----
#
# 用 POSIX 写法而非 bash 数组：这个脚本曾被 status-right 写成 #(sh .../ai-status.sh)
# 调用，而 /bin/sh 是 dash，`cmd=()` 直接语法错误退出、状态栏静默空白且不报错。
# 现在 status-right 已改成直接调（走 shebang 的 bash），但保持 POSIX 兼容更稳。
# 会话名可能含空格或单引号，所以用 eval + 单引号转义。
# 空状态必须用 -u 取消而不是传空值——set 缺少值参数会报错，而命令是串联的，
# 一条失败会让整条全部失败（踩过）。
cmd=''
add() { [ -n "$cmd" ] && cmd="$cmd ';'"; cmd="$cmd $1"; }
q() {
    # 只有值里真含单引号时才 fork sed —— 每行一次 fork 会让脚本从 ~10ms 涨到 ~40ms
    case "$1" in
        *\'*) printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")" ;;
        *)    printf "'%s'" "$1" ;;
    esac
}

while read -r tag tok rest; do
    case "$tag" in
        SESS)
            [ -n "$rest" ] || continue
            if [ "$tok" = '-' ]; then
                add "set -t $(q "$rest") -u @ai_sess"
            else
                add "set -t $(q "$rest") @ai_sess $(q "$tok")"
            fi
            ;;
        PSET)
            add "set -p -t $(q "$rest") @ai_state $(q "$tok")"
            ;;
        PTITLE)
            add "select-pane -t $(q "$tok") -T $(q "$rest")"
            ;;
        PCLR)
            add "set -p -t $(q "$tok") -u @ai_state"
            add "select-pane -t $(q "$tok") -T $(q "$rest")"
            ;;
    esac
done <<EOF
$(printf '%s\n' "$parsed" | grep -v '^COUNT ')
EOF
[ -n "$cmd" ] && eval "tmux $cmd" 2>/dev/null || true

out=""
# ⚑ 等你确认：反色黄块，整条状态栏上最醒目的元素
[ "${wait:-0}" -gt 0 ] && out="${out}#[fg=#21252b]#[bg=#e5c07b]#[bold] ⚑${wait} #[default]"
[ "${busy:-0}" -gt 0 ] && out="${out}#[bg=#21252b]#[fg=#61afef] ✦${busy}#[default]"
[ "${idle:-0}" -gt 0 ] && out="${out}#[bg=#21252b]#[fg=#98c379] ✓${idle}#[default]"
[ -n "$out" ] && out="${out} "

printf '%s' "$out"
