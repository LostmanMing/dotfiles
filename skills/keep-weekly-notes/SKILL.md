---
name: keep-weekly-notes
description: Maintain concise, topic-organized weekly conversation and work notes as private offline HTML. Use when asked to record current work, update this week's notes, preserve a feature's optimization path and final rationale, or reorganize a weekly note that has become hard to scan.
argument-hint: [要记录或整理的工作]
---

# 每周对话工作笔记

把当前对话中值得长期保留的工作压缩进本周 HTML。按主题维护知识，不保存聊天流水。

## 不可违反的边界

- 运行时所有 `*.html` 的创建、修改、拆分、合并和目录重排都必须交给一个在后台运行且具备文件写入能力的 subagent。
- 主 agent 不得用 `Write`、`Edit`、shell 重定向、模板替换脚本或其他方式改 HTML。
- 同一个周文件同时只能有一个 writer；等待其完成后才能再次更新。
- 当前 agent 环境不支持后台 subagent，或 writer 写入失败时，停止并明确报告“HTML 未更新”，不得由主 agent 兜底。
- 只记录工作事实、决策和结果；不保存原始 transcript、完整命令输出、prompt、token、凭据、环境变量或身份信息。

## 1. 读取或初始化配置

配置独立于具体 agent 工具，位于：

```text
${XDG_CONFIG_HOME:-$HOME/.config}/keep-weekly-notes/config.json
```

直接定位本周文件：

```bash
python3 <SKILL_DIR>/scripts/notes.py week
```

退出码为 `3` 表示尚未配置。若本次参数已给出明确目录，直接使用；否则通过当前 agent 环境提供的结构化提问能力让用户选择建议目录或输入自定义目录；若没有结构化提问能力，再简短询问路径。拿到路径后运行：

```bash
python3 <SKILL_DIR>/scripts/notes.py config set --output-root '<用户选择的目录>'
python3 <SKILL_DIR>/scripts/notes.py week
```

后续直接复用配置，不重复询问。helper 会拒绝相对路径、权限开放的已有目录以及 dotfiles 仓库内路径，防止私人笔记泄露或进入版本库。已有目录权限过宽时，提示用户改选私有子目录；未经允许不要替用户 chmod 现有目录。

## 2. 定位本周文件

读取 `week` 命令 JSON 中的 `week_id`、`week_start`、`week_end` 和 `html_path`。布局固定为：

```text
<output_root>/
├── 2026-W35/
│   └── index.html
└── 2026-W36/
    └── index.html
```

每个 ISO 周独立；更新本周时不修改以前的周目录。

## 3. 提炼更新包

只从当前可见对话提炼有长期价值的信息，按下面字段交给 writer：

- `topic_slug`：稳定、简短的英文 kebab-case 标识；同一功能后续沿用。
- `topic_title`：面向人的主题名。
- `outcome`：目前实际状态或交付结果。
- `evidence`：影响判断的测试结果、限制或失败现象，只留关键证据。
- `route`：仅在经历多次方案变化时提供，格式为“初始方案 → 问题/证据 → 调整 → 结果”。
- `rationale`：为什么最终这样做，尤其记录被否决方案的关键缺陷。
- `next`：确实尚未完成的事项；没有则省略。

不要把每轮问答逐条复述。若当前对话没有新增决策、结果或关键证据，直接说明无需更新。

## 4. 委派后台 writer

启动一个具备文件写入能力的 subagent，并使用当前 agent 环境提供的后台/异步执行方式；不要用后台 shell 进程冒充 subagent。prompt 至少包含：

1. 本周 ID、日期范围、`week_dir`、`html_path`、模板 `<SKILL_DIR>/assets/week.html` 和 validator 路径。
2. 完整更新包；subagent 看不到主对话，不得让它自行猜测背景。
3. 独占权限仅限本周 `index.html`、同目录候选文件及周目录，不得修改其他周或 skill 文件。
4. 写入任何笔记内容前设置 `umask 077`，以 `0700` 创建周目录，并在同目录使用 `.index.html.new` 作为候选文件；不得直接编辑现有 `index.html`。
5. 文件不存在时把模板复制为候选文件并替换全部占位内容；存在时先完整读取，再复制为候选文件并按语义合并。候选文件必须设为 `0600`。
6. 先验证候选文件：

```bash
python3 <SKILL_DIR>/scripts/notes.py validate --staged --file '<week_dir>/.index.html.new' --week '<week_id>'
```

若更新包含 `route`，追加：

```bash
--require-route '<topic_slug>'
```

7. 候选验证通过后，用同文件系统内的原子 rename/move 替换 `index.html`，再对最终路径运行一次不带 `--staged` 的 validator。验证失败时保留原 `index.html` 不动并停止，不自动换另一个 agent 重试。

要求 writer 最终只回报：文件路径、create/update/restructure、变化的 topic slug、验证结果；不要回传整篇私人笔记。

等待后台完成通知，不要轮询 output file。失败时仍不得由主 agent 改 HTML。

## 5. 内容整理规则

writer 每次都应维护整篇文档，而不是在末尾追加：

- 用 `article[data-topic]` 识别主题；同一主题合并到原位置。
- 页内目录必须与实际主题一致，并按依赖关系和重要性排序，不按聊天时间排序。
- 当前结论覆盖旧结论；只保留解释决策变化所必需的历史。
- 多轮优化压缩成短路线，突出“为什么改”和“验证后怎样”，另列最终理由。
- 合并重复主题；拆分过载主题；重命名含糊标题；删除已失效的临时细节和“杂项”。
- 当目录难以扫描、同一内容散落或标题层级失真时，直接重构目录与章节，不保留旧布局兼容层。
- 普通主题尽量不超过 250 个词或约 1500 个可见字符；整周尽量不超过 1200 个词或约 8000 个可见字符。优先压缩早期步骤，不删除会改变决策含义的证据。

## 6. 主 agent 验收

后台 agent 完成后，主 agent只读检查实际文件并再次运行 validator。确认：

- 本周文件存在且上周文件未被修改。
- 同一 `data-topic` 仅出现一次，目录链接完整。
- 多轮修改不是流水账，优化路线与最终理由都清楚。
- 没有远程资源、脚本、敏感内容或未替换占位符。

只有验证通过才能报告完成；失败要如实说明 HTML 当前状态和未完成项。

## Resources

| 路径 | 用途 |
|---|---|
| `scripts/notes.py` | 配置、ISO 周路径计算和只读 HTML 验证 |
| `assets/week.html` | 后台 writer 首次创建周文件时使用的离线模板 |
