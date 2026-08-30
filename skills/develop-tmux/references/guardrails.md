# Tmux 防回归约束

只在任务涉及对应领域时读取。

## Clipboard

- 保持 `set-clipboard on`，让 OSC 52 同时写 tmux buffer 并转发终端。
- `@clipboard_cmd` 是不支持 OSC 52 终端的并行兜底；不能按 SSH 或 `DISPLAY` 排除其中一路。
- 外部 clipboard 命令失败不能影响 tmux buffer；用户内容只经 stdin 传递。

## AI 状态

- 永远不写 `pane_title`；qodercli/Claude 会自行覆盖。内部状态写 `@ai_state`，会话聚合写 `@ai_sess`。
- 未知但非空的 Claude status 降级为 busy；保留 `kind` 与 `jobId` 过滤，避免后台 daemon 覆盖交互会话。
- 状态脚本不能含 sleep、网络、`tmux wait-for` 或按 pane 次数增长的 tmux 调用。
- PID 必须结合进程 start time 防复用；平台分支以当前 `ai-panes.sh` 为准。

## fzf 与 popup

- 公共版本检查、清空 `FZF_DEFAULT_OPTS`、OneDark 配色和基础布局留在 `fzf-common.sh`。
- normal/insert 切换必须成对 `unbind`/`rebind`，否则字母键无法输入。
- 隐藏输入前先清查询；用户查询只作为单参数传递，禁止 `eval`。
- popup 外框样式依赖 server >= 3.3；新版 client 连接旧 server 不会启用新选项。

## 可重复加载

- `terminal-features`、`terminal-overrides` 等 append 型配置必须先恢复/清理再追加，连续 source 不得累积。
- TPM 路径显式保持为 `~/.tmux/plugins/`，避免 XDG 配置目录改变插件安装位置。

## 真实验证

- 使用私有 socket/server，避免碰默认 server。
- popup/选择器要在 attached client 中测试，不用一次性 CLI 的 `#()` 缓存结果判断状态栏。
- 验证大/小终端、退出路径、空列表、缺依赖和重复 source。
