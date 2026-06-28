#!/bin/bash
set -e

echo "=== 安装 Aerospace + Sketchybar 依赖 ==="

# --- Homebrew taps ---
brew tap FelixKratz/formulae 2>/dev/null || true

# --- 核心应用 ---
echo ">> 安装 sketchybar + aerospace..."
brew install sketchybar
brew install --cask aerospace

# --- 运行时依赖 ---
echo ">> 安装运行时依赖..."
brew install lua switchaudio-osx blueutil jq

# --- 温度传感器 ---
echo ">> 安装 smctemp..."
brew tap narugit/tap 2>/dev/null || true
brew install narugit/tap/smctemp
mkdir -p ~/.local/bin/smctemp
ln -sf "$(brew --prefix)/bin/smctemp" ~/.local/bin/smctemp/smctemp

# --- 字体 ---
echo ">> 安装字体..."
brew install --cask sf-symbols font-sf-mono font-sf-pro 2>/dev/null || true

# sketchybar-app-font（工作区图标）
FONT_URL="https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v2.0.28/sketchybar-app-font.ttf"
if [ ! -f ~/Library/Fonts/sketchybar-app-font.ttf ]; then
  curl -L "$FONT_URL" -o ~/Library/Fonts/sketchybar-app-font.ttf
fi

# --- SbarLua（Lua API 桥接） ---
echo ">> 安装 SbarLua..."
if [ ! -f ~/.local/share/sketchybar_lua/sketchybar.so ]; then
  git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua
  cd /tmp/SbarLua && make install && rm -rf /tmp/SbarLua
fi

# --- 编译 event_providers ---
echo ">> 编译 event_providers..."
CONFIG_DIR="$HOME/.config/sketchybar"
if [ ! -f "$CONFIG_DIR/helpers/event_providers/cpu_load/bin/cpu_load" ]; then
  cd "$CONFIG_DIR/helpers/event_providers" && make
  cd cpu_load && make
  cd ../network_load && make
  cd "$HOME"
fi

# --- 配置软链 ---
echo ">> 链接配置..."
mkdir -p ~/.config
ln -sf ~/dotfiles/.config/sketchybar ~/.config/sketchybar
ln -sf ~/dotfiles/.config/aerospace ~/.config/aerospace

# --- 启动 ---
echo ">> 启动服务..."
brew services restart sketchybar
open /opt/homebrew/Caskroom/aerospace/*/AeroSpace-*/AeroSpace.app 2>/dev/null || true

echo ""
echo "=== 安装完成 ==="
echo "sketchybar --query bar   检查 bar 状态"
echo "aerospace list-workspaces --all   检查 aerospace 状态"
