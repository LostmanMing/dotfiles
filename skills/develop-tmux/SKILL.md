---
name: develop-tmux
description: Develop and troubleshoot this tmux configuration and scripts, including installation, bindings, popups, status logic, AI state, clipboard integration, and isolated real-server verification. Use for .config/tmux changes.
argument-hint: <要开发或排查的 tmux 功能>
---

# Tmux 配置开发

从 `<SKILL_DIR>/../..` 解析 `<DOTFILES_ROOT>`，维护其 `.config/tmux`；先在隔离 server 验证，再决定是否触碰用户活跃会话。

## 开始前

1. 读取 `.config/tmux/AGENTS.md` 的相关章节和受影响脚本/配置。
2. 检查主仓库状态，保留所有已有改动。
3. 分别检查 client `tmux -V` 与 server `tmux display-message -p '#{version}'`；两者可能不同。
4. 确认目标功能需要哪些依赖，只安装必需项。

## 修改边界

- 键位、tmux option 和 popup 入口放 `tmux.conf`；复杂逻辑放 `scripts/`。
- 四个 fzf 界面的版本、环境和配色复用 `scripts/fzf-common.sh`，业务数据与按键留在调用脚本。
- 状态生产只在 `ai-panes.sh`，聚合/写 option 在 `ai-status.sh`，展示与跳转在 `ai-pick.sh`。
- 状态栏路径格式复用 `path-tail.sh`；不要在 format 中堆阻塞 shell。
- 新增键位、依赖或用户可见行为时同步 README 和 AGENTS。
- 修改 popup/fzf、AI 状态或剪贴板前读取 `references/guardrails.md` 对应段落。

## 验证

1. 运行 `<SKILL_DIR>/scripts/verify.sh`，先完成 shell 语法、隔离 server 加载、重复 source 和关键绑定检查。
2. 涉及 popup、fzf、choose-tree、copy-mode、状态栏或 pane 跳转时，运行 `<SKILL_DIR>/scripts/verify.sh --interactive`，从真实 attached client 使用对应快捷键并捕获界面。
3. 测试目标脚本的错误路径：缺依赖、空结果、Esc/Ctrl-C、查询中特殊字符或不存在的目标。
4. 系统剪贴板需在终端外实际粘贴验证；tmux buffer 用 `tmux save-buffer -` 验证。
5. 最后才在用户许可下 source 活跃 server；不得为升级或验证强杀有工作的 server。

## 排错顺序

1. 捕获真实 pane、`display-message` 和脚本退出状态。
2. 检查 client/server 版本、PATH、依赖、`TMUX_PLUGIN_MANAGER_PATH` 和软链。
3. AI 状态按 `ai-panes.sh` → pane title/session JSON → `@ai_state`/`@ai_sess` → format → `ai-status.sh` 排查。
4. popup 瞬间退出先直接运行脚本检查 fzf 参数与版本。
5. 在隔离 socket 复现并修复根因，再回到用户路径验收。

## 安全边界

- 不对默认 server 执行 `kill-server`。
- 不删除未知插件目录、session 或用户 buffer。
- 不用 hook 代替 AI CLI 的实际状态源，不写 `pane_title`。
- 不把用户输入拼入 `eval` 或未引用的 shell 命令。
