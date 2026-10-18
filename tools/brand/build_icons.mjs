#!/usr/bin/env node
// UltraPads icon build: design/brand/ultrapads-mark.svg -> app icon SVGs + every platform bitmap.
//   just icons   (or: node tools/brand/build_icons.mjs)
// Needs ImageMagick 7 (`magick`) and a Chromium binary (SVG filters need a browser renderer):
// $CHROME, chromium / google-chrome on PATH, or Playwright's headless shell in ~/.cache/ms-playwright.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const BRAND = join(REPO, 'design/brand');
const APP = join(REPO, 'app/ultrapads');
const SITE = join(REPO, 'website/public');
const MARK = join(BRAND, 'ultrapads-mark.svg');
// 背景渐变与 mark 中的 #bg 一致；Android adaptive 背景与 manifest 主题色取同一组值。
const BG_TOP = '#1d1e23';
const BG_BOTTOM = '#0e0f11';

function run(cmd, args) {
  const r = spawnSync(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'] });
  if (r.error) throw new Error(`${cmd}: ${r.error.message}`);
  if (r.status !== 0) throw new Error(`${cmd} ${args.join(' ')}\n${r.stderr}`);
}

function findChrome() {
  const candidates = [process.env.CHROME, 'chromium', 'chromium-browser', 'google-chrome', 'google-chrome-stable'];
  for (const c of candidates.filter(Boolean)) {
    if (c.includes('/') ? existsSync(c) : spawnSync('which', [c]).status === 0) return c;
  }
  const pw = join(homedir(), '.cache/ms-playwright');
  if (existsSync(pw)) {
    for (const d of readdirSync(pw).filter((d) => d.startsWith('chromium')).sort().reverse()) {
      for (const bin of ['chrome-headless-shell-linux64/chrome-headless-shell', 'chrome-linux/chrome', 'chrome-linux64/chrome']) {
        if (existsSync(join(pw, d, bin))) return join(pw, d, bin);
      }
    }
  }
  throw new Error('未找到 Chromium：设置 CHROME=/path/to/chrome 或安装 chromium / Playwright headless shell');
}

// 1. 由 mark 生成圆角图标 SVG（品牌目录 + 官网）。
const mark = readFileSync(MARK, 'utf8');
const icon = mark
  .replace(/<!--[\s\S]*?-->/, '<!-- 由 design/brand/ultrapads-mark.svg 经 just icons 生成，不要手改。 -->')
  .replace('<g id="mark">', '<rect width="512" height="512" rx="112" fill="url(#bg)"/>\n<rect x="1" y="1" width="510" height="510" rx="111" fill="none" stroke="#e8e4dd" stroke-opacity=".1" stroke-width="2"/>\n<g id="mark">');
writeFileSync(join(BRAND, 'ultrapads.svg'), icon);
writeFileSync(join(SITE, 'icon.svg'), icon);

// 2. 用 Chromium 渲染 1024 母版。
const chrome = findChrome();
const tmp = mkdtempSync(join(tmpdir(), 'up-icons-'));
const bg = `linear-gradient(${BG_TOP}, ${BG_BOTTOM})`;
const masters = {
  // 圆角图标：Linux、Windows、Web、Android 旧式启动器。
  rounded: { svg: 'ultrapads.svg', box: 1024, scale: 1 },
  // 满版方形：iOS（系统自己切圆角）、PWA maskable、apple-touch-icon；标志缩到 80% 安全圆内。
  square: { svg: 'ultrapads-mark.svg', box: 1024, scale: 0.9, bg },
  // macOS：824 圆角主体居中 + 投影（Big Sur 图标栅格）。
  macos: { svg: 'ultrapads.svg', box: 824, scale: 1, shadow: true },
  // Android adaptive 前景：108dp 画布，标志落在 66dp 安全区内。
  foreground: { svg: 'ultrapads-mark.svg', box: 1024, scale: 0.66 },
};
for (const [name, m] of Object.entries(masters)) {
  const html = `<!doctype html><meta charset="utf-8"><style>html,body{margin:0;background:transparent}
body{width:1024px;height:1024px;display:grid;place-items:center}
div{width:${m.box}px;height:${m.box}px;${m.bg ? `background:${m.bg};` : ''}${m.shadow ? 'filter:drop-shadow(0 10px 14px rgb(0 0 0 / .35));' : ''}}
img{width:100%;height:100%;display:block;transform:scale(${m.scale})}</style>
<div><img src="${pathToFileURL(join(BRAND, m.svg))}"></div>`;
  const page = join(tmp, `${name}.html`);
  writeFileSync(page, html);
  run(chrome, ['--headless', '--no-sandbox', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files',
    '--default-background-color=00000000', '--window-size=1024,1024', `--screenshot=${join(tmp, `${name}.png`)}`, pathToFileURL(page).href]);
}

// 3. 缩放到各平台尺寸。
function out(master, size, dest, { opaque = false } = {}) {
  mkdirSync(dirname(dest), { recursive: true });
  const args = [join(tmp, `${master}.png`), '-filter', 'Lanczos', '-resize', `${size}x${size}`];
  if (opaque) args.push('-background', BG_BOTTOM, '-alpha', 'remove', '-alpha', 'off');
  run('magick', [...args, '-strip', `${opaque ? 'PNG24' : 'PNG32'}:${dest}`]);
}

out('rounded', 512, join(APP, 'linux/packaging/dev.ultrapads.ultrapads.png'));
out('rounded', 192, join(APP, 'web/icons/Icon-192.png'));
out('rounded', 512, join(APP, 'web/icons/Icon-512.png'));
out('rounded', 32, join(APP, 'web/favicon.png'));
out('square', 192, join(APP, 'web/icons/Icon-maskable-192.png'), { opaque: true });
out('square', 512, join(APP, 'web/icons/Icon-maskable-512.png'), { opaque: true });
out('square', 180, join(SITE, 'apple-touch-icon.png'), { opaque: true });

const ios = join(APP, 'ios/Runner/Assets.xcassets/AppIcon.appiconset');
for (const [pt, scales] of [[20, [1, 2, 3]], [29, [1, 2, 3]], [40, [1, 2, 3]], [60, [2, 3]], [76, [1, 2]], [83.5, [2]], [1024, [1]]]) {
  for (const s of scales) out('square', Math.round(pt * s), join(ios, `Icon-App-${pt}x${pt}@${s}x.png`), { opaque: true });
}
const mac = join(APP, 'macos/Runner/Assets.xcassets/AppIcon.appiconset');
for (const s of [16, 32, 64, 128, 256, 512, 1024]) out('macos', s, join(mac, `app_icon_${s}.png`));

const res = join(APP, 'android/app/src/main/res');
for (const [dpi, f] of Object.entries({ mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 })) {
  out('rounded', 48 * f, join(res, `mipmap-${dpi}/ic_launcher.png`));
  out('foreground', 108 * f, join(res, `mipmap-${dpi}/ic_launcher_foreground.png`));
}
writeFileSync(join(res, 'drawable/ic_launcher_background.xml'), `<?xml version="1.0" encoding="utf-8"?>
<!-- 由 tools/brand/build_icons.mjs 生成：adaptive icon 背景，与 design/brand/ultrapads.svg 的背景渐变一致。 -->
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient android:angle="270" android:startColor="${BG_TOP}" android:endColor="${BG_BOTTOM}" />
</shape>
`);
mkdirSync(join(res, 'mipmap-anydpi-v26'), { recursive: true });
writeFileSync(join(res, 'mipmap-anydpi-v26/ic_launcher.xml'), `<?xml version="1.0" encoding="utf-8"?>
<!-- 由 tools/brand/build_icons.mjs 生成。 -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
`);

const ico = join(tmp, 'ico');
mkdirSync(ico);
const icoParts = [256, 64, 48, 32, 16].map((s) => {
  const p = join(ico, `${s}.png`);
  out('rounded', s, p);
  return p;
});
run('magick', [...icoParts, join(APP, 'windows/runner/resources/app_icon.ico')]);

rmSync(tmp, { recursive: true, force: true });
console.log('icons: ultrapads.svg / website icon.svg / Linux / Windows / macOS / iOS / Android / Web 已生成');
