// 通用测评引擎。数据由同目录的 questions.js 提供全局变量：
//   TOPIC     {title, goal}
//   CATS      {key: {name}}
//   QUESTIONS [{cat, level:1|2|3, multi?:bool, text, opts:[], answer:[idx], why}]
//   SELF      [[key, label]]            自评滑块 0-5
//   CONTEXT   [{id, label, placeholder}] 自由填写题
// 题干/选项/解析支持行内 HTML（<code> <b> 等），由出题者负责内容安全。

const LV = p => p >= 0.8 ? "扎实" : p >= 0.55 ? "半懂" : p >= 0.3 ? "薄弱" : "空白";
const A = i => String.fromCharCode(65 + i);

function render() {
  document.getElementById("quiz").innerHTML = QUESTIONS.map((q, i) => {
    const type = q.multi ? "checkbox" : "radio";
    const opts = q.opts.map((o, j) =>
      `<label class="opt" data-q="${i}" data-o="${j}">
         <input type="${type}" name="q${i}" value="${j}"> ${o}
       </label>`).join("");
    return `<div class="q" id="q${i}">
      <div class="qhead"><span class="qno">${String(i + 1).padStart(2, "0")}</span>
      <span class="qtext">${q.text}</span></div>
      <div class="tags"><span class="badge">${CATS[q.cat].name}</span>
      <span class="badge">难度 ${"★".repeat(q.level)}</span>
      ${q.multi ? '<span class="badge">多选</span>' : ""}</div>
      ${opts}
      <div class="explain hidden" id="e${i}"></div>
    </div>`;
  }).join("");

  document.getElementById("self").innerHTML = SELF.map(([, label], i) =>
    `<div class="slider-row">
       <label for="s${i}">${label}</label>
       <input type="range" id="s${i}" min="0" max="5" step="1" value="0"
              oninput="document.getElementById('so${i}').value=this.value">
       <output id="so${i}">0</output>
     </div>`).join("") +
    `<p class="muted">0 = 完全没接触　1 = 听说过　2 = 能看懂别人的代码　3 = 能自己写　4 = 熟练　5 = 能给别人讲</p>`;

  document.getElementById("ctx").innerHTML = CONTEXT.map((c, i) =>
    `<p style="margin:14px 0 4px">${i + 1}. ${c.label}</p>
     <input type="text" id="c${i}" placeholder="${c.placeholder || ""}">`).join("");

  const t = document.getElementById("topic");
  if (t) t.innerHTML = `<h1>${TOPIC.title}</h1><p>${TOPIC.goal}</p>`;
}

function score() {
  return QUESTIONS.map((q, i) => {
    const picked = [...document.querySelectorAll(`input[name="q${i}"]:checked`)].map(e => +e.value);
    const correct = new Set(q.answer);
    let s = 0;
    if (picked.length) {
      if (q.multi) {
        const hit = picked.filter(p => correct.has(p)).length;
        s = Math.max(0, (hit - (picked.length - hit)) / q.answer.length);
      } else s = correct.has(picked[0]) ? 1 : 0;
    }
    return { picked, s };
  });
}

function grade() {
  const res = score();
  const per = {};
  Object.keys(CATS).forEach(k => per[k] = { got: 0, max: 0 });

  QUESTIONS.forEach((q, i) => {
    per[q.cat].got += res[i].s;
    per[q.cat].max += 1;
    const ex = document.getElementById(`e${i}`);
    ex.innerHTML = `<b>答案：</b>${q.answer.map(A).join(" ")}　`
      + (!res[i].picked.length ? "（未作答）" : res[i].s === 1 ? "✅ 正确"
        : res[i].s > 0 ? "◐ 部分正确" : "❌ 错误") + `<br>${q.why}`;
    ex.classList.remove("hidden");
    q.opts.forEach((_, j) => {
      const el = document.querySelector(`.opt[data-q="${i}"][data-o="${j}"]`);
      if (!el) return;
      el.classList.remove("right", "wrong");
      if (q.answer.includes(j)) el.classList.add("right");
      else if (res[i].picked.includes(j)) el.classList.add("wrong");
    });
  });

  document.getElementById("scores").innerHTML = Object.keys(CATS).map(k => {
    const p = per[k].max ? per[k].got / per[k].max : 0;
    return `<div class="score-row"><span>${CATS[k].name}</span>
      <span class="bar"><i style="width:${(p * 100).toFixed(0)}%"></i></span>
      <span class="lv">${(p * 100).toFixed(0)}% ${LV(p)}</span></div>`;
  }).join("");

  const total = Object.values(per).reduce((a, b) => a + b.got, 0);
  const pct = total / QUESTIONS.length;
  const band = pct >= 0.75 ? "B（有基础，缺的是细节与链路）"
    : pct >= 0.45 ? "A+（概念大体有，链路不通）" : "A（需要从底层模型搭地基）";

  const profile =
`## 测评结果：${TOPIC.title}
总分：${total.toFixed(1)} / ${QUESTIONS.length}（${(pct * 100).toFixed(0)}%），起点档位：${band}

分项：
${Object.keys(CATS).map(k => {
  const p = per[k].max ? per[k].got / per[k].max : 0;
  return `- ${CATS[k].name}：${(p * 100).toFixed(0)}%（${LV(p)}）`;
}).join("\n")}

逐题：
${QUESTIONS.map((q, i) =>
  `${i + 1}. [${q.cat} ★${q.level}] 我选 ${res[i].picked.map(A).join("") || "-"} / 正解 ${q.answer.map(A).join("")} → ${res[i].s.toFixed(1)}`).join("\n")}

自评（0-5）：${SELF.map(([, l], i) => `${l}=${document.getElementById("s" + i).value}`).join("; ")}

${CONTEXT.map((c, i) => `${c.label}\n  ${document.getElementById("c" + i).value.trim() || "（未填）"}`).join("\n")}`;

  document.getElementById("band").textContent = band;
  document.getElementById("profile").textContent = profile;
  document.getElementById("result").classList.remove("hidden");
  try { localStorage.setItem("assess_profile", profile); } catch (e) {}
  document.getElementById("result").scrollIntoView({ behavior: "smooth" });
}

render();
document.getElementById("submit").addEventListener("click", grade);
document.getElementById("copybtn").addEventListener("click", () => {
  const t = document.getElementById("profile").textContent;
  navigator.clipboard?.writeText(t).then(() => {
    const b = document.getElementById("copybtn");
    b.textContent = "已复制 ✓";
    setTimeout(() => b.textContent = "复制结果", 1800);
  }, () => alert("复制失败，请手动全选复制"));
});
