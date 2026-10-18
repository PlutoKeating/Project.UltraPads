import 'package:flutter/material.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../skins/skins_sheet.dart';
import 'component_gallery.dart';
import 'token_browser.dart';

/// 设计画廊 ④ 动效演示：pad 按下/松开、Loop 闪烁与旋转、A/B 翻页、
/// 皮肤面板、速度面板、录音按钮。参数全部来自 token（列出数值便于核对）。
class MotionGallery extends StatefulWidget {
  const MotionGallery({super.key});

  @override
  State<MotionGallery> createState() => _MotionGalleryState();
}

class _MotionGalleryState extends State<MotionGallery> {
  bool _pressed = false;
  int _bank = 0;
  bool _recording = false;

  String _ms(Duration d) => '${d.inMilliseconds} ms';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    Widget caption(String s) => Padding(
      padding: const EdgeInsets.only(top: UpSpacing.xs),
      child: UpText(
        s,
        role: UpTextRole.caption,
        color: c.textMuted,
        maxLines: 3,
      ),
    );
    final cell = UpPadTokens.cellWidth;
    return ListView(
      padding: const EdgeInsets.all(UpPageTokens.paddingX),
      children: [
        GallerySection(
          title: '${l10n.settingsGalleryPressed} / ${l10n.performPadStateIdle}',
        ),
        Row(
          spacing: UpSpacing.lg,
          children: [
            Listener(
              onPointerDown: (_) => setState(() => _pressed = true),
              onPointerUp: (_) => setState(() => _pressed = false),
              onPointerCancel: (_) => setState(() => _pressed = false),
              child: SizedBox.square(
                dimension: cell,
                child: UpPad(
                  data: const PadData(role: 1),
                  pressed: _pressed,
                  pressOrigin: Offset(cell / 2, cell / 2),
                ),
              ),
            ),
            Expanded(
              child: caption(
                'pressAttack ${_ms(UpPadTokens.pressAttack)} · pressRelease ${_ms(UpPadTokens.pressRelease)} quadOut · scale ${UpTheme.of(context).colors.padPressedScale}',
              ),
            ),
          ],
        ),
        GallerySection(
          title: '${l10n.performPadModeLoop} · ${l10n.performPadStatePlaying}',
        ),
        Row(
          spacing: UpSpacing.lg,
          children: [
            SizedBox.square(
              dimension: cell,
              child: const UpPad(
                data: PadData(
                  role: 3,
                  loop: true,
                  state: PadVisualState.playing,
                ),
              ),
            ),
            Expanded(
              child: caption(
                'loopFlashHalf ${_ms(UpPadTokens.loopFlashHalf)} yoyo · loopRevolution ${_ms(UpPadTokens.loopRevolution)} linear',
              ),
            ),
          ],
        ),
        GallerySection(
          title: l10n.performSwitchBank(
            _bank == 0 ? l10n.performBankB : l10n.performBankA,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: cell * 2,
                child: InteractivePadGrid(bank: _bank),
              ),
            ),
            BankButton(
              label: _bank == 0 ? l10n.performBankA : l10n.performBankB,
              onPressed: () => setState(() => _bank = 1 - _bank),
            ),
          ],
        ),
        caption('bankSwitch ${_ms(UpPadGridTokens.bankSwitch)} quadOut'),
        GallerySection(
          title: l10n.performSkins,
        ),
        Wrap(
          spacing: UpSpacing.md,
          runSpacing: UpSpacing.md,
          children: [
            UpButton(
              label: l10n.performSkins,
              variant: UpButtonVariant.secondary,
              onPressed: () => showSkinsSheet(context),
            ),
          ],
        ),
        caption(
          'sheet ${_ms(UpSheetTokens.enter)}',
        ),
        GallerySection(title: l10n.performRecord),
        Row(
          spacing: UpSpacing.lg,
          children: [
            RecordButton(
              recording: _recording,
              onPressed: () => setState(() => _recording = !_recording),
              elapsedLabel: l10n.loadSoundElapsed(0),
            ),
            Expanded(
              child: caption(
                'pulse ${_ms(UpRecordTokens.pulse)} × ${UpRecordTokens.pulseScale} · ripple ${_ms(UpRecordTokens.ripple)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: UpSpacing.giant),
      ],
    );
  }
}
