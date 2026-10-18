// 发布元数据的纯函数（不做网络 I/O，供 Worker 与 node --test 共用）。
// 契约见 docs/API.md §6「发布与更新接口」。

export const REPO = "PlutoKeating/Project.UltraPads";
export const TAG = /^v\d+\.\d+\.\d+$/;
/** 发布资产命名：ultrapads-<版本>-<平台>.<tar.gz|apk>，平台见 PLATFORMS。 */
const ASSET_RE = /^ultrapads-(\d+\.\d+\.\d+)-(linux-x64|linux-arm64|android-arm64-v8a|android-armeabi-v7a|android-x86_64)\.(tar\.gz|apk)$/;
export const PLATFORMS = ["linux-x64", "linux-arm64", "android-arm64-v8a", "android-armeabi-v7a", "android-x86_64"];
/** /dl/ 只镜像这些文件名（发布资产 + 校验文件）。 */
export const MIRRORED = /^(?:ultrapads-\d+\.\d+\.\d+-[a-z0-9_-]+\.(?:tar\.gz|apk)|SHA256SUMS\.txt)$/;

/** 解析资产名 → { version, platform }；不符合命名返回 null。 */
export function parseAssetName(name) {
  const m = ASSET_RE.exec(name);
  if (!m) return null;
  const kind = m[2].startsWith("linux-") ? "tar.gz" : "apk";
  if (m[3] !== kind) return null;
  return { version: m[1], platform: m[2] };
}

/** GitHub 资产的 digest（"sha256:<hex>"）→ 小写 hex；没有或格式不对返回 null。 */
export function sha256Of(digest) {
  const m = /^sha256:([0-9a-f]{64})$/.exec(String(digest ?? "").toLowerCase());
  return m ? m[1] : null;
}

/**
 * GitHub release JSON → 版本清单。
 * 只收录有 sha256 的资产（没有 digest 的资产客户端无法校验，宁可不提供）。
 * 预发布 / 草稿 / 非 vX.Y.Z 的 tag 返回 null。
 */
export function manifestFromRelease(release, origin) {
  if (!release || release.draft || release.prerelease) return null;
  const tag = String(release.tag_name ?? "");
  if (!TAG.test(tag)) return null;
  const version = tag.slice(1);
  const assets = {};
  for (const a of Array.isArray(release.assets) ? release.assets : []) {
    const name = String(a.name ?? "");
    const parsed = parseAssetName(name);
    const sha256 = sha256Of(a.digest);
    if (!parsed || parsed.version !== version || !sha256) continue;
    assets[parsed.platform] = {
      name,
      size: typeof a.size === "number" ? a.size : null,
      sha256,
      url: `${origin}/dl/${tag}/${name}`,
      fallback_url: `https://github.com/${REPO}/releases/download/${tag}/${name}`,
    };
  }
  return {
    version,
    tag,
    published_at: release.published_at ?? null,
    notes_url: `https://github.com/${REPO}/releases/tag/${tag}`,
    assets,
  };
}

/**
 * 清单 → 给 shell 读取的 KEY=VALUE 行（安装脚本逐行按前缀匹配，不 eval）。
 * 值只可能是版本号、文件名、十六进制、数字与 https 地址；仍做一次白名单过滤，出现意外字符就整体拒绝。
 */
export function manifestToShell(manifest, platform) {
  const a = manifest.assets[platform];
  if (!a) return null;
  const lines = [
    ["UP_VERSION", manifest.version],
    ["UP_TAG", manifest.tag],
    ["UP_NAME", a.name],
    ["UP_SIZE", a.size ?? ""],
    ["UP_SHA256", a.sha256],
    ["UP_URL", a.url],
    ["UP_FALLBACK_URL", a.fallback_url],
  ];
  for (const [, v] of lines) {
    if (!/^[A-Za-z0-9._:/+-]*$/.test(String(v))) return null;
  }
  return lines.map(([k, v]) => `${k}=${v}`).join("\n") + "\n";
}
