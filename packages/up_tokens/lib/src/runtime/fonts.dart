import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../generated/primitives.g.dart';

/// Which font family set text roles render with.
enum UpFontSet {
  /// Open Sans (SIL OFL 1.1) bundled in up_tokens — Ref 4.7.0 default.
  openSans,

  /// Uni Sans (Fontfabric, commercial, Ref 3.x). Optional skin font:
  /// only used when the private files were injected; otherwise Open Sans.
  uniSans;

  static UpFontSet parse(Object? v) =>
      UpFontSet.values.where((UpFontSet f) => f.name == v).firstOrNull ??
      UpFontSet.openSans;
}

/// Font registry.
///
/// * Open Sans Regular / ExtraBold / Light ship in `packages/up_tokens`
///   (declared in pubspec.yaml) and need no loading.
/// * The Uni Sans cuts are **never committed**. `just inject-assets`
///   (tools/assets/inject_private_assets.dart) copies them from
///   `private-assets/compat/fonts/` into the app's git-ignored
///   `assets/private_manifest/` as `font__<name>.ttf`; [loadPrivate] registers
///   whatever is present.
abstract final class UpFonts {
  /// Package that bundles Open Sans.
  static const String package = 'up_tokens';

  /// Default location of injected private fonts inside the app bundle.
  static const String privateAssetDir = 'assets/private_manifest/';

  /// Private family name -> injected file name. Names match `font.family.uniSans*`.
  static final Map<String, String> privateFiles = <String, String>{
    UpFontFamilies.uniSansRegular.first: 'font__Uni_Sans.ttf',
    UpFontFamilies.uniSansHeavy.first: 'font__Uni_Sans_Heavy.ttf',
    UpFontFamilies.uniSansThin.first: 'font__Uni_Sans_Thin.ttf',
  };

  static final Set<String> _loaded = <String>{};

  /// Bumped whenever the set of available families changes (themes cache on it).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Whether a private family has been registered with the engine.
  static bool isLoaded(String family) => _loaded.contains(family);

  /// Families currently registered by [loadPrivate] / [registerBytes].
  static Set<String> get loadedFamilies => Set<String>.unmodifiable(_loaded);

  /// Private Uni Sans family for a weight: <=300 Thin, >=600 Heavy, else Regular.
  static String uniSansFamilyFor(FontWeight weight) {
    if (weight.value <= 300) return UpFontFamilies.uniSansThin.first;
    if (weight.value >= 600) return UpFontFamilies.uniSansHeavy.first;
    return UpFontFamilies.uniSansRegular.first;
  }

  /// Tries to load every [privateFiles] entry from [bundle]. Missing files are
  /// skipped silently (open-source checkout). Returns the families loaded.
  static Future<Set<String>> loadPrivate({
    AssetBundle? bundle,
    String assetDir = privateAssetDir,
  }) async {
    final AssetBundle b = bundle ?? rootBundle;
    final Map<String, ByteData> found = <String, ByteData>{};
    for (final MapEntry<String, String> e in privateFiles.entries) {
      if (_loaded.contains(e.key)) continue;
      try {
        found[e.key] = await b.load('$assetDir${e.value}');
      } on Object {
        // Not injected: Open Sans is used.
      }
    }
    return registerBytes(found);
  }

  /// Registers font bytes per family (e.g. read from disk on desktop).
  static Future<Set<String>> registerBytes(
    Map<String, ByteData> fontsByFamily,
  ) async {
    final Set<String> added = <String>{};
    for (final MapEntry<String, ByteData> e in fontsByFamily.entries) {
      final FontLoader loader = FontLoader(e.key)
        ..addFont(Future<ByteData>.value(e.value));
      await loader.load();
      if (_loaded.add(e.key)) added.add(e.key);
    }
    if (added.isNotEmpty) revision.value++;
    return added;
  }

  /// Test hook: forget registered families.
  @visibleForTesting
  static void debugReset() {
    _loaded.clear();
    revision.value++;
  }
}
