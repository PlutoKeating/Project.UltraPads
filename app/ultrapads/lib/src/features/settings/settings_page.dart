import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../routing/routes.dart';
import '../../state/engine_state.dart';
import '../../state/settings_state.dart';
import '../account/account_section.dart';
import '../skins/skins_sheet.dart';
import 'update_section.dart';

/// 设置：音频（缓冲 / 设备 / 延迟）、外观（皮肤 / 动画 pad / 经典动画）、
/// 语言、键盘映射、我的设备、关于。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  /// 缓冲档位（帧）。
  static const _buffers = [64, 128, 256, 512, 1024];

  /// Android 的缓冲由 AAudio 按 burst 决定（引擎忽略固定缓冲请求），不提供档位。
  static bool get _systemBuffer => !kIsWeb && Platform.isAndroid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final locales = ref.watch(localeControllerProvider);
    final boot = ref.watch(engineBootProvider);
    final engine = ref.watch(engineProvider);
    final assets = ref.watch(privateAssetsProvider);
    final status = ref.watch(_audioStatusProvider);
    final devices =
        ref.watch(_devicesProvider).value ?? const <AudioDeviceInfo>[];
    // 音频未运行（启动失败）时没有采样率：缓冲档位不显示毫秒数。
    final rate = switch (status.value?.sampleRate) {
      final r? when r > 0 => r,
      _ => null,
    };
    final buffer = _systemBuffer
        ? 0
        : settings.bufferFrames ?? status.value?.bufferFrames;

    Widget header(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(0, UpSpacing.xxl, 0, UpSpacing.sm),
      child: UpText(s, role: UpTextRole.titleSm, color: c.textSecondary),
    );

    Future<void> restartAudio() async {
      final s = ref.read(settingsProvider);
      await tryEngine(engine.audioStop);
      await tryEngine(
        () => engine.audioStart(
          AudioConfig(
            bufferFrames: s.bufferFrames,
            outputDevice: s.outputDevice,
          ),
        ),
      );
      ref.invalidate(_audioStatusProvider);
    }

    return Scaffold(
      backgroundColor: c.surfacePage,
      body: SafeArea(
        child: Column(
          children: [
            UpTopBar(
              leading: UpIconButton(
                icon: Icons.arrow_back_rounded,
                semanticLabel: l10n.commonBack,
                onPressed: () => context.pop(),
              ),
              title: l10n.settingsTitle,
              centerTitle: true,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: UpPageTokens.paddingX,
                ),
                children: [
                  if (boot.fallbackReason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: UpSpacing.lg),
                      child: UpText(
                        l10n.settingsEngineFallback,
                        role: UpTextRole.bodySm,
                        color: c.statusWarning,
                        maxLines: 3,
                      ),
                    ),
                  header(l10n.settingsAudio),
                  UpListItem(
                    icon: Icons.speaker_rounded,
                    title: l10n.settingsOutputDevice,
                    subtitle: switch (settings.outputDevice) {
                      null => status.value?.device ?? l10n.commonUnknown,
                      final id => () {
                        final name =
                            devices
                                .where((d) => d.id == id)
                                .map((d) => d.name)
                                .firstOrNull ??
                            id;
                        // 选的设备打不开时引擎回退到系统默认输出（up-host audio_start）
                        final st = status.value;
                        return st != null && st.running && st.device != name
                            ? l10n.settingsOutputDeviceFallback(name)
                            : name;
                      }(),
                    },
                    onTap: devices.isEmpty
                        ? null
                        : () async {
                            final id = await showUpSheet<String>(
                              context,
                              builder: (ctx) => UpSheet(
                                title: l10n.settingsOutputDevice,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: UpPageTokens.paddingX,
                                    ),
                                    child: UpListItem(
                                      title: l10n.settingsOutputDeviceSystem,
                                      onTap: () => Navigator.pop(ctx, ''),
                                    ),
                                  ),
                                  for (final d in devices.where(
                                    (d) => !d.isInput,
                                  ))
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: UpPageTokens.paddingX,
                                      ),
                                      child: UpListItem(
                                        title: d.name,
                                        onTap: () => Navigator.pop(ctx, d.id),
                                      ),
                                    ),
                                ],
                              ),
                            );
                            if (id == null) return;
                            ctrl.setOutputDevice(id.isEmpty ? null : id);
                            await restartAudio();
                          },
                  ),
                  const SizedBox(height: UpSheetTokens.itemGap),
                  UpListItem(
                    icon: Icons.tune_rounded,
                    title: l10n.settingsBufferSize,
                    // 后端没有固定缓冲（如 AAudio 默认）时 bufferFrames 为 0。
                    subtitle: rate == null || buffer == null
                        ? null
                        : buffer == 0
                        ? l10n.settingsBufferSizeSystem
                        : l10n.settingsBufferSizeValue(
                            buffer,
                            buffer / rate * Duration.millisecondsPerSecond,
                          ),
                    trailing: _systemBuffer
                        ? null
                        : Wrap(
                            spacing: UpSpacing.xs,
                            children: [
                              for (final b in _buffers)
                                UpChip(
                                  label: '$b',
                                  variant: buffer == b
                                      ? UpChipVariant.selected
                                      : UpChipVariant.normal,
                                  onTap: () async {
                                    ctrl.setBufferFrames(b);
                                    await restartAudio();
                                  },
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: UpSheetTokens.itemGap),
                  UpListItem(
                    icon: Icons.speaker_rounded,
                    title: l10n.settingsAudioStatus,
                    subtitle: switch (status.value) {
                      null => l10n.errorEngineUnsupported,
                      final st when !st.running => l10n.settingsAudioStopped,
                      final st => l10n.settingsAudioStatusValue(
                        st.host,
                        st.device,
                        st.channels,
                        st.sampleFormat,
                      ),
                    },
                  ),
                  const SizedBox(height: UpSheetTokens.itemGap),
                  UpListItem(
                    icon: Icons.timer_rounded,
                    title: l10n.settingsLatency,
                    subtitle: switch (status.value) {
                      null => l10n.errorEngineUnsupported,
                      final st when !st.running || !st.latencyMs.isFinite =>
                        l10n.settingsAudioStopped,
                      final st => l10n.settingsLatencyValue(
                        st.latencyMs.round(),
                      ),
                    },
                  ),
                  header(l10n.settingsAppearance),
                  UpListItem(
                    icon: Icons.palette_rounded,
                    title: l10n.settingsSkin,
                    subtitle: skinName(context, settings.skinId),
                    onTap: () => showSkinsSheet(context),
                  ),
                  const SizedBox(height: UpSheetTokens.itemGap),
                  UpSwitchRow(
                    title: l10n.settingsAnimatePads,
                    value: settings.animatePads,
                    onChanged: ctrl.setAnimatePads,
                  ),
                  if (assets.key('apk/lottie/normal_blue.json') != null) ...[
                    const SizedBox(height: UpSheetTokens.itemGap),
                    UpSwitchRow(
                      title: l10n.settingsClassicPads,
                      value: settings.classicPads,
                      onChanged: ctrl.setClassicPads,
                    ),
                  ],
                  const SizedBox(height: UpSheetTokens.itemGap),
                  UpSwitchRow(
                    title: l10n.settingsKeyboardMapping,
                    subtitle: l10n.performKeyboardHint,
                    value: settings.keyboardEnabled,
                    onChanged: ctrl.setKeyboardEnabled,
                  ),
                  header(l10n.settingsLanguage),
                  UpListItem(
                    title: l10n.settingsLanguageSystem(
                      UpL10n.of(context).localeNativeName,
                    ),
                    trailing: locales.followsSystem
                        ? Icon(Icons.check_rounded, color: c.accentPrimary)
                        : null,
                    onTap: locales.followSystem,
                  ),
                  for (final loc in UpL10n.supportedLocales) ...[
                    const SizedBox(height: UpSheetTokens.itemGap),
                    UpListItem(
                      title: lookupUpL10n(loc).localeNativeName,
                      subtitle: lookupUpL10n(loc).localeEnglishName,
                      trailing: locales.locale == loc
                          ? Icon(Icons.check_rounded, color: c.accentPrimary)
                          : null,
                      onTap: () => locales.setLocale(loc),
                    ),
                  ],
                  header(l10n.settingsAccountTitle),
                  const AccountSection(),
                  header(l10n.hubTitle),
                  UpListItem(
                    icon: Icons.devices_rounded,
                    title: l10n.hubTitle,
                    subtitle: l10n.hubDescription,
                    onTap: () => context.push(Routes.hub),
                  ),
                  header(l10n.settingsAbout),
                  UpListItem(
                    icon: Icons.info_rounded,
                    title: l10n.settingsVersion(engine.appVersion),
                    subtitle: l10n.settingsEngineBackend(engine.backendName),
                  ),
                  const SizedBox(height: UpSheetTokens.itemGap),
                  const UpdateSection(),
                  const SizedBox(height: UpSheetTokens.itemGap),
                  UpListItem(
                    icon: Icons.folder_special_rounded,
                    title: l10n.settingsPrivateAssets,
                    subtitle: assets.available
                        ? assets.priority.join(' + ')
                        : l10n.commonNone,
                  ),
                  const SizedBox(height: UpSheetTokens.itemGap),
                  UpListItem(
                    icon: Icons.description_rounded,
                    title: l10n.settingsLicenses,
                    onTap: () => showLicensePage(context: context),
                  ),
                  header(l10n.settingsDeveloper),
                  UpListItem(
                    icon: Icons.tour_rounded,
                    title: l10n.settingsReplayGuide,
                    onTap: () {
                      ref
                          .read(settingsProvider.notifier)
                          .setFirstGuideSeen(false);
                      showUpToast(context, l10n.settingsReplayGuideDone);
                    },
                  ),
                  const SizedBox(height: UpSheetTokens.itemGap),
                  UpListItem(
                    icon: Icons.auto_awesome_mosaic_rounded,
                    title: l10n.settingsDesignGallery,
                    onTap: () => context.push(Routes.gallery),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: UpSpacing.xxl,
                    ),
                    child: UpText(
                      l10n.settingsResearchNotice,
                      role: UpTextRole.caption,
                      color: c.textMuted,
                      maxLines: 6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 只读当前状态（`audio_status`），不再为了读状态而重启音频。
final _audioStatusProvider = FutureProvider<AudioStatus?>(
  (ref) => tryEngine(ref.watch(engineProvider).audioStatus),
);

final _devicesProvider = FutureProvider<List<AudioDeviceInfo>>(
  (ref) async =>
      await tryEngine(ref.watch(engineProvider).audioDevices) ?? const [],
);
