#!/usr/bin/env bash
# ai-state.sh <busy|wait|idle|clear> —— 把当前 tmux pane 的 AI 状态发布出去。
#
# 给 Claude Code / qodercli 的 hooks 调用。写两处：
#   1. pane_title —— 唯一的"线格式"，三个展示面（window-status / choose-tree /
#      status-right）都只解析它。格式与 qodercli 原生输出保持完全一致，
#      这样一套解析逻辑同时覆盖两个 CLI。
#   2. @ai_state  —— 机器可读镜像，供 ai-status.sh 优先取用，也便于排错。
#      （实测该 pane 作用域选项在 window 作用域也能读到，所以将来若要给
#       tmux format 加快路径是可行的，目前没这个必要。）
#
# 铁律：无论如何 exit 0，绝不阻塞调用它的 CLI。
#
# 只给 Claude Code 用，**不要给 qodercli 挂 hooks**：qodercli 原生的 pane_title
# 带任务摘要（如「✦ AI status icons | Working」），在 choose-tree 里能直接看出那个
# 会话在干什么；本脚本只能写出「✦ qoder | Working」，会把摘要覆盖掉。
# 代价是 qodercli 的状态变化最多滞后一个 status-interval（2s），而 Claude 走 hook
# 会调 refresh-client 立即刷新。
set -u

# hook 通过 stdin 传 JSON。必须读掉，否则写入端可能拿到 EPIPE。
cat >/dev/null 2>&1

state="${1:-idle}"
label="${AI_STATE_LABEL:-AI}"

# 不在 tmux 里（裸终端 / CI）就什么都不做
[ -n "${TMUX_PANE:-}" ] || exit 0
command -v tmux >/dev/null 2>&1 || exit 0

# 下面三个字形刻意与 qodercli 原生 title 的语法一致，属于「线格式」，
# 不要改成显示层用的那套。显示层（tmux.conf 的 window-status / choose-tree、
# 以及 ai-status.sh）用的是 ⚑ / ✦ / ✓，两者独立：线格式只需要能被
# "| Working" 这类后缀匹配到，字形本身不参与判定。
# 特别是 idle 这里保持 ◇ 而非显示层的 ✓——choose-tree 会把原始 title 显示在
# 引号里，与 qodercli 的会话并排时字形一致更整齐。
case "$state" in
    busy)  title="✦ ${label} | Working" ;;
    wait)  title="▲ ${label} | Action Required" ;;
    idle)  title="◇ ${label} | Ready" ;;
    # clear：还原成主机名，与非 AI pane 一致，避免死会话虚增计数
    clear) title="$(tmux display -p '#{host_short}' 2>/dev/null || hostname)" ;;
    *)     exit 0 ;;
esac

# pane 可能已经死了 —— 下面每条都可能失败，静默吞掉
if [ "$state" = clear ]; then
    tmux set -p -t "$TMUX_PANE" -u @ai_state 2>/dev/null || exit 0
else
    tmux set -p -t "$TMUX_PANE" @ai_state "$state" 2>/dev/null || exit 0
fi
tmux select-pane -t "$TMUX_PANE" -T "$title" 2>/dev/null || exit 0

# 事件驱动地立刻重画状态栏，不必等 status-interval
tmux refresh-client -S 2>/dev/null || true
exit 0
