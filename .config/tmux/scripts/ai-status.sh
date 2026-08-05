#!/usr/bin/env bash
# ai-status.sh —— 由 status-right 经 #() 每 status-interval（2s）调用一次。两件事：
#   1. 输出全局三态计数，形如  ⚑2 ✦1 ✓3
#      没有 AI pane 时输出空串（状态栏退回原样，无占位符）
#   2. 把状态写进 tmux 选项，供三个展示面的 format 读取：
#        @ai_state（pane 作用域）—— 这个 pane 是 AI pane 且状态是 X
#        @ai_sess （会话作用域）—— 该会话内所有 pane 里最严重的那个状态
#
# 谁在什么状态由 ai-panes.sh 判定，本脚本只做计数和写回。
#
# 为什么状态要写进选项而不是让 format 直接读 pane_title：pane_title 是 CLI 自己
# 的地盘（Claude 运行时会不停改写它），我们插手就会互相覆盖、图标一闪一闪。
# @ai_state 只有本脚本写，没人能覆盖，代价是图标最多滞后一个 status-interval。
#
# 为什么会话聚合要在这里算：tmux 3.2a 的 format 无法遍历 pane，而在会话作用域
# 只能解析到活动 pane——会对「另一个窗口在等确认」的会话报错状态。本脚本反正
# 每 2 秒就要遍历一遍所有 pane，顺手聚合几乎零成本，比给 choose-tree 每行挂一个
# #() 便宜得多。
#
# 约束（违反任一条都会让状态栏坏掉）：
#   1. tmux 调用次数必须是常数 —— 每 pane 调一次会让开销随 pane 数线性增长。
#      所有写回用 \; 串成**一次**调用。
#   2. 绝不阻塞 —— 挂住时 tmux 会在状态栏显示 <'...' not ready>，所以不得有
#      sleep / 网络 / tmux wait-for，且每个 tmux 调用都要能失败退出
#   3. 只输出自己构造的数字和图标 —— #() 的输出会被 tmux 再解析一遍 #[...]，
#      若把任务摘要回显出去，摘要里的 #[ 会污染甚至被求值
#   4. 样式块写成 #[fg=X]#[bold] 分开的形式 —— 条件表达式内的 #[fg=X,bold]
#      会被逗号截断成 #[fg=X（实测）
set -u

command -v tmux >/dev/null 2>&1 || exit 0

dir="${0%/*}"; [ "$dir" = "$0" ] && dir=.
rows=$("$dir/ai-panes.sh" 2>/dev/null) || exit 0
[ -n "$rows" ] || exit 0

# 输出行的可变长字段（会话名）放在行尾，因为 shell 侧用 `read -r tag tok rest`
# 取，只有最后一个变量能吃空格。
parsed=$(printf '%s\n' "$rows" | awk -F'\t' '
  function rk(s) { return (s == "wait" ? 3 : (s == "busy" ? 2 : (s == "idle" ? 1 : 0))) }
  {
    state = $1; pid = $2; sess = $3; old = $4
    if (state != "") { c[state]++ }
    if (rk(state) > rank[sess]) { rank[sess] = rk(state) }
    seen[sess] = 1
    # 只在有变化时才写，稳态下一行输出都没有
    if (state != old) {
      if (state == "") { printf "PCLR %s -\n", pid }
      else             { printf "PSET %s %s\n", state, pid }
    }
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

# ---- 写回，全部串成一次 tmux 调用 ----
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
        PSET) add "set -p -t $(q "$rest") @ai_state $(q "$tok")" ;;
        PCLR) add "set -p -t $(q "$tok") -u @ai_state" ;;
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
