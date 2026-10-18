import 'package:flutter/material.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_ui/up_ui.dart';

import '../library/genres.dart';
import 'catalog_models.dart';

/// 曲风键 → 显示名；目录里的曲风不一定在内置曲风表里，缺失时原样显示键。
String genreLabel(UpL10n l10n, String key) =>
    GenreSpec(key, Icons.music_note_rounded, ColorRole.pink).label(l10n);

/// 条目的封面角色色：按 ID 稳定地落到调色板里。
int roleOf(CatalogItem item) => ColorRole.fromPalette(
  item.id.hashCode.abs() % ColorRole.palette.length,
).index;

String sizeMb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

/// 列表行的副标题：BPM · 曲风 · 大小。
String itemSubtitle(UpL10n l10n, CatalogItem i) => [
  if (i.bpm > 0) l10n.performTempo(i.bpm.round()),
  if (i.genre.isNotEmpty) genreLabel(l10n, i.genre),
  if (i.size > 0) l10n.libraryCatalogDetailSizeMb(sizeMb(i.size)),
].join(' · ');

String originLabel(UpL10n l10n, String origin) => switch (origin) {
  'album' => l10n.libraryCatalogOriginAlbum,
  'online' => l10n.libraryCatalogOriginOnline,
  'synth' => l10n.libraryCatalogOriginSynth,
  'ugc' => l10n.libraryCatalogOriginUgc,
  _ => origin,
};

/// 许可证提示：每个限制一句话（署名 / 相同方式共享 / 非商业）。
List<String> licenseHints(UpL10n l10n, LicenseInfo l) => switch (l.id) {
  'CC0-1.0' => [l10n.libraryLicenseCc0Hint],
  'PD' => [l10n.libraryLicensePdHint],
  _ => [
    if (l.needsAttribution) l10n.libraryLicenseByHint,
    if (l.shareAlike) l10n.libraryLicenseSaHint,
    if (l.nonCommercial) l10n.libraryLicenseNcHint,
  ],
};

/// 许可证徽标：SA / NC 带限制的用醒目样式，长按 / 悬停显示说明。
class LicenseBadge extends StatelessWidget {
  const LicenseBadge({super.key, required this.license});
  final LicenseInfo license;

  @override
  Widget build(BuildContext context) {
    final hints = licenseHints(context.l10n, license);
    return Tooltip(
      message: hints.join('\n'),
      child: UpBadge(
        label: license.badge,
        kind: license.nonCommercial || license.shareAlike
            ? UpBadgeKind.top
            : UpBadgeKind.neutral,
      ),
    );
  }
}
