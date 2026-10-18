import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:up_tokens/up_tokens.dart';

/// 运行时私有素材解析。
///
/// - 入库占位清单：`assets/private_manifest/manifest.json`（`available: false`）
/// - 注入后清单：`assets/private_manifest/injected.json`（由
///   `tools/assets/inject_private_assets.dart` 生成，不入库）
///
/// 键的格式为 `<来源>/<类别>/<相对路径>`，来源按 `priority`（ios → apk）解析。
/// 任何查询在素材缺失时返回 null，调用方回退到开源占位（程序化绘制、
/// Material 图标、up_tokens 的 Montserrat）。
class PrivateAssets {
  const PrivateAssets._(
    this.available,
    this.priority,
    this.entries, {
    this.privateKits = const {},
    this.generatedAt = '',
  });

  static const PrivateAssets none = PrivateAssets._(false, [], {});

  static const _dir = 'assets/private_manifest';

  final bool available;
  final List<String> priority;
  final Map<String, String> entries;

  /// 原 App 内置 Kit：原目录结构中的相对路径（相对 compat-ios 根）→ 资源路径。
  /// 首次启动还原成目录后交给曲库导入器（见 `library/first_run.dart`）。
  final Map<String, String> privateKits;

  /// 注入时间（用来判断是否需要重新导入内置 Kit）。
  final String generatedAt;

  static Future<PrivateAssets> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    for (final name in const ['injected.json', 'manifest.json']) {
      try {
        final json =
            jsonDecode(await b.loadString('$_dir/$name'))
                as Map<String, dynamic>;
        if (json['available'] != true) continue;
        final kits = json['privateKits'] as Map<String, dynamic>?;
        return PrivateAssets._(
          true,
          List<String>.from(json['priority'] as List? ?? const []),
          Map<String, String>.from(json['entries'] as Map? ?? const {}),
          privateKits: Map<String, String>.from(
            kits?['files'] as Map? ?? const {},
          ),
          generatedAt: json['generatedAt'] as String? ?? '',
        );
      } catch (_) {
        // 未注入：继续回退
      }
    }
    return none;
  }

  /// 精确键（`ios/skin/padDefault/Skin_padDefault__img_pad_blue.png`）。
  String? key(String key) => entries[key];

  /// 依次尝试多个键，返回第一个存在的资源路径。
  String? first(Iterable<String> keys) {
    for (final k in keys) {
      final v = entries[k];
      if (v != null) return v;
    }
    return null;
  }

  /// 在各来源（按优先级）的同一类别下找 [rel]。
  String? resolve(String category, String rel) =>
      first(priority.map((s) => '$s/$category/$rel'));

  ImageProvider? image(String? path) => path == null ? null : AssetImage(path);

  /// 注册私有字体：Uni Sans（APK）→ UpFonts 已知的家族名。
  Future<void> registerFonts([AssetBundle? bundle]) async {
    if (!available) return;
    final b = bundle ?? rootBundle;
    final found = <String, ByteData>{};
    for (final MapEntry(key: family, value: file)
        in UpFonts.privateFiles.entries) {
      // UpFonts 约定的文件名是 `font__Uni_Sans.ttf`；清单里是原名 `Uni Sans.ttf`。
      final original = file.replaceFirst('font__', '').replaceAll('_', ' ');
      final path = resolve('font', original);
      if (path == null) continue;
      try {
        found[family] = await b.load(path);
      } catch (e) {
        debugPrint('PrivateAssets: font $file failed: $e');
      }
    }
    if (found.isNotEmpty) await UpFonts.registerBytes(found);
  }
}
