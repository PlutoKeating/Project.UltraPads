import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';

import '../assets/private_assets.dart';

/// 启动时注入。
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('prefsProvider must be overridden'),
);

final privateAssetsProvider = Provider<PrivateAssets>(
  (ref) => PrivateAssets.none,
);

/// 语言：up_i18n 的 LocaleController，持久化到 SharedPreferences。
class PrefsLocaleStore implements LocaleStore {
  PrefsLocaleStore(this.prefs);
  final SharedPreferences prefs;
  static const _k = 'locale';

  @override
  Future<String?> read() async => prefs.getString(_k);

  @override
  Future<void> write(String? languageTag) async =>
      languageTag == null ? prefs.remove(_k) : prefs.setString(_k, languageTag);
}

final localeControllerProvider = ChangeNotifierProvider<LocaleController>(
  (ref) => throw StateError('localeControllerProvider must be overridden'),
);

/// 用户偏好（不是业务真值；业务状态都在引擎）。
@immutable
class AppSettings {
  const AppSettings({
    this.skinId = UpSemanticThemes.defaultId,
    this.customSkins = const [],
    this.animatePads = true,
    this.onboarded = false,
    this.bufferFrames,
    this.outputDevice,
    this.keyboardEnabled = true,
    this.classicPads = false,
    this.firstGuideSeen = false,
    this.autoUpdateCheck = true,
  });

  /// 当前皮肤：内置 id 或自定义皮肤 id。
  final String skinId;
  final List<UpSkin> customSkins;
  final bool animatePads;
  final bool onboarded;
  final int? bufferFrames;
  final String? outputDevice;
  final bool keyboardEnabled;

  /// 使用 APK 经典 Lottie pad 动画（需要注入 APK 素材）。
  final bool classicPads;

  /// 演奏页首次引导（4.7.0 FirstGuide）已完成或跳过。
  final bool firstGuideSeen;

  /// 启动后自动检查新版本（只发一次 GET /api/version，不上报设备信息）。
  final bool autoUpdateCheck;

  AppSettings copyWith({
    String? skinId,
    List<UpSkin>? customSkins,
    bool? animatePads,
    bool? onboarded,
    int? Function()? bufferFrames,
    String? Function()? outputDevice,
    bool? keyboardEnabled,
    bool? classicPads,
    bool? firstGuideSeen,
    bool? autoUpdateCheck,
  }) => AppSettings(
    skinId: skinId ?? this.skinId,
    customSkins: customSkins ?? this.customSkins,
    animatePads: animatePads ?? this.animatePads,
    onboarded: onboarded ?? this.onboarded,
    bufferFrames: bufferFrames != null ? bufferFrames() : this.bufferFrames,
    outputDevice: outputDevice != null ? outputDevice() : this.outputDevice,
    keyboardEnabled: keyboardEnabled ?? this.keyboardEnabled,
    classicPads: classicPads ?? this.classicPads,
    firstGuideSeen: firstGuideSeen ?? this.firstGuideSeen,
    autoUpdateCheck: autoUpdateCheck ?? this.autoUpdateCheck,
  );
}

class SettingsController extends Notifier<AppSettings> {
  static const _kSkin = 'skin';
  static const _kCustom = 'customSkins';
  static const _kAnimate = 'animatePads';
  static const _kOnboarded = 'onboarded';
  static const _kBuffer = 'bufferFrames';
  static const _kDevice = 'outputDevice';
  static const _kKeyboard = 'keyboard';
  static const _kClassic = 'classicPads';
  static const _kFirstGuide = 'firstGuideSeen';
  static const _kAutoUpdate = 'autoUpdateCheck';

  SharedPreferences get _p => ref.read(prefsProvider);

  @override
  AppSettings build() {
    final p = ref.watch(prefsProvider);
    final skins = <UpSkin>[];
    for (final raw in p.getStringList(_kCustom) ?? const <String>[]) {
      try {
        skins.add(UpSkin.decode(raw));
      } catch (_) {
        // 损坏的皮肤 JSON：丢弃
      }
    }
    return AppSettings(
      skinId: p.getString(_kSkin) ?? UpSemanticThemes.defaultId,
      customSkins: skins,
      animatePads: p.getBool(_kAnimate) ?? true,
      onboarded: p.getBool(_kOnboarded) ?? false,
      bufferFrames: p.getInt(_kBuffer),
      outputDevice: p.getString(_kDevice),
      keyboardEnabled: p.getBool(_kKeyboard) ?? true,
      classicPads: p.getBool(_kClassic) ?? false,
      firstGuideSeen: p.getBool(_kFirstGuide) ?? false,
      autoUpdateCheck: p.getBool(_kAutoUpdate) ?? true,
    );
  }

  void setSkin(String id) {
    state = state.copyWith(skinId: id);
    _p.setString(_kSkin, id);
  }

  /// 新增或替换一个自定义皮肤。
  void saveCustomSkin(UpSkin skin, {bool select = true}) {
    final list = [...state.customSkins.where((s) => s.id != skin.id), skin];
    state = state.copyWith(customSkins: list, skinId: select ? skin.id : null);
    _p.setStringList(_kCustom, [for (final s in list) s.encode()]);
    if (select) _p.setString(_kSkin, skin.id);
  }

  void deleteCustomSkin(String id) {
    final list = state.customSkins.where((s) => s.id != id).toList();
    final skin = state.skinId == id ? UpSemanticThemes.defaultId : state.skinId;
    state = state.copyWith(customSkins: list, skinId: skin);
    _p.setStringList(_kCustom, [for (final s in list) s.encode()]);
    _p.setString(_kSkin, skin);
  }

  void setAnimatePads(bool v) {
    state = state.copyWith(animatePads: v);
    _p.setBool(_kAnimate, v);
  }

  void setOnboarded() {
    state = state.copyWith(onboarded: true);
    _p.setBool(_kOnboarded, true);
  }

  /// 首次引导完成 / 跳过（true），或在设置中重新显示（false）。
  void setFirstGuideSeen(bool v) {
    state = state.copyWith(firstGuideSeen: v);
    _p.setBool(_kFirstGuide, v);
  }

  void setBufferFrames(int? v) {
    state = state.copyWith(bufferFrames: () => v);
    v == null ? _p.remove(_kBuffer) : _p.setInt(_kBuffer, v);
  }

  void setOutputDevice(String? v) {
    state = state.copyWith(outputDevice: () => v);
    v == null ? _p.remove(_kDevice) : _p.setString(_kDevice, v);
  }

  void setClassicPads(bool v) {
    state = state.copyWith(classicPads: v);
    _p.setBool(_kClassic, v);
  }

  void setAutoUpdateCheck(bool v) {
    state = state.copyWith(autoUpdateCheck: v);
    _p.setBool(_kAutoUpdate, v);
  }

  void setKeyboardEnabled(bool v) {
    state = state.copyWith(keyboardEnabled: v);
    _p.setBool(_kKeyboard, v);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

/// 4.7.0 皮肤预设在设置中的 id 前缀（`preset-default` …）。
const presetPrefix = 'preset-';

/// 当前皮肤对应的 UpTheme：自定义皮肤 → 4.7.0 预设 → 内置主题。
final upThemeProvider = Provider<UpTheme>((ref) {
  final s = ref.watch(settingsProvider);
  for (final skin in s.customSkins) {
    if (skin.id == s.skinId) return UpTheme.fromSkin(skin);
  }
  if (s.skinId.startsWith(presetPrefix)) {
    final id = s.skinId.substring(presetPrefix.length);
    for (final p in UpSkinPresets.all) {
      if (p.id == id) return p.toTheme();
    }
  }
  return UpThemes.byId(s.skinId);
});

/// 皮肤 JSON 的编码（导出 / 分享）。
String encodeSkin(UpSkin skin) =>
    const JsonEncoder.withIndent('  ').convert(skin.toJson());
