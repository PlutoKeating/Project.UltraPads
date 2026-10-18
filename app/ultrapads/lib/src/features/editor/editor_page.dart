import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../routing/routes.dart';
import '../../state/engine_state.dart';
import '../perform/pad_mapping.dart';
import 'sample_pickers.dart';

/// 编辑 Kit（4.7.0 `CreateKit/Main`）：
/// 顶栏（✕ / 标题 / SAVE）→ A/B 迷你 pad 面板（选 pad）→
/// 底部面板：LOAD SOUND（5 个来源）| EDIT PAD（颜色、Loop、分组、音量、裁剪、复制、清空）。
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  KitDoc? _doc;
  bool _dirty = false;
  bool _unsupported = false;
  int _selected = 0;
  int _tab = 0;

  /// 裁剪视图打开的 pad。
  bool _trimming = false;

  static const _maxTrimSecs = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  EngineClient get _engine => ref.read(engineProvider);

  Future<void> _load() async {
    final kit = _engine.snapshot().kit;
    KitDoc? doc;
    if (kit != null) doc = await tryEngine(() => _engine.libraryGetKit(kit.id));
    if (!mounted) return;
    setState(() {
      _unsupported = kit != null && doc == null;
      _doc =
          doc ??
          KitDoc(
            id: 'user:${DateTime.now().millisecondsSinceEpoch}',
            name: context.l10n.kitEditorNewKit,
            pads: List.filled(PadId.total, PadParams.empty),
          );
    });
  }

  PadParams get _pad => _doc!.pads[_selected];

  void _update(PadParams p) {
    final id = PadId.flat(_selected);
    setState(() {
      _doc = _doc!.withPad(id, p);
      _dirty = true;
    });
    // 正在编辑当前 Kit 时实时生效（引擎为唯一事实源，演奏页立刻听到修改）。
    if (_engine.snapshot().kit?.id == _doc!.id) {
      _engine.send(SetPadParamsCmd(id, p));
    }
  }

  Future<void> _assign(SampleInfo s) async {
    final l10n = context.l10n;
    if (!_pad.isEmpty) {
      final ok = await showUpConfirm(
        context,
        title: l10n.kitEditorReplaceTitle,
        confirm: l10n.commonConfirm,
        cancel: l10n.commonCancel,
      );
      if (!ok) return;
    }
    final maxFrames = s.sampleRate * _maxTrimSecs;
    _update(
      _pad.copyWith(
        sample: () => s.id,
        startFrame: 0,
        endFrame: () => s.frames > maxFrames ? maxFrames : null,
        color: _pad.isEmpty ? ColorRole.fromPalette(_selected) : null,
      ),
    );
    setState(() => _tab = 1);
  }

  Future<void> _pickSource(int source) async {
    final l10n = context.l10n;
    SampleInfo? s;
    switch (source) {
      case 0 || 3:
        s = await pickKitSample(context, ref, ownKitsOnly: source == 3);
      case 1:
        s = await context.push<SampleInfo>(Routes.micSampler);
      case 2:
        final files = await FilePicker.pickFiles(type: FileType.audio);
        final path = files.firstOrNull?.path;
        if (path == null) return;
        final report = await tryEngine(() => _engine.libraryImport(path));
        if (report == null) {
          if (mounted) showUpToast(context, l10n.errorEngineUnsupported);
          return;
        }
        s = report.samples.firstOrNull;
        if (s == null && mounted) {
          showUpToast(context, l10n.errorUnsupportedFormat);
        }
      case 4:
        s = await pickRecordingSample(context, ref);
    }
    if (s != null && mounted) await _assign(s);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final ok = await tryEngineDo(() => _engine.librarySaveKit(_doc!));
    if (!mounted) return;
    if (!ok) {
      showUpToast(context, l10n.errorEngineUnsupported);
      return;
    }
    setState(() => _dirty = false);
    showUpToast(context, l10n.kitEditorSaved);
  }

  Future<void> _close() async {
    final l10n = context.l10n;
    if (_dirty) {
      final leave = await showUpConfirm(
        context,
        title: l10n.kitEditorUnsavedTitle,
        message: l10n.kitEditorUnsavedBody,
        confirm: l10n.kitEditorDiscard,
        cancel: l10n.commonCancel,
        danger: true,
      );
      if (!leave) return;
      // 放弃：把引擎里的当前 Kit 恢复到磁盘版本。
      final kit = _engine.snapshot().kit;
      if (kit != null && kit.id == _doc?.id) {
        await tryEngine(() => _engine.libraryLoadKit(kit.id));
      }
    }
    if (mounted) context.pop();
  }

  void _clone() {
    // 复制到下一个空 pad（4.7.0 CLONE）。
    final target = _doc!.pads.indexWhere((p) => p.isEmpty);
    if (target < 0) return;
    final from = _pad;
    final id = PadId.flat(target);
    setState(() {
      _doc = _doc!.withPad(id, from);
      _dirty = true;
      _selected = target;
    });
    if (_engine.snapshot().kit?.id == _doc!.id) {
      _engine.send(SetPadParamsCmd(id, from));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = UpTheme.of(context);
    final c = theme.colors;
    final doc = _doc;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        // 4.7.0：编辑 Kit 整页粉色底（#EE4286 → primitive swatch.mediumPink）。
        backgroundColor: UpPrimitiveColors.swatchMediumPink,
        body: SafeArea(
          child: doc == null
              ? const Center(child: UpProgressRing())
              : Column(
                  children: [
                    UpTopBar(
                      background: UpPrimitiveColors.baseTransparent,
                      leading: UpIconButton(
                        icon: Icons.close_rounded,
                        semanticLabel: l10n.commonClose,
                        onPressed: _close,
                      ),
                      title: doc.name,
                      centerTitle: true,
                      trailing: [
                        UpButton(
                          label: l10n.commonSave,
                          variant: UpButtonVariant.outline,
                          size: UpButtonSize.sm,
                          onPressed: _dirty ? _save : null,
                        ),
                      ],
                    ),
                    if (_unsupported)
                      Padding(
                        padding: const EdgeInsets.all(UpSpacing.sm),
                        child: UpText(
                          l10n.errorEngineUnsupported,
                          role: UpTextRole.caption,
                          color: c.textOnAccent,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(UpPageTokens.paddingX),
                      child: _MiniPads(
                        doc: doc,
                        selected: _selected,
                        onSelect: (i) => setState(() {
                          _selected = i;
                          _trimming = false;
                        }),
                        onAudition: (i) {
                          if (_engine.snapshot().kit?.id == doc.id) {
                            _engine.padDown(PadId.flat(i));
                            _engine.padUp(PadId.flat(i));
                          } else if (doc.pads[i].sample != null) {
                            tryEngine(
                              () => _engine.samplePreview(doc.pads[i].sample!),
                            );
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: c.sheetBackground,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(UpSheetTokens.radius),
                          ),
                        ),
                        child: Column(
                          children: [
                            UpSegmentTabs(
                              labels: [
                                l10n.loadSoundTitle,
                                l10n.kitEditorEditPad,
                              ],
                              index: _tab,
                              onChanged: (i) => setState(() => _tab = i),
                            ),
                            Expanded(
                              child: _tab == 0
                                  ? _LoadSoundList(onPick: _pickSource)
                                  : _pad.isEmpty
                                  ? Center(
                                      child: UpText(
                                        l10n.kitEditorSelectPad,
                                        role: UpTextRole.body,
                                        color: c.textSecondary,
                                      ),
                                    )
                                  : _trimming
                                  ? _TrimView(
                                      params: _pad,
                                      maxSecs: _maxTrimSecs,
                                      onChanged: _update,
                                      onDone: () =>
                                          setState(() => _trimming = false),
                                    )
                                  : _EditPadPanel(
                                      params: _pad,
                                      onChanged: _update,
                                      onTrim: () =>
                                          setState(() => _trimming = true),
                                      onClone: _clone,
                                      onClear: () => _update(PadParams.empty),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// A / B 两个迷你 pad 面板，点选 pad；双击试听。
class _MiniPads extends StatelessWidget {
  const _MiniPads({
    required this.doc,
    required this.selected,
    required this.onSelect,
    required this.onAudition,
  });
  final KitDoc doc;
  final int selected;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onAudition;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final data = padDataFrom(
      doc.pads,
      List.filled(PadId.total, PadPlayState.idle),
    );
    Widget panel(int bank) => Expanded(
      child: Column(
        spacing: UpSpacing.xs,
        children: [
          UpText(
            bank == 0 ? l10n.performBankA : l10n.performBankB,
            role: UpTextRole.label,
            color: c.textOnAccent,
          ),
          AspectRatio(
            aspectRatio: PadId.columns / PadId.rows,
            child: Container(
              padding: const EdgeInsets.all(UpSpacing.sm),
              decoration: BoxDecoration(
                color: c.surfaceDim,
                borderRadius: BorderRadius.circular(UpRadii.lg),
              ),
              child: GridView.count(
                crossAxisCount: PadId.columns,
                mainAxisSpacing: UpSpacing.xs,
                crossAxisSpacing: UpSpacing.xs,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < PadId.padsPerBank; i++)
                    Semantics(
                      button: true,
                      selected: selected == bank * PadId.padsPerBank + i,
                      label: l10n.performPadLabel(i + 1),
                      child: GestureDetector(
                        onTap: () => onSelect(bank * PadId.padsPerBank + i),
                        onDoubleTap: () =>
                            onAudition(bank * PadId.padsPerBank + i),
                        child: UpPad(
                          data: data[bank * PadId.padsPerBank + i],
                          selected: selected == bank * PadId.padsPerBank + i,
                          showLabel: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return Row(spacing: UpSpacing.lg, children: [panel(0), panel(1)]);
  }
}

/// LOAD SOUND：5 个来源（内置歌曲 / 麦克风 / 本地文件 / 其他 Kit / 录音）。
class _LoadSoundList extends StatelessWidget {
  const _LoadSoundList({required this.onPick});
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      (
        Icons.grid_view_rounded,
        l10n.loadSoundImportFrom,
        l10n.loadSoundSourceSongs,
      ),
      (
        Icons.mic_rounded,
        l10n.loadSoundRecordingFrom,
        l10n.loadSoundSourceMicrophone,
      ),
      (
        Icons.audio_file_rounded,
        l10n.loadSoundImportFrom,
        l10n.loadSoundSourceFiles,
      ),
      (
        Icons.person_rounded,
        l10n.loadSoundImportFrom,
        l10n.loadSoundSourceKits,
      ),
      (
        Icons.mic_external_on_rounded,
        l10n.loadSoundImportFrom,
        l10n.loadSoundSourceRecordings,
      ),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(UpPageTokens.paddingX),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: UpSheetTokens.itemGap),
      itemBuilder: (_, i) => UpListItem(
        icon: items[i].$1,
        overline: items[i].$2,
        title: items[i].$3,
        onTap: () => onPick(i),
      ),
    );
  }
}

/// EDIT PAD：颜色、Loop、分组、音量、编辑（裁剪）、复制、清空。
class _EditPadPanel extends StatelessWidget {
  const _EditPadPanel({
    required this.params,
    required this.onChanged,
    required this.onTrim,
    required this.onClone,
    required this.onClear,
  });

  final PadParams params;
  final ValueChanged<PadParams> onChanged;
  final VoidCallback onTrim;
  final VoidCallback onClone;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = UpTheme.of(context);
    final c = theme.colors;
    Widget label(String s) =>
        UpText(s, role: UpTextRole.label, color: c.textSecondary);
    Widget stepper(
      String title,
      String value,
      VoidCallback? minus,
      VoidCallback? plus,
    ) => Row(
      children: [
        Expanded(child: label(title)),
        UpIconButton(
          icon: Icons.remove_rounded,
          semanticLabel: title,
          onPressed: minus,
        ),
        SizedBox(
          width: UpButtonTokens.minWidth,
          child: UpText(
            value,
            role: UpTextRole.numeric,
            color: c.textPrimary,
            align: TextAlign.center,
          ),
        ),
        UpIconButton(
          icon: Icons.add_rounded,
          semanticLabel: title,
          onPressed: plus,
        ),
      ],
    );
    final group = params.chokeGroup;
    final volumeStep = UpOpacities.faint;
    return ListView(
      padding: const EdgeInsets.all(UpPageTokens.paddingX),
      children: [
        label(l10n.kitEditorPadColor),
        const SizedBox(height: UpSpacing.sm),
        UpSwatchRow(
          colors: [
            for (final r in ColorRole.palette)
              theme.padRole(r.paletteIndex).mid,
          ],
          selected: params.color.paletteIndex,
          onSelected: (i) =>
              onChanged(params.copyWith(color: ColorRole.fromPalette(i))),
        ),
        const SizedBox(height: UpSpacing.lg),
        UpSwitchRow(
          title: l10n.kitEditorLoop,
          value: params.mode == PadMode.loop,
          onChanged: (v) => onChanged(
            params.copyWith(mode: v ? PadMode.loop : PadMode.oneShot),
          ),
        ),
        const SizedBox(height: UpSpacing.sm),
        UpSwitchRow(
          title: l10n.performPadModeGate,
          value: params.mode == PadMode.gate,
          onChanged: (v) => onChanged(
            params.copyWith(mode: v ? PadMode.gate : PadMode.oneShot),
          ),
        ),
        stepper(
          l10n.kitEditorGroup,
          group == null
              ? l10n.commonNone
              : l10n.kitEditorChokeGroupValue(group),
          group == null
              ? null
              : () => onChanged(
                  params.copyWith(
                    chokeGroup: () => group <= 1 ? null : group - 1,
                  ),
                ),
          (group ?? 0) >= PadId.padsPerBank
              ? null
              : () => onChanged(
                  params.copyWith(chokeGroup: () => (group ?? 0) + 1),
                ),
        ),
        stepper(
          l10n.kitEditorVolume,
          '${(params.gain * 100).round()}%',
          params.gain <= 0
              ? null
              : () => onChanged(
                  params.copyWith(
                    gain: (params.gain - volumeStep).clamp(0.0, 1.0),
                  ),
                ),
          params.gain >= 1
              ? null
              : () => onChanged(
                  params.copyWith(
                    gain: (params.gain + volumeStep).clamp(0.0, 1.0),
                  ),
                ),
        ),
        // 4.7.0 EDIT PAD：PITCH ±（半音，引擎以播放速率实时实现）。
        stepper(
          l10n.kitEditorPitch,
          l10n.kitEditorPitchValue(_signed(params.pitch.round())),
          params.pitch <= PadParams.pitchMin
              ? null
              : () => onChanged(
                  params.copyWith(
                    pitch: (params.pitch.roundToDouble() - 1).clamp(
                      PadParams.pitchMin,
                      PadParams.pitchMax,
                    ),
                  ),
                ),
          params.pitch >= PadParams.pitchMax
              ? null
              : () => onChanged(
                  params.copyWith(
                    pitch: (params.pitch.roundToDouble() + 1).clamp(
                      PadParams.pitchMin,
                      PadParams.pitchMax,
                    ),
                  ),
                ),
        ),
        Row(
          children: [
            Expanded(child: label(l10n.kitEditorPan)),
            Expanded(
              flex: 2,
              child: UpSlider(
                value: params.pan,
                min: -1,
                max: 1,
                semanticLabel: l10n.kitEditorPan,
                onChanged: (v) => onChanged(params.copyWith(pan: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: UpSpacing.lg),
        Wrap(
          spacing: UpSpacing.md,
          runSpacing: UpSpacing.md,
          children: [
            UpButton(
              label: l10n.kitEditorEditFile,
              icon: Icons.content_cut_rounded,
              variant: UpButtonVariant.secondary,
              onPressed: onTrim,
            ),
            UpButton(
              label: l10n.kitEditorClone,
              icon: Icons.copy_rounded,
              variant: UpButtonVariant.secondary,
              onPressed: onClone,
            ),
            UpButton(
              label: l10n.kitEditorClearPad,
              icon: Icons.delete_rounded,
              variant: UpButtonVariant.danger,
              onPressed: onClear,
            ),
          ],
        ),
      ],
    );
  }
}

/// EDIT FILE：波形 + 首尾拖杆裁剪（最长 30 s）+ 试听。
class _TrimView extends ConsumerWidget {
  const _TrimView({
    required this.params,
    required this.maxSecs,
    required this.onChanged,
    required this.onDone,
  });
  final PadParams params;
  final int maxSecs;
  final ValueChanged<PadParams> onChanged;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final sample = params.sample!;
    final info = ref.watch(_sampleInfoProvider(sample)).value;
    final peaks =
        ref
            .watch(
              waveformProvider((
                sample: sample,
                buckets: UpWaveformTokens.height.toInt() * 2,
              )),
            )
            .value ??
        const [];
    final frames = info?.frames ?? 0;
    final start = frames == 0 ? 0.0 : params.startFrame / frames;
    final end = frames == 0 ? 1.0 : (params.endFrame ?? frames) / frames;
    return ListView(
      padding: const EdgeInsets.all(UpPageTokens.paddingX),
      children: [
        Semantics(
          label: l10n.a11yWaveform(info?.name ?? sample),
          child: WaveformView(
            peaks: peaks,
            height: UpWaveformTokens.height * 2,
            selection: (start, end),
            onSelectionChanged: frames == 0
                ? null
                : (sel) {
                    final s = (sel.$1 * frames).round();
                    var e = (sel.$2 * frames).round();
                    final max = (info!.sampleRate * maxSecs);
                    if (e - s > max) e = s + max;
                    onChanged(
                      params.copyWith(
                        startFrame: s,
                        endFrame: () => e >= frames ? null : e,
                      ),
                    );
                  },
          ),
        ),
        const SizedBox(height: UpSpacing.sm),
        UpText(
          l10n.kitEditorMaxLength(maxSecs),
          role: UpTextRole.caption,
          color: c.textSecondary,
        ),
        const SizedBox(height: UpSpacing.lg),
        Wrap(
          spacing: UpSpacing.md,
          children: [
            UpButton(
              label: l10n.kitEditorPreview,
              icon: Icons.play_arrow_rounded,
              variant: UpButtonVariant.secondary,
              onPressed: () => tryEngine(
                () => ref
                    .read(engineProvider)
                    .samplePreview(
                      sample,
                      startFrame: params.startFrame,
                      endFrame: params.endFrame,
                    ),
              ),
            ),
            UpButton(label: l10n.commonDone, onPressed: onDone),
          ],
        ),
      ],
    );
  }
}

final _sampleInfoProvider = FutureProvider.family<SampleInfo?, String>(
  (ref, id) => tryEngine(() => ref.watch(engineProvider).sampleInfo(id)),
);

/// `3` → `+3`，`-2` → `-2`，`0` → `0`（数字格式，非文案）。
String _signed(int v) => v > 0 ? '+$v' : '$v';
