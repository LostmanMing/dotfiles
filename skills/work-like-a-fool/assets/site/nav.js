// 通用导航：页面需先定义 window.SITE_PAGES = [["index.html","首页"], ...]
(function () {
  const PAGES = window.SITE_PAGES || [];
  const cur = location.pathname.split("/").pop() || "index.html";
  const wrap = document.querySelector(".wrap");
  if (!wrap || !PAGES.length) return;

  const nav = document.createElement("nav");
  nav.className = "top";
  PAGES.forEach(([href, title], i) => {
    if (i) { const s = document.createElement("span"); s.className = "sep"; s.textContent = "·"; nav.appendChild(s); }
    const a = document.createElement("a");
    a.href = href; a.textContent = title;
    if (href === cur) a.className = "here";
    nav.appendChild(a);
  });
  wrap.insertBefore(nav, wrap.firstChild);

  const i = PAGES.findIndex(p => p[0] === cur);
  const host = document.querySelector(".pager");
  if (host && i >= 0) {
    const mk = (p, next) => {
      if (!p) return document.createElement("span");
      const a = document.createElement("a");
      a.href = p[0];
      if (next) a.className = "next";
      const s = document.createElement("span");
      s.textContent = next ? "下一节 →" : "← 上一节";
      a.appendChild(s);
      a.appendChild(document.createTextNode(p[1]));
      return a;
    };
    host.appendChild(mk(PAGES[i - 1], false));
    host.appendChild(mk(PAGES[i + 1], true));
  }
})();
