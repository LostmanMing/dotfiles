---
name: develop-dotfiles
description: Develop and maintain this dotfiles repository safely, including installation, cross-module changes, verification, troubleshooting, and submodule coordination. Use for work in the dotfiles root or changes spanning Neovim and tmux; routes module work to develop-neovim and develop-tmux.
argument-hint: <要开发、安装或排查的 dotfiles 功能>
---

# Dotfiles 开发总入口

从 `<SKILL_DIR>/../..` 解析 `<DOTFILES_ROOT>`，协调模块边界、已有改动和验证；模块细节交给对应子 skill。

## 开始前

1. 读取 `<DOTFILES_ROOT>/AGENTS.md` 及任务涉及目录下最近的 `AGENTS.md`。
2. 分别检查 `<DOTFILES_ROOT>` 与相关子模块的 `git status --short`；保留已有修改，不做 blanket reset/restore/checkout。
3. 确认用户要安装或修改的组件，不一次性安装全部可选依赖。
4. 区分事实与假设；版本、路径、运行中服务等可变状态必须现场检查。

## 路由到子 skill

模块任务开始实现前，必须通过 `Skill` 工具激活相应子 skill；不要只口头引用：

- Neovim、Lua、插件、LSP、DAP、keymap、`.config/nvim/**`、`/root/dotfiles-nvim/**` → `develop-neovim`
- tmux、pane/window/session、popup、fzf、状态栏、tmux 剪贴板、`.config/tmux/**` → `develop-tmux`
- nvim ↔ tmux 导航或剪贴板等跨模块任务 → 两个子 skill 都激活
- shell、Git、根 README/AGENTS、技能包和子模块指针 → 留在本 skill

子 skill 已在当前任务运行时不要重复激活。子任务完成后回到这里检查跨模块一致性和最终 diff。

## 工作流

### 安装

- 先列出目标组件和必需/可选依赖，只安装用户选择的部分。
- 优先使用仓库记录的版本和安装路径；系统仓库过旧时再使用固定版本二进制或源码安装。
- 软链前检查目标，不能覆盖用户已有文件或整个 `~/.qoder/skills` 目录。
- 安装后从用户入口运行一次，不以“命令存在”代替功能验证。

### 修改

- 先读相邻实现，复用现有 helper、主题和约定。
- 只做请求需要的改动；新增依赖、键位或可见行为时同步对应模块 README/AGENTS。
- 不把 API key、token、机器身份文件、历史记录或本地缓存纳入仓库。
- Neovim 是独立仓库；不要假设 `<DOTFILES_ROOT>/.config/nvim` 与另一个独立 `dotfiles-nvim` checkout 必然是同一工作树。

### 验证

- 使用子 skill 的验证流程到达用户实际界面。
- 根级改动至少检查安装命令、软链解析和相关 CLI 行为。
- 最后分别查看主仓库与子模块 diff/status，只报告实际观察到的结果和未覆盖项。

### 排错

1. 从用户入口复现并捕获原始输出。
2. 先排版本、PATH、软链、服务端/客户端和缺失依赖，再判断配置逻辑。
3. 使用隔离 socket、临时目录或独立进程，避免污染活跃会话。
4. 修正根因并重新走完整用户路径，不用禁用检查或破坏现有状态绕过问题。

## 子模块提交顺序

仅在用户明确要求提交时操作。Neovim 变更先在 Neovim 仓库完成验证与提交，再在主仓库更新子模块指针；不要把两个仓库的提交混成一步，也不要自动 push。
