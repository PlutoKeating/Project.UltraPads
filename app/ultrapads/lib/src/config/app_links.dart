import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 外部链接配置（入库的 `assets/config/links.json`）。页面不硬编码任何 URL。
class AppLinks {
  const AppLinks({this.videoSearch = const {}, this.videoQuerySuffix = ''});

  static const asset = 'assets/config/links.json';

  /// 语言代码（`zh`、`en`…，`default` 兜底）→ 带 `{query}` 占位的搜索 URL。
  final Map<String, String> videoSearch;
  final String videoQuerySuffix;

  factory AppLinks.fromJson(Map<String, dynamic> json) => AppLinks(
    videoSearch: Map<String, String>.from(
      json['videoSearch'] as Map? ?? const {},
    ),
    videoQuerySuffix: json['videoQuerySuffix'] as String? ?? '',
  );

  static Future<AppLinks> load([AssetBundle? bundle]) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString(asset);
      return AppLinks.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppLinks();
    }
  }

  /// 视频教程链接：Kit 自带的 [kitVideoUrl] 优先，否则按语言用搜索模板。
  /// 没有可用配置时返回 null（按钮隐藏）。
  Uri? videoFor({
    required String languageCode,
    String? kitName,
    String? kitVideoUrl,
  }) {
    if (kitVideoUrl != null && kitVideoUrl.isNotEmpty) {
      return Uri.tryParse(kitVideoUrl);
    }
    final template = videoSearch[languageCode] ?? videoSearch['default'];
    if (template == null) return null;
    final query = [
      if (kitName != null && kitName.isNotEmpty) kitName,
      if (videoQuerySuffix.isNotEmpty) videoQuerySuffix,
    ].join(' ');
    return Uri.tryParse(
      template.replaceAll('{query}', Uri.encodeQueryComponent(query)),
    );
  }
}

final appLinksProvider = FutureProvider<AppLinks>((ref) => AppLinks.load());
