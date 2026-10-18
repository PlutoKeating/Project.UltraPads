import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 外部链接配置（入库的 `assets/config/links.json`）。页面不硬编码任何 URL。
class AppLinks {
  const AppLinks({this.downloadPage});

  static const asset = 'assets/config/links.json';

  /// 下载落地页（无法自动更新时，设置页「软件更新」打开它）。
  final Uri? downloadPage;

  factory AppLinks.fromJson(Map<String, dynamic> json) => AppLinks(
    downloadPage: switch (json['downloadPage']) {
      final String url when url.isNotEmpty => Uri.tryParse(url),
      _ => null,
    },
  );

  static Future<AppLinks> load([AssetBundle? bundle]) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString(asset);
      return AppLinks.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppLinks();
    }
  }
}

final appLinksProvider = FutureProvider<AppLinks>((ref) => AppLinks.load());
