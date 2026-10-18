// 语言切换（默认跟随浏览器）、复制安装命令、从 /api/version 填入版本号与直达下载地址。
(() => {
  const nodes = document.querySelectorAll("[data-zh]");
  let saved = null;
  try { saved = localStorage.getItem("lang"); } catch { /* 存储不可用时只跟随浏览器 */ }
  let lang = (saved || navigator.language || "zh").toLowerCase().startsWith("zh") ? "zh" : "en";
  const apply = () => {
    document.documentElement.lang = lang === "zh" ? "zh-CN" : "en";
    nodes.forEach((n) => { n.textContent = n.dataset[lang]; });
    document.getElementById("lang").textContent = lang === "zh" ? "English" : "中文";
  };
  apply();
  document.getElementById("lang").addEventListener("click", () => {
    lang = lang === "zh" ? "en" : "zh";
    try { localStorage.setItem("lang", lang); } catch { /* 忽略 */ }
    apply();
  });

  const copy = document.getElementById("copy");
  copy.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(document.getElementById("cmd").textContent);
      copy.textContent = lang === "zh" ? "已复制" : "Copied";
      setTimeout(apply, 1500);
    } catch { /* 剪贴板不可用时用户可手动选择 */ }
  });

  fetch("/api/version").then((r) => (r.ok ? r.json() : null)).then((m) => {
    if (!m) return;
    document.getElementById("version").textContent = `v${m.version}`;
    document.getElementById("notes").href = m.notes_url;
    document.querySelectorAll("[data-asset]").forEach((a) => {
      const asset = m.assets[a.dataset.asset];
      if (asset) a.href = asset.url;
    });
  }).catch(() => { /* 链接保持 /dl/latest/*，由 Worker 302 */ });
})();
