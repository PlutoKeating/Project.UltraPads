import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Font registry.
///
/// * The original Uni Sans cuts (Fontfabric, commercial) are **never committed**.
///   `just inject-assets` (tools/assets/inject_private_assets.dart) copies them
///   from `private-assets/compat/fonts/` into the app's git-ignored
///   `assets/private_manifest/` as `font__<name>.ttf`; [loadPrivate] registers
///   whatever is present at startup.
/// * When a private cut is missing, text roles fall back to the bundled
///   Montserrat (SIL OFL 1.1, `packages/up_tokens/assets/fonts/`).
abstract final class UpFonts {
  /// Package that bundles the fallback fonts.
  static const String package = 'up_tokens';

  /// Default location of injected private fonts inside the app bundle.
  static const String privateAssetDir = 'assets/private_manifest/';

  /// Private family name -> file name expected in [privateAssetDir].
  /// Family names must match `font.family.*` tokens.
  static const Map<String, String> privateFiles = <String, String>{
    'Uni Sans': 'font__Uni_Sans.ttf',
    'Uni Sans Heavy': 'font__Uni_Sans_Heavy.ttf',
    'Uni Sans Thin': 'font__Uni_Sans_Thin.ttf',
  };

  static final Set<String> _loaded = <String>{};

  /// Bumped whenever the set of available families changes (themes cache on it).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Whether a private family has been registered with the engine.
  static bool isLoaded(String family) => _loaded.contains(family);

  /// Families currently registered by [loadPrivate] / [registerBytes].
  static Set<String> get loadedFamilies => Set<String>.unmodifiable(_loaded);

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
        // Not injected: fallback family will be used.
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
