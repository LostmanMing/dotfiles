#!/usr/bin/env bash
# ai-spin.sh —— busy 图标的动画 ticker。短命 burst，不是守护进程。
#
# 为什么需要它：状态栏只按 status-interval（tmux 下限 1s）自动重绘，1s 才换一帧的
# 动画观感很卡。实测 refresh-client -S 能**立即**让 format 重新展开，且**不会**重跑
# #()（聚合脚本仍按 status-interval 走）。所以本脚本只做「换帧 + 强制重绘状态栏」，
# 判定与计数仍全部归 ai-status.sh / ai-panes.sh。
#
# 生命周期：由 ai-status.sh 用 `flock -n` 按需拉起，一轮跑 ~2.5s（盖住 2s 的
# status-interval，不留动画空档）后自己退出；期间每 0.8s 查一次 @ai_busy，归零就提前
# 收工。没有守护进程、没有 pid 文件——flock 保证同一时刻只有一个 burst（多客户端时
# 每个客户端的 status-right 都会跑聚合脚本，没有锁会起一堆）。
# 拉起条件（在 ai-status.sh 里）：3.8+ 只在有 busy **且开着 choose-tree**（该 server
# 有 tree-mode 的 pane）时需要——状态行动画已交给 tmux 原生 #{A/…}；旧 server 仍是
# busy>0 就拉（状态行还读 @ai_spin）。
#
# 帧：经典圆点 spinner（⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏，等同 nvim/lualine 那套；U+28xx，
# East Asian Width = N，单格宽）。由 100ms 时间片取模，不是自增——多个 burst 接力时
# 也不跳帧，10 帧正好 1s 一圈。ai-status.sh 的窗口后缀、右侧计数与本脚本同源同时刻
# 取同一帧，所以两处永远同步。
#
# 为什么不用四象限 braille（⣾⣽⣻⢿）：那是实心半格，在状态栏里显得又高又重；
# 圆点集只画外圈几个点，视觉上小巧，和 nvim 的 LSP loading 图标一致。
#
# 顺带效果：-S 触发的状态栏重绘也会让开着的前台 mode 重建（tmux 在状态栏重绘时
# 顺带跑可见 mode 的 update 钩子），所以 prefix+s/w 的 choose-tree 里帧跟着转；
# prefix+a 的 fzf 列表借不到这条路，由 ai-pick.sh 自己的 --listen reload 保活。
set -u

command -v tmux >/dev/null 2>&1 || exit 0

clients=$(tmux list-clients -F '#{client_name}' 2>/dev/null) || exit 0
[ -n "$clients" ] || exit 0

i=0
while :; do
    case "$(( $(date +%s%N) / 100000000 % 10 ))" in
        0) f=⠋ ;; 1) f=⠙ ;; 2) f=⠹ ;; 3) f=⠸ ;; 4) f=⠼ ;;
        5) f=⠴ ;; 6) f=⠦ ;; 7) f=⠧ ;; 8) f=⠇ ;; *) f=⠏ ;;
    esac

    cmd="set -g @ai_spin '$f'"
    for c in $clients; do
        cmd="$cmd ';' refresh-client -S -t '$c'"
    done
    eval "tmux $cmd" 2>/dev/null || exit 0

    i=$((i + 1))
    # 每 8 个时间片（0.8s）看一次还有没有 busy；归零立即收工，不空转
    if [ "$((i % 8))" -eq 0 ]; then
        busy=$(tmux show -gv @ai_busy 2>/dev/null) || exit 0
        case "$busy" in ''|0|*[!0-9]*) exit 0 ;; esac
    fi
    [ "$i" -ge 24 ] && exit 0
    sleep 0.1
done
