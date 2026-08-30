#!/usr/bin/env bash
# config-pick.sh —— prefix + c 的配置文件选择器。
# 浮窗（display-popup）里 fzf 列出常用配置文件：j/k 上下移动、回车用 nvim
# 打开（nvim 仍在该浮窗内，退出后浮窗自动消失）、Esc 取消。
# 运行在 tmux display-popup 中；外框样式由 tmux.conf 统一设置，内部 fzf 样式来自
# fzf-common.sh。键位仍由本脚本管理：j/k 移动，a 搜索，Enter 用 nvim 打开。
set -u

dir="${0%/*}"; [ "$dir" = "$0" ] && dir=.
# shellcheck source=fzf-common.sh
source "$dir/fzf-common.sh"
fzf_require 0.59 "prefix+c" || exit 0
command -v nvim >/dev/null 2>&1 || { tmux display-message "prefix+c 需要 nvim"; exit 0; }

# ── 候选生成：动态扫描，不硬编码 ────────────────────────────
# 三条规则并集（sort -u 去重）：
#   1. ~ 下所有点开头文件，以及隐藏目录里的一层文件（.ssh/config、
#      .claude/settings.json、.config/xxx/yyy 都会进来）
#   2. ~/.config 递归（≤4 层）里配置后缀的文件（toml/yml/yaml/json/
#      lua/rc/ini/cfg/conf/sh/zsh/plist/txt）
#   3. ~/dotfiles 仓库根下的直接配置文件（iterm2.json 等，容易被前两条漏掉）
# 排除：node_modules/.git/lazy（nvim 插件树）/cache/logs/sockets 等运行时目录。
home="$HOME"
# 注意：路径匹配是字面量——隐藏目录要写全（*/.cache/*，不是 */cache/*）
excl=(
  -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/lazy/*"
  -not -path "*/AppSupport/*" -not -path "*/sockets/*" -not -path "*/.cache/*"
  -not -path "*/logs/*" -not -path "*/store/*" -not -path "*/icons/*"
  -not -path "*/helpers/*" -not -path "*/target/*" -not -path "*/com.nvidia*"
  -not -path "*/NVIDIA*" -not -path "*/assets/*" -not -path "*/themes/*"
  -not -path "*/.conda/*" -not -path "*/.labuladong/*" -not -path "*.bak/*"
  -not -path "*/.oh-my-zsh/*" -not -path "*/.npm/*" -not -path "*/anaconda3/*"
  -not -path "*/.zsh_sessions/*" -not -name ".DS_Store" -not -name ".localized"
  -not -name ".CFUserTextEncoding" -not -name "*.zwc" -not -name "package*.json"
  -not -name ".claude.json" -not -name ".anonymous-*" -not -name ".lesshst"
  -not -name ".zcompdump*" -not -name ".wget-hsts" -not -name ".viminfo"
  -not -name ".netrwhist" -not -name ".python_history" -not -name "known_hosts*"
  -not -name ".zsh_history" -not -name ".git" -not -name ".last-*"
)
cfgsuf=( -name "*.toml" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json"
  -o -name "*.lua" -o -name "*.rc" -o -name "*.ini" -o -name "*.cfg"
  -o -name "*.conf" -o -name "*.sh" -o -name "*.zsh" -o -name "*.plist"
  -o -name "*.txt" )

list=$({
  # 1) 点文件 + 隐藏目录一层
  find -L "$home" -maxdepth 2 -type f \( -name ".*" -o -path "$home/.[^/]*/*" \) "${excl[@]}" 2>/dev/null
  # 2) .config 递归（-L：nvim/tmux 等目录是指向 dotfiles 的符号链接，默认不跟随）
  find -L "$home/.config" -maxdepth 4 -type f \( "${cfgsuf[@]}" \) "${excl[@]}" 2>/dev/null
  # 3) dotfiles 仓库根
  find -L "$home/dotfiles" -maxdepth 1 -type f 2>/dev/null
} | sort -u)

# 显示名用 ~ 相对路径；实际路径留第二列，preview/打开时还原
files=()
while IFS= read -r f; do
  files+=("${f/#$home/\~}"$'\t'"$f")
done <<< "$list"

[ "${#files[@]}" -eq 0 ] && { tmux display-message "没有找到可用的配置文件"; exit 0; }

# --no-input：默认 normal 模式（不进入输入框），q 退出、j/k 上下移动、
# a 进入插入模式直接查询。进输入模式时 unbind 掉 j/k/a/q（否则这些键在
# 输入模式也触发绑定、打不出字母），Esc 时按 FZF_INPUT_STATE 判断：
# 输入模式 → rebind + 回 normal（查询保留）；normal → abort。
# 模式切换写法来自 fzf 官方 changelog 的 vim-like mode switch 示例。
# Enter 用 fzf 默认（所有模式下都 accept，直接打开选中项）。
# 样式跟随 tmux 的 one-dark 主题（#61afef 蓝 / #e5c07b 金 / #98c379 绿），
# 右侧 preview 用 nl 带行号预览文件内容（没有 bat，不额外装依赖）。
choice=$(printf '%s\n' "${files[@]}" | fzf \
    "${FZF_POPUP_LAYOUT[@]}" \
    "${FZF_THEME[@]}" \
    --with-nth=1 --delimiter=$'\t' \
    --no-input \
    --bind 'j:down,k:up,q:abort,a:show-input+unbind(j,k,a,q)' \
    --bind 'esc:transform:
      if [[ $FZF_INPUT_STATE = enabled ]]; then
        echo "rebind(j,k,a,q)+hide-input"
      else
        echo abort
      fi' \
    --ansi \
    --input-border=rounded --input-label=' 搜索 ' --input-label-pos=2 \
    --list-border=rounded --list-label=' 配置 · j/k 移动 · Enter 打开 · a 搜索 · q 退出 ' --list-label-pos=2 \
    --prompt '⚙ ' \
    --preview 'p=$(printf "%s" {} | cut -f2); [ -f "$p" ] && nl -ba "$p" | head -n 50' \
    --preview-window 'right:45%,border-rounded' \
    --no-multi)

[ -z "$choice" ] && exit 0

file=${choice#*$'\t'}
# exec 让 nvim 成为浮窗里的前台进程，退出 nvim 浮窗自动消失
exec nvim "$file"