#!/usr/bin/env bash
# ai-pick.sh —— prefix + a 的 AI 会话选择器。跨所有 tmux 会话列出正在运行的
# qodercli / Claude，选中回车跳过去。
#
# 数据来自 ai-panes.sh（和状态栏共用同一份判定），这里只负责排版和跳转。
#
# 排序意图（照搬 craftzdog/tmux-claude-session-manager）：
#   ⚑ 等你确认  最前 —— 它被你卡着
#   ✓ 已就绪    其次 —— 答完了等你看
#   ✦ 进行中    最后 —— 还在跑，不用管
# 同级按「最后活动」由近到远。
#
# 为什么不用 display-popup：tmux 3.2a 的 popup 去不掉边框（-B 是 3.3 才有）。
# 调用方（tmux.conf 的 bind a）用 split-window -f + resize-pane -Z 开一个满屏
# zoom 的临时 pane，视觉上和 choose-tree -Z 一致。fzf 退出后 pane 自然消亡，
# zoom 解除、原布局恢复。
#
# 也因为跑在普通 pane 而不是 popup 里，当前 client 就是要切的那个 client，
# 不需要 craftzdog 那套「把宿主 client 名存进全局选项」+ popup 拆除竞态重试。
set -u

dir="${0%/*}"; [ "$dir" = "$0" ] && dir=.

# vim 模式要 fzf >= 0.59（--no-input / show-input / hide-input 是那版引入的）。
# 版本太老时 fzf 只吐一句参数错误就退出、pane 瞬间关掉，等于静默失败，所以显式挡住。
# 注意 apt 上的 Ubuntu 22.04 只有 0.29，必须装上游二进制，见 AGENTS.md。
command -v fzf >/dev/null 2>&1 || {
    tmux display-message "prefix+a 需要 fzf >= 0.59（apt 的 0.29 不够，见 AGENTS.md）"
    exit 0
}
# 0.74.2 -> 74；0.29 -> 29；将来的 1.2 -> 1002。取前两段做数值比较即可。
fzf_ver=$(fzf --version 2>/dev/null | awk -F'[. ]' '{print $1 * 1000 + $2; exit}')
[ "${fzf_ver:-0}" -ge 59 ] || {
    tmux display-message "fzf 版本过低（$(fzf --version 2>/dev/null | awk '{print $1}')），vim 模式需要 >= 0.59，见 AGENTS.md"
    exit 0
}

# 别让用户将来的全局 fzf 配置（--height / --tmux 之类）搞坏这个界面
export FZF_DEFAULT_OPTS=''

# 状态列用固定宽度的字面量而不是 printf %-10s：mawk 按**字节**计宽，中文会算错。
# 三列都补到 10 个显示格（⚑✦✓ 都是 East Asian Width = N，占 1 格）。
#
# 可见内容必须拼成**一个**字段：fzf 的 --with-nth 会用原始分隔符把字段拼回去，
# tab 按 8 列制表位展开，宽度全被吃掉、列也对不齐（踩过）。所以 TSV 只留三个
# 机器字段（rank / 活动时间戳 / pane_id），第 4 个字段是排好版的整行。
# --with-nth=4 同时也把模糊匹配限定在显示内容上，不会误匹配到 pane_id。
#
# 排序键是**原始活动时间戳**（第 2 列，降序），不是格式化后的 age：sort -n 只认
# 前导数字，"16h" 会排在 " 39m" 前面，而 16 小时前明显更旧。
rows=$("$dir/ai-panes.sh" 2>/dev/null | awk -F'\t' -v OFS='\t' \
    -v now="$(date +%s)" -v home="$HOME" '
  $1 != "" {
    if ($1 == "wait")      { rank = 0; icon = "\033[38;5;180m⚑ 等你确认\033[0m" }
    else if ($1 == "idle") { rank = 1; icon = "\033[38;5;114m✓ 已就绪  \033[0m" }
    else                   { rank = 2; icon = "\033[38;5;75m✦ 进行中  \033[0m" }

    mins = ($6 > 0) ? int((now - $6) / 60) : -1
    if      (mins < 0)    { age = "   -" }
    else if (mins < 60)   { age = sprintf("%3dm", mins) }
    else if (mins < 2400) { age = sprintf("%3dh", int(mins / 60)) }
    else                  { age = sprintf("%3dd", int(mins / 1440)) }

    cwd = $7
    if (index(cwd, home) == 1) { cwd = "~" substr(cwd, length(home) + 1) }
    # 太长就砍掉开头留尾部——尾部那几级目录才是有信息量的
    if (length(cwd) > 24) { cwd = "..." substr(cwd, length(cwd) - 20) }

    print rank, $6 + 0, $2, \
      sprintf("%s %s  %-12s %-24s %s", icon, age, $5, cwd, $8)
  }
' | sort -t"$(printf '\t')" -k1,1n -k2,2nr)

[ -n "$rows" ] || { tmux display-message "没有正在运行的 AI 会话"; exit 0; }

# vim 双模式。核心是 --no-input：输入区直接隐藏，敲的键只能触发绑定、不会进查询框，
# 这本身就是 normal 模式。但**还必须配 unbind/rebind**：进 insert 后 j/k 若仍绑着
# down/up，就打不出 "j" 这个字符了（上游 CHANGELOG 的 0.59.0 示例正是这么写的）。
#
# esc 不再是退出，而是回 normal（normal 下按它是空操作，和 vim 一致）；退出走 q 和 ctrl-c。
# esc 的动作顺序有讲究：clear-query **必须**排在 hide-input 前面，否则输入区一藏起来
# 查询变更就不再触发重新过滤，回到 normal 时列表还停在过滤后的结果上（实测）。
#
# 布局 --layout=reverse-list --header-first --info=inline：列表从顶部往下，
# 提示符+计数在倒数第二行、按键提示钉在最后一行，都左对齐。
# 进 insert 时输入行才出现，布局往上顶一行，提示始终在最后。
vim_keys='j,k,g,G,a,i,/,q'
hint_normal='j/k 移动 · a 搜索 · enter 跳转 · q 退出'
hint_insert='esc 回浏览 · enter 跳转'
to_insert="show-input+unbind($vim_keys)+change-header($hint_insert)"

# {3} 是 pane_id（原始行的字段，不受 --with-nth 影响），喂给预览的 capture-pane；
# -e 保留对方自己的颜色
# --tiebreak=index：打分相同时保持上面排好的顺序
sel=$(printf '%s\n' "$rows" | fzf \
    --ansi \
    --delimiter="$(printf '\t')" \
    --with-nth=4 \
    --layout=reverse-list --header-first --info=inline --no-separator \
    --cycle --tiebreak=index \
    --no-input \
    --prompt='搜索 ' \
    --header="$hint_normal" \
    --bind='j:down,k:up,g:first,G:last' \
    --bind="a:$to_insert" \
    --bind="i:$to_insert" \
    --bind="/:$to_insert" \
    --bind="esc:clear-query+hide-input+rebind($vim_keys)+change-header($hint_normal)" \
    --bind='q:abort' \
    --preview='tmux capture-pane -ept {3}' \
    --preview-window='right,50%,follow') || exit 0

[ -n "$sel" ] || exit 0

pane=$(printf '%s' "$sel" | cut -f3)
[ -n "$pane" ] || exit 0

# 顺序要紧：先把 client 切到目标会话，再选窗口和 pane。
# 目标可能就在当前会话/窗口里，这三步都是幂等的。
sess=$(tmux display -pt "$pane" '#{session_name}' 2>/dev/null) || exit 0
tmux switch-client -t "$sess" 2>/dev/null
tmux select-window -t "$pane" 2>/dev/null
tmux select-pane -t "$pane" 2>/dev/null
