import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `--dart-define=UP_SITE=http://127.0.0.1:8787`：覆盖官方站点地址（本地联调 Worker）。
const String siteOverride = String.fromEnvironment('UP_SITE');

/// 外部链接与服务地址配置（入库的 `assets/config/links.json`）。页面不硬编码任何 URL。
class AppLinks {
  const AppLinks({
    this.downloadPage,
    this.siteBase,
    this.idIssuer,
    this.idClientId = 'ultrapads-app',
    this.idSettingsPage,
  });

  static const asset = 'assets/config/links.json';

  /// 下载落地页（无法自动更新时，设置页「软件更新」打开它）。
  final Uri? downloadPage;

  /// 官方站点（目录与账号数据接口 `/api/catalog`、`/api/me`，docs/API.md §7）。
  final Uri? siteBase;

  /// PlutoKeating 账号（OIDC）签发方与本应用的客户端 ID。
  final Uri? idIssuer;
  final String idClientId;

  /// 账号设置页（设置 → 账号 → 管理账号）。
  final Uri? idSettingsPage;

  static Uri? _uri(Object? v) => switch (v) {
    final String s when s.isNotEmpty => Uri.tryParse(s),
    _ => null,
  };

  factory AppLinks.fromJson(Map<String, dynamic> json) => AppLinks(
    downloadPage: _uri(json['downloadPage']),
    siteBase: _uri(siteOverride.isNotEmpty ? siteOverride : json['siteBase']),
    idIssuer: _uri(json['idIssuer']),
    idClientId: switch (json['idClientId']) {
      final String s when s.isNotEmpty => s,
      _ => 'ultrapads-app',
    },
    idSettingsPage: _uri(json['idSettingsPage']),
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
