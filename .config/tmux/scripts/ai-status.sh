#!/usr/bin/env bash
# ai-status.sh —— 汇总所有 session 里 AI CLI pane 的状态。两个用途：
#   1. 输出全局计数给 status-right（由 #() 调用），形如  ⚑2 ✦1 ✓3
#      没有 AI pane 时输出空串（状态栏退回原样，无占位符）
#   2. 顺带把每个会话的聚合状态写进会话作用域选项 @ai_sess，
#      供 prefix+s（choose-tree -Zs，只显示会话行）读取
#
# 为什么会话状态要靠这里算：tmux 3.2a 的 format 无法遍历 pane，而 #{pane_title}
# 在会话作用域只解析到活动 pane——会对「另一个窗口在等确认」的会话报错状态。
# 本脚本反正每 status-interval 就要遍历一遍所有 pane，顺手聚合几乎零成本，
# 比给 choose-tree 每行挂一个 #() 便宜得多。
#
# 状态来源优先级：@ai_state（hook 写入，权威） > pane_title（qodercli 原生发布）
# 会话聚合取最严重的一个：wait > busy > idle
#
# 约束（违反任一条都会让状态栏坏掉）：
#   1. tmux 调用次数必须是常数 —— 每 pane 调一次会让开销随 pane 数线性增长。
#      写回会话选项时把所有 set 用 \; 串成**一次**调用。
#   2. 绝不阻塞 —— 挂住时 tmux 会在状态栏显示 <'...' not ready>，所以不得有
#      sleep / 网络 / tmux wait-for，且每个 tmux 调用都要能失败退出
#   3. 只输出自己构造的数字和图标 —— #() 的输出会被 tmux 再解析一遍 #[...]，
#      若把任务摘要回显出去，摘要里的 #[ 会污染甚至被求值
#   4. 样式块写成 #[fg=X]#[bold] 分开的形式 —— 条件表达式内的 #[fg=X,bold]
#      会被逗号截断成 #[fg=X（实测）
set -u

command -v tmux >/dev/null 2>&1 || exit 0

# 用 ~ 作字段分隔符：pane_title 里不会出现（qodercli 用的是 " | "）
panes=$(tmux list-panes -a -F '#{session_name}#{l:~}#{@ai_state}#{l:~}#{pane_title}' 2>/dev/null) || exit 0
[ -n "$panes" ] || exit 0

# 一次 awk 同时算出：全局三态计数 + 每会话聚合状态
parsed=$(printf '%s\n' "$panes" | awk -F'~' '
  {
    sess = $1
    s = $2
    if (s == "") {
      # 匹配带竖线的 "| Working" 而非裸 Working：任务摘要里含该词不会误判
      if      ($3 ~ /\| Action Required/) s = "wait"
      else if ($3 ~ /\| Working/)         s = "busy"
      else if ($3 ~ /\| Ready/)           s = "idle"
      else                                s = "none"
    }
    c[s]++
    if (s != "none") {
      # 会话取最严重的：wait(3) > busy(2) > idle(1)
      r = (s == "wait" ? 3 : (s == "busy" ? 2 : 1))
      if (r > rank[sess]) { rank[sess] = r }
    }
    seen[sess] = 1
  }
  END {
    printf "COUNT %d %d %d\n", c["wait"]+0, c["busy"]+0, c["idle"]+0
    for (s in seen) {
      st = (rank[s] == 3 ? "wait" : (rank[s] == 2 ? "busy" : (rank[s] == 1 ? "idle" : "")))
      printf "SESS %s %s\n", s, st
    }
  }
')

read -r _ wait busy idle <<EOF
$(printf '%s\n' "$parsed" | grep '^COUNT ')
EOF

# 把每会话状态写回会话选项，全部串成一次 tmux 调用。
# 用 POSIX 写法而非 bash 数组：这个脚本曾被 status-right 写成 #(sh .../ai-status.sh)
# 调用，而 /bin/sh 是 dash，`cmd=()` 直接语法错误退出、状态栏静默空白且不报错。
# 现在 status-right 已改成直接调（走 shebang 的 bash），但保持 POSIX 兼容更稳。
# 会话名可能含空格或单引号，所以用 eval + 单引号转义。
# 空状态必须用 -u 取消而不是传空值——set 缺少值参数会报错，而命令是串联的，
# 一条失败会让整条全部失败（踩过）。
cmd=''
while read -r _ sess st; do
    [ -n "$sess" ] || continue
    q=$(printf '%s' "$sess" | sed "s/'/'\\\\''/g")
    [ -n "$cmd" ] && cmd="$cmd ';'"
    if [ -n "$st" ]; then
        cmd="$cmd set -t '$q' @ai_sess '$st'"
    else
        cmd="$cmd set -t '$q' -u @ai_sess"
    fi
done <<EOF
$(printf '%s\n' "$parsed" | grep '^SESS ')
EOF
[ -n "$cmd" ] && eval "tmux $cmd" 2>/dev/null || true

out=""
# ⚑ 等你确认：反色黄块，整条状态栏上最醒目的元素
[ "${wait:-0}" -gt 0 ] && out="${out}#[fg=#21252b]#[bg=#e5c07b]#[bold] ⚑${wait} #[default]"
[ "${busy:-0}" -gt 0 ] && out="${out}#[bg=#21252b]#[fg=#61afef] ✦${busy}#[default]"
[ "${idle:-0}" -gt 0 ] && out="${out}#[bg=#21252b]#[fg=#98c379] ✓${idle}#[default]"
[ -n "$out" ] && out="${out} "

printf '%s' "$out"
