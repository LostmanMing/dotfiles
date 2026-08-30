---
name: develop-neovim
description: Develop and troubleshoot this Neovim configuration, including Lua, plugins, keymaps, options, LSP, DAP, installation, and real runtime verification. Use for dotfiles-nvim or .config/nvim changes; reuses verify-nvim-config and its verifier.
argument-hint: <要开发或排查的 Neovim 功能>
---

# Neovim 配置开发

从 `<SKILL_DIR>/../..` 解析 `<DOTFILES_ROOT>`。在一个明确的 Neovim 工作树中修改配置，并通过真实 Neovim 运行结果验收。

## 定位工作树

1. 根据用户给出的路径或当前仓库选择目标；否则从 `<DOTFILES_ROOT>/.config/nvim` 与 `~/dotfiles-nvim` 中查找。
2. 若两个候选都存在且不是同一工作树，结合当前改动判断目标；仍不明确时让用户选择，不能同时修改两处。
3. 只修改选定工作树；检查并保留其已有未提交改动。
4. 读取该工作树的 `AGENTS.md`、相关 README 段落及受影响 Lua 文件。

## 修改约定

- 核心选项放 `lua/config/options.lua`，全局键位放 `lua/config/keymaps.lua`，插件行为放 `lua/plugins/<name>.lua`。
- 每个 keymap 都带 `desc`；注释只解释非显然的约束或原因。
- Lazy spec 优先使用 `keys`、`cmd`、`event`、`ft`、`opts`，不要无故改成启动时全量加载。
- 先复用 `lua/config/util.lua` 和已有插件模式，不为一次性行为新增抽象。
- 新增外部命令时做可执行文件检查，并把安装方式与版本下限写入 `AGENTS.md`。
- 影响用户用法、快捷键或插件清单时同步 README。

涉及剪贴板、buffer/tab、特殊窗口、DAP 或终端交互时，先读 `references/guardrails.md` 的对应段落。

## 验证

1. 读取 `<ROOT>/skills/verify-nvim-config/SKILL.md`。
2. 运行 `<ROOT>/skills/verify-nvim-config/verify.sh [受影响的 Lua 文件...]`；这是语法与启动烟测，不是最终交互验证。
3. 对 keymap、UI、终端、剪贴板、LSP/DAP 或命令行为，在隔离 tmux 中启动真实 `nvim`，发送真实按键/命令并捕获 pane；验证正常路径和一个邻近边界。
4. 插件依赖需从公开 Lazy spec/命令入口触发，不能只 `require()` 内部模块。
5. 最后检查 diff；失败、环境限制和未覆盖项必须明确报告。

## 排错顺序

1. 用真实 Neovim 启动复现，而非只读代码。
2. 检查 `nvim --version`、可执行 adapter/LSP、PATH、插件是否加载及文件类型。
3. 判断问题属于配置语法、lazy-load 条件、键位冲突、外部依赖还是终端/tmux 能力。
4. 做最小修复后同时重跑 verifier 与实际交互路径。

## 安全边界

- 不删除 `lazy-lock.json` 解决插件问题，不批量升级无关插件。
- 不覆盖用户未提交改动。
- 不因 headless 通过就声称 UI、键位或调试功能可用。
- 不在缺少 `CAP_SYS_PTRACE` 的容器中把 LLDB attach 失败归咎于配置。
