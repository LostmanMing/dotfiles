# Neovim 防回归约束

只在任务涉及对应领域时读取。

## 剪贴板

- 复制同时走 OSC 52 和可用的本地工具；不能按 `DISPLAY`、SSH 或平台二选一。
- tmux 内粘贴读 `tmux save-buffer -`；不要启用 clipboard cache，否则 tmux copy-mode 的新内容不可见。
- 不使用 `vim.ui.clipboard.osc52` 的 paste：终端不回应时会长时间阻塞。
- 系统剪贴板没有可靠回执，最终要真实复制后在终端外粘贴确认。

## Buffer、tab 与工具窗口

- `scope.nvim` 通过 `buflisted` 和缓存隔离 tab；不要只给 bufferline 加显示过滤。
- 同一 buffer 出现在多个 tab 时，不直接全局删除；关闭 tab 的顺序必须晚于当前 buffer 处理。
- NvimTree/Overseer 等普通工具窗口可在 `BufWinEnter` 设置 `winfixbuf`；Trouble 创建窗口时绕过 autocmd，应使用其原生 `win.wo` 配置。
- 实测特殊窗口中 `:edit` 应返回 `E1513`，不能只检查选项值。

## DAP

- Python adapter 使用当前 `python3` 的 debugpy；确认 `python3 -m debugpy --version`。
- Ubuntu 22.04 的 C/C++ adapter 使用 `lldb-vscode-14`；GDB 12 没有 DAP interpreter。
- Python→C++ 混合调试是在 Python 断点停住后另起 LLDB attach 会话。
- 容器缺少 `CAP_SYS_PTRACE` 时 LLDB 可启动但不能控制目标进程，这是环境限制。

## 真实交互

- 键位必须发送实际按键，不能用直接调用映射函数代替。
- UI 要捕获 pane 或截图，覆盖弹窗、焦点、退出和 resize 等相关边界。
- LSP/DAP 要从公开用户入口触发，并确认外部进程或 endpoint 真正启动。
