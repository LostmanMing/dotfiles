#!/usr/bin/env python3
"""创建定制教程站点骨架。

用法：
  # 阶段一：只建测评页
  scaffold.py --dir ./mysite --title "标题" --subtitle "副标题" --quiz-only

  # 阶段二：按测评结果补齐课程页（modules 为 JSON 文件或内联 JSON）
  scaffold.py --dir ./mysite --title "标题" --modules modules.json

modules.json 形如：
  [{"file":"m01.html","nav":"M1 全景图","mod":"M1","title":"全景图","goal":"这节要达到什么"},
   {"file":"m02.html","nav":"M2 XX","mod":"M2","title":"XX","goal":"..."}]

已存在的页面不会被覆盖（除 assets/ 下的模板与 pages.js）。
"""
import argparse
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.join(os.path.dirname(HERE), "assets", "site")


def fill(src, dst, repl):
    with open(src, encoding="utf-8") as f:
        s = f.read()
    for k, v in repl.items():
        s = s.replace(k, v)
    with open(dst, "w", encoding="utf-8") as f:
        f.write(s)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True, help="站点目录")
    ap.add_argument("--title", required=True)
    ap.add_argument("--subtitle", default="")
    ap.add_argument("--env", default="（用 scripts/probe_env.py 探测后填入）")
    ap.add_argument("--chain", default="（在这里画出这个主题的技术链路，测评维度对应链路各段）")
    ap.add_argument("--modules", default=None, help="JSON 文件路径或内联 JSON")
    ap.add_argument("--quiz-only", action="store_true")
    a = ap.parse_args()

    root = os.path.abspath(a.dir)
    assets = os.path.join(root, "assets")
    os.makedirs(os.path.join(assets, "img"), exist_ok=True)
    os.makedirs(os.path.join(root, "labs"), exist_ok=True)

    created, skipped = [], []

    # 静态资源：总是覆盖（它们是模板，不含内容）
    for f in ("style.css", "nav.js", "quiz.js"):
        shutil.copy(os.path.join(SITE, f), os.path.join(assets, f))

    modules = []
    if a.modules:
        raw = a.modules
        if os.path.isfile(raw):
            with open(raw, encoding="utf-8") as f:
                raw = f.read()
        try:
            modules = json.loads(raw)
        except json.JSONDecodeError as e:
            print(f"FAIL: --modules 不是合法 JSON: {e}")
            return 1

    # pages.js：导航顺序 = 首页 → 各模块 → 测评
    pages = [["index.html", "首页"]]
    pages += [[m["file"], m.get("nav", m.get("mod", m["file"]))] for m in modules]
    pages += [["quiz.html", "测评"]]
    with open(os.path.join(assets, "pages.js"), "w", encoding="utf-8") as f:
        f.write("window.SITE_PAGES = " + json.dumps(pages, ensure_ascii=False, indent=2) + ";\n")

    def emit(name, src, repl):
        dst = os.path.join(root, name)
        if os.path.exists(dst):
            skipped.append(name)
            return
        fill(src, dst, repl)
        created.append(name)

    emit("quiz.html", os.path.join(SITE, "quiz.html"),
         {"__TITLE__": a.title, "__CHAIN__": a.chain})
    emit("index.html", os.path.join(SITE, "index.html"),
         {"__TITLE__": a.title, "__SUBTITLE__": a.subtitle, "__ENV__": a.env})

    # questions.js 占位：AI 需要覆盖它
    q = os.path.join(assets, "questions.js")
    if not os.path.exists(q):
        with open(q, "w", encoding="utf-8") as f:
            f.write("""// 由 AI 生成。契约见 SKILL.md / references/quiz-design.md
const TOPIC = { title: "TODO", goal: "TODO" };
const CATS = { demo: { name: "示例维度" } };
const QUESTIONS = [
  { cat: "demo", level: 1, text: "TODO", opts: ["A", "B"], answer: [0], why: "TODO" },
];
const SELF = [["demo", "示例自评项"]];
const CONTEXT = [{ id: "goal", label: "你的目标场景？", placeholder: "例：..." }];
""")
        created.append("assets/questions.js")
    else:
        skipped.append("assets/questions.js")

    if not a.quiz_only:
        for m in modules:
            emit(m["file"], os.path.join(SITE, "page.html"), {
                "__MOD__": m.get("mod", ""), "__TITLE__": m.get("title", ""),
                "__GOAL__": m.get("goal", ""), "__IMG__": m.get("img", "TODO.svg"),
            })

    print(f"OK  站点: {root}")
    print(f"    新建 {len(created)} 个: {', '.join(created) if created else '-'}")
    if skipped:
        print(f"    跳过（已存在，未覆盖）{len(skipped)} 个: {', '.join(skipped)}")
    print(f"    导航 {len(pages)} 页 → assets/pages.js")
    print("    下一步: 覆盖 assets/questions.js，然后 scripts/validate.py --dir " + a.dir)
    if modules and not a.quiz_only:
        print("    注意: 课程页模板里预置了一个指向 assets/img/TODO.svg 的 <figure>，"
              "校验会报错——这是强制提醒你补图；确实不需要图时删掉该 figure。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
