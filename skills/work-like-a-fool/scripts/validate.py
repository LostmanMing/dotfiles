#!/usr/bin/env python3
"""校验教程站点：题目数据契约、页面引用、SVG 合法性、导航完整性。

用法： validate.py --dir ./mysite
退出码 0 = 全部通过；1 = 有错误（ERROR）；警告（WARN）不影响退出码。
"""
import argparse
import json
import os
import re
import subprocess
import sys
import xml.dom.minidom

E, W = [], []


def err(m): E.append(m)
def warn(m): W.append(m)


def check_questions(assets):
    p = os.path.join(assets, "questions.js")
    if not os.path.isfile(p):
        err("缺少 assets/questions.js")
        return
    src = open(p, encoding="utf-8").read()
    if "TODO" in src:
        err("assets/questions.js 仍含 TODO 占位，未生成真实题目")
    node = None
    for c in ("node", "nodejs"):
        if subprocess.run(["which", c], capture_output=True).returncode == 0:
            node = c
            break
    if not node:
        warn("未找到 node，跳过题目数据的深度校验（语法/答案索引/维度覆盖）")
        return
    probe = src + r"""
const out = {cats: Object.keys(CATS), n: QUESTIONS.length, self: SELF.length,
             ctx: CONTEXT.length, topic: TOPIC.title, bad: []};
QUESTIONS.forEach((q, i) => {
  const t = (m) => out.bad.push(`Q${i + 1}: ${m}`);
  if (!CATS[q.cat]) t(`cat "${q.cat}" 不在 CATS 里`);
  if (![1, 2, 3].includes(q.level)) t(`level 必须是 1/2/3，实际 ${q.level}`);
  if (!Array.isArray(q.opts) || q.opts.length < 2) t("opts 至少 2 项");
  if (!Array.isArray(q.answer) || !q.answer.length) t("answer 不能为空");
  (q.answer || []).forEach(a => { if (a < 0 || a >= (q.opts || []).length) t(`answer 索引 ${a} 越界`); });
  if (!q.multi && (q.answer || []).length !== 1) t("单选题 answer 必须恰好 1 个");
  if (q.multi && (q.answer || []).length < 2) t("多选题 answer 应 >= 2 个");
  if (!q.why || q.why.length < 10) t("why（解析）缺失或过短");
});
const cnt = {};
QUESTIONS.forEach(q => cnt[q.cat] = (cnt[q.cat] || 0) + 1);
out.percat = cnt;
console.log(JSON.stringify(out));
"""
    r = subprocess.run([node, "-e", probe], capture_output=True, text=True)
    if r.returncode != 0:
        err(f"questions.js 执行失败（语法错误？）：{r.stderr.strip().splitlines()[-1] if r.stderr.strip() else '?'}")
        return
    d = json.loads(r.stdout.strip().splitlines()[-1])
    for b in d["bad"]:
        err(b)
    if d["n"] < 20:
        err(f"题目只有 {d['n']} 道，要求 >= 20")
    if not d["self"]:
        warn("SELF（自评项）为空")
    if not d["ctx"]:
        warn("CONTEXT（实际处境问题）为空")
    for c in d["cats"]:
        if d["percat"].get(c, 0) < 2:
            warn(f"维度 {c} 只有 {d['percat'].get(c, 0)} 道题，建议 >= 2")
    print(f"  题目: {d['n']} 道 / {len(d['cats'])} 个维度 {d['percat']}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    a = ap.parse_args()
    root = os.path.abspath(a.dir)
    assets = os.path.join(root, "assets")
    if not os.path.isdir(root):
        print(f"FAIL: 目录不存在 {root}")
        return 1

    print(f"校验 {root}")
    check_questions(assets)

    pages = []
    pjs = os.path.join(assets, "pages.js")
    if os.path.isfile(pjs):
        m = re.search(r"window\.SITE_PAGES\s*=\s*(\[.*?\]);", open(pjs, encoding="utf-8").read(), re.S)
        if m:
            pages = [p[0] for p in json.loads(m.group(1))]
        else:
            err("assets/pages.js 格式异常，解析不出 SITE_PAGES")
    else:
        err("缺少 assets/pages.js")

    htmls = sorted(f for f in os.listdir(root) if f.endswith(".html"))
    for f in pages:
        if f not in htmls:
            err(f"pages.js 引用了不存在的页面 {f}")
    for f in htmls:
        if f not in pages:
            warn(f"页面 {f} 未出现在导航里")

    for f in htmls:
        s = open(os.path.join(root, f), encoding="utf-8").read()
        if "assets/pages.js" not in s or "assets/nav.js" not in s:
            err(f"{f} 未引入 pages.js / nav.js，导航不会出现")
        if '<div class="pager"></div>' not in s:
            warn(f"{f} 缺少 <div class=\"pager\"></div>，上下页按钮不会渲染")
        for ref in re.findall(r'(?:src|href)="(assets/[^"]+)"', s):
            if not os.path.exists(os.path.join(root, ref)):
                err(f"{f} 引用了不存在的资源 {ref}")
        for todo in re.findall(r"__[A-Z_]+__", s):
            err(f"{f} 残留模板占位符 {todo}")
        if "TODO" in s:
            warn(f"{f} 含 TODO")

    imgdir = os.path.join(assets, "img")
    svgs = sorted(f for f in os.listdir(imgdir)) if os.path.isdir(imgdir) else []
    for f in svgs:
        if not f.endswith(".svg"):
            continue
        try:
            xml.dom.minidom.parse(os.path.join(imgdir, f))
        except Exception as ex:
            err(f"assets/img/{f} 不是合法 XML: {ex}")
    used = set()
    for f in htmls:
        used |= set(re.findall(r"assets/img/([^\"]+)", open(os.path.join(root, f), encoding="utf-8").read()))
    for f in svgs:
        if f not in used:
            warn(f"assets/img/{f} 未被任何页面引用")

    print(f"  页面: {len(htmls)} 个 | 导航: {len(pages)} 项 | 图: {len(svgs)} 张（引用 {len(used & set(svgs))}）")
    for m in W:
        print(f"  WARN  {m}")
    for m in E:
        print(f"  ERROR {m}")
    print("PASS" if not E else f"FAIL（{len(E)} 个错误）")
    return 1 if E else 0


if __name__ == "__main__":
    sys.exit(main())
