import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../config/app_links.dart';
import '../../routing/routes.dart';
import '../../state/engine_state.dart';
import '../../state/perform_state.dart';
import '../../state/settings_state.dart';
import '../recorder/save_recording_sheet.dart';
import '../skins/skins_sheet.dart';
import '../tutorial/tutorial_feedback.dart';
import '../tutorial/tutorial_timing.dart';
import 'keyboard_map.dart';
import 'pad_mapping.dart';
import 'perform_layout.dart';
import 'perform_toolbar.dart';

/// 演奏页（启动页），布局以 App Store 4.7.0（`ScreenPads/Main`）为准：
///
/// ```
/// [♫ SONGS] KIT <名称>                     [速度 1.0（教程模式）]
/// [🎓 LEARN TO PLAY | ⋮]  ⇄  [● ◐ ✎ ⤴ ⚙ ◀]               [ A ]
///   教程模式：[▶/■ ———————o——— ✕]
/// ┌────┬────┬────┐
/// │    │    │    │  3 × 4，A/B 两页横移切换
/// └────┴────┴────┘
/// ```
class PerformPage extends ConsumerStatefulWidget {
  const PerformPage({super.key});

  @override
  ConsumerState<PerformPage> createState() => _PerformPageState();
}

class _PerformPageState extends ConsumerState<PerformPage>
    with SingleTickerProviderStateMixin {
  final _focus = FocusNode(debugLabel: 'perform-keyboard');
  final Map<PhysicalKeyboardKey, int> _heldKeys = {};
  final Set<int> _keyPressed = {};
  final Set<String> _reported = {};
  StreamSubscription<EngineEvent>? _events;
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;
  bool _toolsExpanded = false;

  @override
  void initState() {
    super.initState();
    _events = ref.read(engineProvider).events.listen(_onEngineEvent);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _events?.cancel();
    _focus.dispose();
    super.dispose();
  }

  EngineClient get _engine => ref.read(engineProvider);

  void _onEngineEvent(EngineEvent e) {
    if (!mounted) return;
    final l10n = context.l10n;
    switch (e) {
      case KitLoadedEvent():
        ref.read(tutorialProvider.notifier).stop();
        showUpToast(context, l10n.performKitLoaded);
      case ErrorEvent(:final error):
        final key = error is EngineNotImplemented
            ? error.function
            : error.code.name;
        if (_reported.add(key)) {
          showUpToast(
            context,
            error is EngineNotImplemented
                ? l10n.errorEngineUnsupported
                : l10n.errorGeneric,
          );
        }
      case RecorderEvent(:final track?):
        showSaveRecordingSheet(context, track);
      default:
        break;
    }
  }

  // ------------------------------------------------------------ tutorial

  void _onTick(Duration now) {
    final dt = (now - _lastTick).inMicroseconds / 1e6;
    _lastTick = now;
    final t = ref.read(tutorialProvider.notifier);
    t.tick(dt, ref.read(bankProvider));
    final s = ref.read(tutorialProvider);
    if (s == null) {
      _ticker.stop();
    } else if (s.completed) {
      _ticker.stop();
      showUpToast(context, context.l10n.tutorialComplete);
    }
  }

  Future<void> _toggleTutorial() async {
    final l10n = context.l10n;
    final tutorial = ref.read(tutorialProvider.notifier);
    if (ref.read(tutorialProvider) != null) {
      tutorial.stop();
      return;
    }
    final kit = ref.read(engineViewProvider).kit;
    if (kit == null) return;
    final chart = await tryEngine(() => _engine.tutorialGet(kit.id));
    if (!mounted) return;
    if (chart == null) {
      showUpToast(context, l10n.tutorialUnavailable);
      return;
    }
    tutorial.start(chart);
    tutorial.settle(ref.read(bankProvider));
    if (chart.timed) {
      _lastTick = Duration.zero;
      if (!_ticker.isActive) _ticker.start();
    }
  }

  // ---------------------------------------------------------------- pads

  void _padDown(int bank, int index) {
    final id = PadId(bank, index);
    _engine.padDown(id); // 同步 FFI：只推命令进无锁队列，UI 不等回执
    ref.read(tutorialProvider.notifier).onPad(id.flat, bank);
  }

  void _padUp(int bank, int index) => _engine.padUp(PadId(bank, index));

  void _switchBank() {
    ref.read(bankProvider.notifier).toggle();
    final b = ref.read(bankProvider);
    ref.read(tutorialProvider.notifier)
      ..onBank(b)
      ..settle(b);
  }

  // ------------------------------------------------------------ keyboard

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (!ref.read(settingsProvider).keyboardEnabled) {
      return KeyEventResult.ignored;
    }
    final key = e.physicalKey;
    final index = PadKeyboardMap.pads[key];
    if (e is KeyRepeatEvent) {
      return index != null ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (index != null) {
      final bank = ref.read(bankProvider);
      if (e is KeyDownEvent && !_heldKeys.containsKey(key)) {
        final flat = bank * PadId.padsPerBank + index;
        if (ref.read(engineViewProvider).pads[flat].isEmpty) {
          return KeyEventResult.handled;
        }
        _heldKeys[key] = flat;
        _padDown(bank, index);
        setState(() => _keyPressed.add(flat));
      } else if (e is KeyUpEvent) {
        final flat = _heldKeys.remove(key);
        if (flat != null) {
          _engine.padUp(PadId.flat(flat));
          setState(() => _keyPressed.remove(flat));
        }
      }
      return KeyEventResult.handled;
    }
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (key == PadKeyboardMap.switchBank) {
      _switchBank();
    } else if (key == PadKeyboardMap.stopAll) {
      _engine.send(const StopAllCmd());
    } else if (key == PadKeyboardMap.record) {
      _toggleRecord();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ------------------------------------------------------------- actions

  void _toggleRecord() {
    final recording =
        ref.read(engineViewProvider).recorder == RecorderState.recording;
    _engine.send(
      recording ? const StopRecordingCmd() : const StartRecordingCmd(),
    );
  }

  void _shareKit() {
    final kit = ref.read(engineViewProvider).kit;
    if (kit == null) return;
    SharePlus.instance.share(
      ShareParams(text: context.l10n.shareKitMessage(kit.name)),
    );
  }

  final _speedKey = GlobalKey(debugLabel: 'speed-pill');

  /// 视频教程（外部浏览器 / App 打开；链接来自 assets/config/links.json）。
  Future<void> _openVideo(Uri uri) async {
    final l10n = context.l10n;
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) showUpToast(context, l10n.performVideoOpenFailed);
  }

  /// 速度（4.7.0 只在教程模式出现）：引擎 SetSpeed 实时变速播放，
  /// 教程时间轴同比缩放（见 TutorialController.setSpeed）。
  Future<void> _pickSpeed() async {
    final s = ref.read(tutorialProvider);
    if (s == null) return;
    final v = await showSpeedModal(
      context,
      current: s.speed,
      anchor: _speedKey.currentContext,
    );
    if (v != null) ref.read(tutorialProvider.notifier).setSpeed(v);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = UpTheme.of(context);
    final c = theme.colors;
    final view = ref.watch(engineViewProvider);
    final bank = ref.watch(bankProvider);
    final tutorial = ref.watch(tutorialProvider);
    final settings = ref.watch(settingsProvider);
    final assets = ref.watch(privateAssetsProvider);
    final videoUri = ref
        .watch(appLinksProvider)
        .value
        ?.videoFor(
          languageCode: Localizations.localeOf(context).languageCode,
          kitName: view.kit?.name,
          kitVideoUrl: view.kit?.videoUrl,
        );

    final pads = padDataFrom(view.pads, view.padStates);
    final hasBankB =
        view.kit?.hasBankB ??
        view.pads.skip(PadId.padsPerBank).any((p) => !p.isEmpty);
    final recording = view.recorder == RecorderState.recording;

    // 教程：填充中的 pad 高亮，其余暗化；需要翻页时 A/B 按钮反色提示。
    final fillSecs = TutorialTiming.fill.inMicroseconds / 1e6;
    final tActive = tutorial != null && !tutorial.completed;
    final fills = tActive ? tutorial.fills(fillSecs) : const <int, double>{};
    final needBank = tActive ? tutorial.requiredBank(fillSecs) : null;
    final bankHint = needBank != null && needBank != bank;
    final dimmed = tActive
        ? {
            for (var i = 0; i < PadId.total; i++)
              if (!fills.containsKey(i) && !pads[i].isEmpty) i,
          }
        : const <int>{};

    final bankButton = hasBankB
        ? BankButton(
            label: bank == 0 ? l10n.performBankA : l10n.performBankB,
            hint: bankHint,
            semanticLabel: l10n.performSwitchBank(
              bank == 0 ? l10n.performBankB : l10n.performBankA,
            ),
            onPressed: _switchBank,
          )
        : null;

    final Widget row;
    if (tutorial != null) {
      row = TutorialToolbar(
        key: const ValueKey('tutorial'),
        session: tutorial,
        onPlayPause: () {
          ref.read(tutorialProvider.notifier).togglePlay();
          _lastTick = Duration.zero;
          if (!_ticker.isActive && tutorial.timed) _ticker.start();
        },
        onSeek: (f) => ref.read(tutorialProvider.notifier).seekFraction(f),
        onExit: () => ref.read(tutorialProvider.notifier).stop(),
      );
    } else {
      row = PerformToolbar(
        key: const ValueKey('tools'),
        expanded: _toolsExpanded,
        recording: recording,
        recordElapsed: view.recordElapsed,
        hasKit: view.kit != null,
        hasTutorial: view.kit?.hasTutorial ?? false,
        onExpand: (v) => setState(() => _toolsExpanded = v),
        onTutorial: _toggleTutorial,
        onRecord: _toggleRecord,
        onSkins: () => showSkinsSheet(context),
        onEdit: () => context.push(Routes.editor),
        onShare: _shareKit,
        onSettings: () => context.push(Routes.settings),
      );
    }

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: c.surfacePads,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, body) => Center(
              child: SizedBox(
                width: PerformLayout.columnWidth(body.biggest),
                child: Column(
                  children: [
                    UpTopBar(
                      background: c.surfacePads,
                      leading: UpChip(
                        label: l10n.navSongs,
                        icon: Icons.music_note_rounded,
                        variant: UpChipVariant.selected,
                        onTap: () => context.push(Routes.kits),
                      ),
                      titleWidget: _KitTitle(name: view.kit?.name),
                      trailing: [
                        if (tutorial != null)
                          SpeedPill(
                            key: _speedKey,
                            label: l10n.performSpeedValue(tutorial.speed),
                            onTap: _pickSpeed,
                          ),
                        // 4.7.0 btnYoutube：顶栏最右（教程模式时速度按钮在它左边）。
                        if (videoUri != null)
                          VideoTutorialButton(
                            label: l10n.performVideoPlatform,
                            semanticLabel: l10n.performVideoTutorial,
                            onTap: () => _openVideo(videoUri),
                          ),
                      ],
                    ),
                    SizedBox(
                      height: UpTopBarTokens.bankButtonSize,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: UpMotion.duration(
                                context,
                                UpDurations.medium,
                              ),
                              child: row,
                            ),
                          ),
                          ?bankButton,
                        ],
                      ),
                    ),
                    if (view.controllerMode) const _ControllerBanner(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          UpPadGridTokens.pageInset,
                          UpPadGridTokens.marginTop,
                          UpPadGridTokens.pageInset,
                          UpPadGridTokens.marginBottom,
                        ),
                        // 宽屏：按 4.7.0 fixed_height 等比计算网格尺寸并居中（PerformLayout）。
                        child: LayoutBuilder(
                          builder: (context, box) => Center(
                            child: SizedBox.fromSize(
                              size: PerformLayout.gridSize(box.biggest),
                              child: Stack(
                                children: [
                                  PadGrid(
                                    pads: pads,
                                    bank: bank,
                                    onPadDown: _padDown,
                                    onPadUp: _padUp,
                                    dimmed: dimmed,
                                    fills: fills,
                                    externallyPressed: _keyPressed,
                                    lottie: settings.classicPads
                                        ? classicLottieSkin(assets)
                                        : null,
                                  ),
                                  if (tutorial != null)
                                    Positioned.fill(
                                      child: TutorialFeedbackLayer(
                                        feedback: tutorial.feedback,
                                        bank: bank,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「KIT」(Regular) + Kit 名 (ExtraBold)。
class _KitTitle extends StatelessWidget {
  const _KitTitle({this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    final c = UpTheme.of(context).colors;
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: UpSpacing.xs,
      children: [
        if (name != null)
          UpText(
            l10n.libraryKitBadge,
            role: UpTextRole.body,
            color: c.textPrimary,
          ),
        Flexible(
          child: UpText(
            name ?? l10n.performNoKit,
            role: UpTextRole.title,
            color: c.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ControllerBanner extends ConsumerWidget {
  const _ControllerBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = UpTheme.of(context).colors;
    final hub = ref.watch(hubViewProvider);
    return Container(
      color: c.hubOnline,
      padding: const EdgeInsets.symmetric(
        horizontal: UpSpacing.xl,
        vertical: UpSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(
            Icons.cast_connected_rounded,
            size: UpSizes.iconSm,
            color: c.textOnAccent,
          ),
          const SizedBox(width: UpSpacing.sm),
          Expanded(
            child: UpText(
              context.l10n.hubControlling(hub.controllerPeer?.name ?? ''),
              role: UpTextRole.labelSm,
              color: c.textOnAccent,
            ),
          ),
          UpIconButton(
            icon: Icons.close_rounded,
            color: c.textOnAccent,
            semanticLabel: context.l10n.commonClose,
            onPressed: () =>
                tryEngine(ref.read(engineProvider).hubControllerDisconnect),
          ),
        ],
      ),
    );
  }
}
