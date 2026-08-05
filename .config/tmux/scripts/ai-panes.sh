#!/usr/bin/env bash
# ai-panes.sh —— 枚举所有 tmux pane 并判定 AI 状态。纯数据，不做任何展示。
#
# 输出 TSV，一行一个 pane，**包括非 AI 的** —— ai-status.sh 要靠它们清理陈旧的
# @ai_state，也要靠它们知道有哪些会话（会话至少有一个 pane）：
#
#   state ⇥ pane_id ⇥ sess ⇥ old ⇥ loc ⇥ activity ⇥ cwd ⇥ summary
#
#   state     wait|busy|idle；非 AI pane 为空
#   old       该 pane 当前的 @ai_state（上一轮我们写的），用来判断要不要改
#   loc       session:window.pane
#   activity  #{window_activity}，epoch 秒；age 由调用方自己算
#   summary   CLI 自己写的 pane_title（剥掉状态后缀和前导字形），空则退回目录名
#
# 消费者：
#   ai-status.sh —— 三态计数、@ai_sess 会话聚合、@ai_state 写入与清理
#   ai-pick.sh   —— prefix + a 的选择器
#
# 状态来源：
#   Claude    ~/.claude/sessions/<pid>.json（Claude 自己 UI 状态的镜像）→ pid → tty → pane
#   qodercli  它原生写在 pane_title 里的 "| Working" / "| Action Required" / "| Ready"
#
# **我们不写 pane_title。** 曾经给 Claude 合成过标题，但 Claude 自己也在写标题
# （设置项 terminalTitleFromRename），两边每 2 秒互相覆盖，底部标签的图标就一闪
# 一闪（踩过）。标题完全归 CLI 所有，我们只写自己的 @ai_state。
#
# 约束：tmux 调用次数必须是常数（一次 list-panes），且绝不阻塞——本脚本在
# status-interval 的路径上，挂住会让状态栏显示 <'...' not ready>。
set -u

command -v tmux >/dev/null 2>&1 || exit 0

claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# ---- Claude Code: sessions/*.json -> "tty 状态 目录名" ----
#
# 每个交互式 Claude 进程写一个 <pid>.json，正常退出时自删。字段：
#   pid / status(idle|busy|waiting) / procStart / cwd
# procStart 实测就是 /proc/<pid>/stat 的第 22 字段（starttime，时钟节拍），
# 拿它做 pid 复用的判据：进程没了或 starttime 不对，就是陈文件，丢掉。
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
    gsub(/[^A-Za-z0-9._-]/, "", base)
    printf "/dev/pts/%d %s %s\n", min, st, base
  }
  FNR == 1 && buf != "" { emit(buf); buf = "" }
  { buf = buf $0 }
  END { if (buf != "") emit(buf) }
' "$claude_dir"/sessions/*.json 2>/dev/null)

# ---- 遍历所有 pane ----
#
# 用 ~ 作字段分隔符：pane_title 里不会出现（qodercli 用的是 " | "）。
# pane_title 放最后，它内容最不可控。
panes=$(tmux list-panes -a -F '#{session_name}#{l:~}#{pane_id}#{l:~}#{pane_tty}#{l:~}#{@ai_state}#{l:~}#{host_short}#{l:~}#{window_index}#{l:~}#{pane_index}#{l:~}#{window_activity}#{l:~}#{pane_current_path}#{l:~}#{pane_title}' 2>/dev/null) || exit 0
[ -n "$panes" ] || exit 0

printf '%s\n' "$panes" | awk -F'~' -v OFS='\t' -v cmap="$claude_states" '
  function rk(s) { return (s == "wait" ? 3 : (s == "busy" ? 2 : (s == "idle" ? 1 : 0))) }
  BEGIN {
    n = split(cmap, L, "\n")
    for (i = 1; i <= n; i++) {
      if (split(L[i], A, " ") < 2) { continue }
      # 同一 tty 上有多个 Claude（嵌套）时取最严重的
      if (rk(A[2]) > crank[A[1]]) { crank[A[1]] = rk(A[2]); cst[A[1]] = A[2]; cdir[A[1]] = A[3] }
    }
  }
  {
    sess = $1; pid = $2; tty = $3; old = $4; hn = $5
    widx = $6; pidx = $7; act = $8; cwd = $9; title = $10

    if (tty in cst) {
      state = cst[tty]
    } else {
      # 匹配带竖线的 "| Working" 而非裸 Working：任务摘要里含该词不会误判
      if      (title ~ /\| Action Required/) { state = "wait" }
      else if (title ~ /\| Working/)         { state = "busy" }
      else if (title ~ /\| Ready/)           { state = "idle" }
      else                                   { state = "" }
    }

    # 摘要：CLI 自己的标题，剥掉尾部空白、状态后缀、和一个前导状态字形。
    # 字形必须显式列举：mawk 的 [^ ] 只匹配单个**字节**，而这些字形是 3 字节
    # UTF-8，写 /^[^ ] / 匹配不到；写 /^[^ ]+ / 又会误删标题里真正的第一个词。
    sum = title
    sub(/[ \t]+$/, "", sum)
    sub(/ \| (Working|Ready|Action Required)$/, "", sum)
    sub(/^(◇|✦|▲|✳|✻) /, "", sum)
    if (sum == "" || sum == hn) {
      sum = cwd; sub(/.*\//, "", sum)
      if (sum == "") { sum = "/" }
    }
    gsub(/[\t\r]/, " ", sum)

    print state, pid, sess, old, sess ":" widx "." pidx, act, cwd, sum
  }
'
