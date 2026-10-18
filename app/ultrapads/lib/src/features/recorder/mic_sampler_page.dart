import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_fx/up_fx.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../state/engine_state.dart';

/// 麦克风采样（参考设计：大红录音按钮 170×170，录音时 0.6 s 脉冲；波形预览；SAVE）。
/// 返回 [SampleInfo]（`context.pop(sample)`）。
class MicSamplerPage extends ConsumerStatefulWidget {
  const MicSamplerPage({super.key});

  @override
  ConsumerState<MicSamplerPage> createState() => _MicSamplerPageState();
}

class _MicSamplerPageState extends ConsumerState<MicSamplerPage>
    with SingleTickerProviderStateMixin {
  bool? _granted;
  bool _permanentlyDenied = false;
  bool _recording = false;
  SampleInfo? _result;
  final _watch = Stopwatch();
  Timer? _timer;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: UpTrackCardTokens.recTransition,
  );

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    if (_recording) tryEngine(ref.read(engineProvider).samplerRecordStop);
    super.dispose();
  }

  bool get _needsRuntimePermission =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> _checkPermission() async {
    if (!_needsRuntimePermission) {
      setState(() => _granted = true);
      return;
    }
    final status = await Permission.microphone.request();
    if (!mounted) return;
    setState(() {
      _granted = status.isGranted;
      _permanentlyDenied = status.isPermanentlyDenied;
    });
  }

  Future<void> _start() async {
    final ok = await tryEngineDo(
      () => ref.read(engineProvider).samplerRecordStart(),
    );
    if (!mounted) return;
    if (!ok) {
      showUpToast(context, context.l10n.errorEngineUnsupported);
      return;
    }
    _watch
      ..reset()
      ..start();
    _timer = Timer.periodic(UpDurations.fast, (_) => setState(() {}));
    if (!FxMotion.reduce(context)) _pulse.repeat(reverse: true);
    setState(() {
      _recording = true;
      _result = null;
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _watch.stop();
    _pulse
      ..stop()
      ..value = 0;
    final s = await tryEngine(ref.read(engineProvider).samplerRecordStop);
    if (!mounted) return;
    setState(() {
      _recording = false;
      _result = s;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final result = _result;
    final peaks = result == null
        ? const <double>[]
        : ref
                  .watch(
                    waveformProvider((
                      sample: result.id,
                      buckets: UpWaveformTokens.height.toInt() * 2,
                    )),
                  )
                  .value ??
              const [];
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
              title: l10n.loadSoundSourceMicrophone,
              centerTitle: true,
            ),
            Expanded(
              child: switch (_granted) {
                null => const Center(child: UpProgressRing()),
                false => Padding(
                  padding: const EdgeInsets.all(UpSpacing.xxxl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: UpSpacing.lg,
                    children: [
                      Icon(
                        Icons.mic_off_rounded,
                        size: UpSizes.iconXxl,
                        color: c.iconSecondary,
                      ),
                      UpText(
                        l10n.permissionMicrophoneTitle,
                        role: UpTextRole.title,
                        color: c.textPrimary,
                        align: TextAlign.center,
                      ),
                      UpText(
                        l10n.permissionMicrophoneBody,
                        role: UpTextRole.body,
                        color: c.textSecondary,
                        align: TextAlign.center,
                        maxLines: 4,
                      ),
                      UpButton(
                        label: _permanentlyDenied
                            ? l10n.permissionOpenSettings
                            : l10n.permissionAllow,
                        onPressed: _permanentlyDenied
                            ? openAppSettings
                            : _checkPermission,
                      ),
                    ],
                  ),
                ),
                true => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    UpText(
                      l10n.loadSoundElapsed(_watch.elapsed.inSeconds),
                      role: UpTextRole.display,
                      color: _recording ? c.statusRecording : c.textPrimary,
                    ),
                    const SizedBox(height: UpSpacing.xxl),
                    Semantics(
                      button: true,
                      label: _recording ? l10n.recordStop : l10n.recordStart,
                      child: GestureDetector(
                        onTap: _recording ? _stop : _start,
                        child: AnimatedBuilder(
                          animation: _pulse,
                          builder: (context, _) => Container(
                            width: UpSizes.controlXl * 2,
                            height: UpSizes.controlXl * 2,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.statusRecording,
                              boxShadow: UpPadTokens.glowPlaying.shadows(
                                c.statusRecording,
                                intensity: _pulse.value,
                              ),
                            ),
                            child: Icon(
                              _recording
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                              size: UpSizes.iconXxl,
                              color: c.iconOnAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: UpSpacing.lg),
                    UpText(
                      l10n.loadSoundHoldToRecord,
                      role: UpTextRole.caption,
                      color: c.textSecondary,
                    ),
                    if (result != null) ...[
                      Padding(
                        padding: const EdgeInsets.all(UpPageTokens.paddingX),
                        child: WaveformView(peaks: peaks),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: UpSpacing.md,
                        children: [
                          UpButton(
                            label: l10n.kitEditorPreview,
                            icon: Icons.play_arrow_rounded,
                            variant: UpButtonVariant.secondary,
                            onPressed: () => tryEngine(
                              () => ref
                                  .read(engineProvider)
                                  .samplePreview(result.id),
                            ),
                          ),
                          UpButton(
                            label: l10n.commonSave,
                            onPressed: () => context.pop(result),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}
