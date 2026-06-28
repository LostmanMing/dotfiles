# SketchyBar — 配置说明

## 布局概览

```
[🍎]  [1 2 3 … 10]  [Front App]  ···  [CPU | 温度] [⏻] [🔊] [📶] [📅]
  ← left                               right →
```

| 区域 | 组件 | 说明 |
|------|------|------|
| Apple | `🍎` | Apple logo 装饰 |
| Spaces | `1~10` | AeroSpace 工作区切换，显示当前窗口的 app 图标 |
| Front App | 当前前台应用名 | 最多显示 7 个字符 |
| CPU | 使用率 % + 折线图 | 实时更新，颜色随负载变化 |
| 温度 | SOC 温度 + 折线图 | 颜色随温度变化（绿→黄→橙→红） |
| 电池 | 电量 % 图标 | 显示百分比和充电状态 |
| 音量 | 音量图标 | 当前输出音量 % |
| Wi-Fi | ↑↓ 速率 | 网络上下行实时速率 |
| 日历 | `Sun. 28 Jun 18:00:00` | 当前日期时间 |

## 鼠标交互

### 工作区（Spaces）

| 操作 | 效果 |
|------|------|
| 点击工作区 | 切换到该工作区 |
| 鼠标悬停 | 高亮工作区边框 |
| 切换焦点窗口 | 自动更新工作区内的 app 图标 |

### CPU / 温度

| 操作 | 效果 |
|------|------|
| 点击 | 打开 Activity Monitor |

### 音量

| 操作 | 效果 |
|------|------|
| 左键点击 | 弹出音频输出设备选择菜单 |
| 右键点击 | 打开系统声音偏好设置 |
| 滚轮 | 调节音量 |

### Wi-Fi

| 操作 | 效果 |
|------|------|
| 点击（上传/下载/图标） | 弹出网络详情（SSID、IP、掩码、路由、主机名） |
| 点击弹窗中的任意值 | 复制到剪贴板 |
| 鼠标移出弹窗 | 关闭弹窗 |

### 电池

| 操作 | 效果 |
|------|------|
| 点击 | 显示剩余时间估算 |

## SBAR 模式（状态栏控制）

通过 AeroSpace 快捷键 `Cmd + Shift + B` 进入 SBAR 模式，可以对状态栏进行控制：

| 快捷键 | 功能 |
|--------|------|
| `Cmd + Shift + S` | 开关 Cava 音频频谱 |
| `Cmd + Shift + R` | 重启 sketchybar 服务 |
| `Cmd + Shift + Backspace` | 关闭壁纸背景 |
| `Cmd + Shift + W` | 开启壁纸背景 |
| `Cmd + Shift + ↑` | 上一张壁纸 |
| `Cmd + Shift + ↓` | 下一张壁纸 |
| `Cmd + Shift + ←` | 取消选中壁纸 |
| `Cmd + Shift + →` / `Enter` | 选中/确认当前壁纸 |
| `Shift + Ctrl + C` | 切换 亮色/暗色 主题 |
| `Shift + Ctrl + B` | 切换 黑色/模糊 bar 背景 |
| `Shift + Ctrl + T` | 切换整体主题 |
| `Esc` | 退出 SBAR 模式 |

## 配色

| Token | 颜色 | Hex |
|-------|------|-----|
| Background | 深灰 60% 透明 | `#363944` |
| White | 浅灰白 | `#e2e2e3` |
| Red | 珊瑚红 | `#fc5d7c` |
| Green | 草绿 | `#9ed072` |
| Blue | 天蓝 | `#76cce0` |
| Yellow | 暖黄 | `#e7c664` |
| Orange | 橙色 | `#f39660` |
| Magenta | 薰衣草紫 | `#b39df3` |
| Grey | 中性灰 | `#7f8490` |
| Bar 背景 | 半透白色 | `0xBF` + white |
| 激活工作区高亮 | 绿色 | `#9ed072` |
| 工作区图标高亮 | 黄色 | `#e7c664` |

## 依赖

- [sketchybar](https://github.com/FelixKratz/SketchyBar)
- [SbarLua](https://github.com/FelixKratz/SbarLua) — Lua 桥接
- `switchaudio-osx` — 音频设备切换
- `smctemp` — SOC 温度读取
- `jq` — JSON 解析
- `pmset` — 电池信息（macOS 内置）

> 详见 [sketchybar 官方文档](https://felixkratz.github.io/SketchyBar/)
