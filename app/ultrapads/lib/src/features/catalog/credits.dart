import 'package:up_i18n/up_i18n.dart';

import 'catalog_models.dart';

/// 需要署名 / 带限制的素材（CC0 与公有领域不需要）。
List<CatalogItem> creditable(Iterable<CatalogItem> items) => [
  for (final i in items)
    if (i.license.needsAttribution) i,
];

/// 分享 / 导出录音时附上的署名文字：每个素材一行署名，外加非商业 / 相同方式共享的提醒。
String creditsText(UpL10n l10n, List<CatalogItem> items) {
  final lines = <String>[
    for (final i in items)
      i.attribution.isNotEmpty
          ? i.attribution
          : '${i.title} — ${i.artist} (${i.license.badge})',
  ];
  if (items.any((i) => i.license.nonCommercial)) {
    lines.add(l10n.shareExportCreditsNc);
  }
  if (items.any((i) => i.license.shareAlike)) {
    lines.add(l10n.shareExportCreditsSa);
  }
  return lines.join('\n');
}
