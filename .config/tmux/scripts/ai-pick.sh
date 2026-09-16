#!/usr/bin/env bash
# ai-pick.sh —— prefix + a 的 AI 会话选择器。跨所有 tmux 会话列出正在运行的
# qodercli / Claude，选中回车跳过去。
#
# 数据来自 ai-panes.sh（和状态栏共用同一份判定），这里只负责排版和跳转。
#
# 排序意图（照搬 craftzdog/tmux-claude-session-manager）：
#   ⚑ 等你确认  最前 —— 它被你卡着
#   ✓ 已就绪    其次 —— 答完了等你看
#   ⠋ 进行中    最后 —— 还在跑，不用管（帧跟着状态栏转，见下）
# 同级按「最后活动」由近到远。
#
# 为什么不用 display-popup：tmux 3.2a 的 popup 去不掉边框（-B 是 3.3 才有）。
# 调用方（tmux.conf 的 bind a）用 split-window -f + resize-pane -Z 开一个满屏
# zoom 的临时 pane，视觉上和 choose-tree -Z 一致。fzf 退出后 pane 自然消亡，
# zoom 解除、原布局恢复。
#
# 也因为跑在普通 pane 而不是 popup 里，当前 client 就是要切的那个 client，
# 不需要 craftzdog 那套「把宿主 client 名存进全局选项」+ popup 拆除竞态重试。
#
# ---- 列表是活的：--listen + 周期 reload ----
# fzf 的列表不会自己重绘，也没有行级更新；用 `--listen`（本机 unix socket）让一个
# 后台循环每 200ms 把预生成的行内容 `cat` 进 fzf（命令只剩 cat、以及 insert 态
# 暂停 reload 的原因，都实测过，见下面「实时刷新」一节的注释）：
#   - 「进行中」的帧在脚本里按 100ms 时间片本地取模（与 ai-spin.sh / 原生 #{A/…}
#     同一套规则），跟着状态栏一起转（列表 ~5FPS，状态栏 10Hz——这是重渲染节奏的
#     上限，不可能更平滑）。不读 @ai_spin：3.8 起 burst 只在 choose-tree 打开时
#     才跑，读选项会拿到冻帧
#   - age、⚑/✓ 状态、排序随之保鲜（picker 开着的这几秒里状态可能翻转）
#   - **insert（搜索）态暂停**：fzf 每次 reload 重绘输入行都会把光标藏一下再放出
#     （实测 ~19ms，肉眼即「搜索框一直闪」），搜索时冻结列表、esc 后恢复
# 光标必须 `--track --id-nth=3` 钉在 pane_id 字段上：reload 换的是整张表，只按
# 行号停的话排序一变（等确认置顶、age 变化）就选错了会话。实测（fzf 0.74）重排
# 后光标跟着 pane_id 走，查询词原样保留，insert 态打字不受 reload 影响。
# reload 用 async 版就够：命令只剩瞬时的 cat，不存在两次 reload 重叠的竞态
# （慢命令时代才需要 reload-sync 串行化，那反而拉长了 loading 窗口）。
# 这套需要 fzf 支持 --id-nth/--track（老版本没有），检测不到就整体退化成旧的
# 静态快照（少一个 listen 循环），功能不受损，只是帧冻在打开那一刻。
set -u

dir="${0%/*}"; [ "$dir" = "$0" ] && dir=.
# shellcheck source=fzf-common.sh
source "$dir/fzf-common.sh"

# ---- 数据渲染（--rows 模式与正常打开共用这份逻辑）----
#
# 状态列用固定宽度的字面量而不是 printf %-10s：mawk 按**字节**计宽，中文会算错。
# 三列都补到 10 个显示格（⚑⠋✓ 都是 East Asian Width = N，占 1 格）。
#
# 可见内容必须拼成**一个**字段：fzf 的 --with-nth 会用原始分隔符把字段拼回去，
# tab 按 8 列制表位展开，宽度全被吃掉、列也对不齐（踩过）。所以 TSV 只留三个
# 机器字段（rank / 活动时间戳 / pane_id），第 4 个字段是排好版的整行。
# --with-nth=4 同时也把模糊匹配限定在显示内容上，不会误匹配到 pane_id。
# pane_id 还是 reload 的身份字段（--id-nth=3），第 3 列的位置不能动。
#
# 排序键是**原始活动时间戳**（第 2 列，降序），不是格式化后的 age：sort -n 只认
# 前导数字，"16h" 会排在 " 39m" 前面，而 16 小时前明显更旧。
render_rows() {
    # 帧本地按 100ms 时间片取模（与 ai-spin.sh 同款规则，10 帧 = 1s 一圈）：不读
    # @ai_spin——3.8 起 burst 只在 choose-tree 打开时才跑，读选项会拿到冻帧；本地算
    # 则任何时候打开 picker 都在转，且与 burst / 原生 A 的取值同源于时钟
    local spin
    case "$(( $(date +%s%N) / 100000000 % 10 ))" in
        0) spin=⠋ ;; 1) spin=⠙ ;; 2) spin=⠹ ;; 3) spin=⠸ ;; 4) spin=⠼ ;;
        5) spin=⠴ ;; 6) spin=⠦ ;; 7) spin=⠧ ;; 8) spin=⠇ ;; *) spin=⠏ ;;
    esac
    "$dir/ai-panes.sh" 2>/dev/null | awk -F'\t' -v OFS='\t' \
        -v now="$(date +%s)" -v home="$HOME" -v spin="$spin" '
  $1 != "" {
    if ($1 == "wait")      { rank = 0; icon = "\033[38;5;180m⚑ 等你确认\033[0m" }
    else if ($1 == "idle") { rank = 1; icon = "\033[38;5;114m✓ 已就绪  \033[0m" }
    else                   { rank = 2; icon = "\033[38;5;75m" spin " 进行中  \033[0m" }

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
' | sort -t"$(printf '\t')" -k1,1n -k2,2nr
}

# reload 循环反复调的就是这个模式；此时不碰 fzf 本身（省一次 fzf --version fork）
[ "${1:-}" = "--rows" ] && { render_rows; exit 0; }

fzf_require 0.59 "prefix+a" || exit 0

rows=$(render_rows)
[ -n "$rows" ] || { tmux display-message "没有正在运行的 AI 会话"; exit 0; }

# ---- 实时刷新：fzf --listen 的后台 reload 循环 ----
# 两个都已实测的坑，别踩回去：
#   1. reload 一律用预生成的 rowsfile（命令只剩 `cat`）。生成（~40ms）直接塞进
#      reload 命令的话，fzf 每次执行都要等，loading 窗口拉长（实测隐藏光标 38ms）。
#   2. **insert（搜索）态暂停 reload**：fzf 每次 reload 重绘输入行时都会把终端
#      光标藏一下再放出来（哪怕命令只剩 cat，窗口 ~19ms——一条 60Hz 帧，肉眼就是
#      「搜索框一直闪」）。insert 态下冻结列表（等价于原版 fzf 的静态体验），esc
#      回 normal 后恢复；normal 态光标本来就不显示，动画与光标互不相干。
# insert 态标记：a/i// 的绑定 touch 它、esc 的绑定 rm 它，loop 里据此暂停。
# 定义放在 if 外：绑定字符串无条件引用它（非 live 时只是没人看的空文件）
insertflag="${TMPDIR:-/tmp}/tmux-ai-pick-$$.insert"
live_args=()
refresh_pid=""; sock=""; rowsfile=""
if command -v curl >/dev/null 2>&1 && fzf --help 2>/dev/null | grep -q -- '--id-nth'; then
    sock="${TMPDIR:-/tmp}/tmux-ai-pick-$$.sock"
    rowsfile="${TMPDIR:-/tmp}/tmux-ai-pick-$$.rows"
    rm -f "$sock" "$insertflag"
    # socket 只在本机，但 key 顺手挡掉同机其它进程乱发动作；每个 picker 一把。
    # 熵源只用 bash 内建（$RANDOM ×3 + pid）——macOS 没有 md5sum/%N，别引外部命令
    export FZF_API_KEY="$$-${RANDOM}${RANDOM}-${RANDOM}"
    live_args=(--track --id-nth=3 --listen="$sock")
    printf '%s\n' "$rows" > "$rowsfile"
    (
        while [ ! -S "$sock" ]; do sleep 0.05; done   # 等 fzf 建出 socket
        while :; do
            sleep 0.2
            [ -e "$insertflag" ] && continue          # 搜索态：冻结列表，别动光标
            # 生成失败/为空就保留上一版（空列表比旧数据更糟）；mv 保证 fzf 要么
            # 读到旧文件要么读到新文件，不会读到写一半的
            render_rows > "$rowsfile.tmp" 2>/dev/null
            [ -s "$rowsfile.tmp" ] && mv "$rowsfile.tmp" "$rowsfile"
            # curl 失败 = fzf 已退出，直接收工（socket 没了/拒绝连接），无需握手
            curl -s --max-time 2 -H "X-API-Key: $FZF_API_KEY" \
                --unix-socket "$sock" -XPOST http://localhost \
                -d "reload(cat $rowsfile)" >/dev/null 2>&1 || break
        done
    ) &
    refresh_pid=$!
fi
cleanup() {
    [ -n "$refresh_pid" ] && kill "$refresh_pid" 2>/dev/null
    [ -n "$sock" ] && rm -f "$sock"
    [ -n "$rowsfile" ] && rm -f "$rowsfile" "$rowsfile.tmp"
    [ -n "$insertflag" ] && rm -f "$insertflag"
}
trap cleanup EXIT

# vim 双模式。核心是 --no-input：输入区直接隐藏，敲的键只能触发绑定、不会进查询框，
# 这本身就是 normal 模式。但**还必须配 unbind/rebind**：进 insert 后 j/k 若仍绑着
# down/up，就打不出 "j" 这个字符了（上游 CHANGELOG 的 0.59.0 示例正是这么写的）。
#
# esc 不再是退出，而是回 normal（normal 下按它是空操作，和 vim 一致）；退出走 q 和 ctrl-c。
# esc 的动作顺序有讲究：clear-query **必须**排在 hide-input 前面，否则输入区一藏起来，
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
    "${FZF_THEME[@]}" \
    --ansi \
    --delimiter="$(printf '\t')" \
    --with-nth=4 \
    --layout=reverse-list --header-first --info=inline --no-separator \
    --cycle --tiebreak=index \
    --no-input \
    ${live_args[@]+"${live_args[@]}"} \
    --prompt='搜索 ' \
    --header="$hint_normal" \
    --bind='j:down,k:up,g:first,G:last' \
    --bind="a:$to_insert+execute-silent(touch $insertflag)" \
    --bind="i:$to_insert+execute-silent(touch $insertflag)" \
    --bind="/:$to_insert+execute-silent(touch $insertflag)" \
    --bind="esc:clear-query+hide-input+rebind($vim_keys)+change-header($hint_normal)+execute-silent(rm -f $insertflag)" \
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
