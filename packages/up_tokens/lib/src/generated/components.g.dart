// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: design/tokens/src (W3C DTCG) -> Style Dictionary -> design/tokens/scripts/build.mjs
// Regenerate with `just tokens` (cd design/tokens && pnpm run build).
// ignore_for_file: type=lint, unused_import

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../runtime/glow.dart';
import '../runtime/gradient.dart';
import '../runtime/text_role.dart';

/// Component tokens for `transport` (theme-independent geometry, motion and glow recipes).
abstract final class UpTransportTokens {
  /// Token: `transport.speedWidth`
  static const double speedWidth = 73;

  /// Token: `transport.speedHeight`
  static const double speedHeight = 39;

  /// Token: `transport.playSize`
  static const double playSize = 50;

  /// Token: `transport.gap`
  static const double gap = 12;

  /// Ref tutorial row 100px
  ///
  /// Token: `transport.height`
  static const double height = 50;

  /// Ref play/stop block 84px
  ///
  /// Token: `transport.stopSize`
  static const double stopSize = 42;
}

/// Component tokens for `chip` (theme-independent geometry, motion and glow recipes).
abstract final class UpChipTokens {
  /// Ref SONGS button 63 px
  ///
  /// Token: `chip.height`
  static const double height = 31.5;

  /// Token: `chip.radius`
  static const double radius = 4;

  /// Token: `chip.paddingX`
  static const double paddingX = 8;

  /// Token: `chip.iconBoxWidth`
  static const double iconBoxWidth = 31.5;

  /// Token: `chip.iconSize`
  static const double iconSize = 16;

  /// Token: `chip.gap`
  static const double gap = 8;
}

/// Component tokens for `banner` (theme-independent geometry, motion and glow recipes).
abstract final class UpBannerTokens {
  /// Token: `banner.width`
  static const double width = 244.5;

  /// Token: `banner.height`
  static const double height = 137;

  /// Token: `banner.radius`
  static const double radius = 8;

  /// Ref pagination 50x10 px
  ///
  /// Token: `banner.indicatorWidth`
  static const double indicatorWidth = 25;

  /// Token: `banner.indicatorHeight`
  static const double indicatorHeight = 5;

  /// Token: `banner.indicatorGap`
  static const double indicatorGap = 6;

  /// Token: `banner.signatureHeight`
  static const double signatureHeight = 104;

  /// Token: `banner.autoplay`
  static const Duration autoplay = Duration(milliseconds: 4000);

  /// Token: `banner.transition`
  static const Duration transition = Duration(milliseconds: 400);

  /// Token: `banner.transitionCurve`
  static const Cubic transitionCurve = Cubic(0.25, 0.46, 0.45, 0.94);

  /// UP: card 137 + pagination row
  ///
  /// Token: `banner.holderHeight`
  static const double holderHeight = 147;

  /// Ref pagination dot height 10px
  ///
  /// Token: `banner.indicatorSize`
  static const double indicatorSize = 5;
}

/// Component tokens for `sheet` (theme-independent geometry, motion and glow recipes).
abstract final class UpSheetTokens {
  /// Ref skin panel 488 px, slides from the bottom
  ///
  /// Token: `sheet.height`
  static const double height = 244;

  /// Token: `sheet.radius`
  static const double radius = 0;

  /// Token: `sheet.headerHeight`
  static const double headerHeight = 50;

  /// Token: `sheet.itemSize`
  static const double itemSize = 115;

  /// Token: `sheet.thumbSize`
  static const double thumbSize = 75;

  /// Ref pink 2 px divider
  ///
  /// Token: `sheet.dividerHeight`
  static const double dividerHeight = 1;

  /// UP
  ///
  /// Token: `sheet.handleWidth`
  static const double handleWidth = 36;

  /// Token: `sheet.handleHeight`
  static const double handleHeight = 4;

  /// Ref 0.4 s QuadOut
  ///
  /// Token: `sheet.enter`
  static const Duration enter = Duration(milliseconds: 400);

  /// Token: `sheet.exit`
  static const Duration exit = Duration(milliseconds: 400);

  /// Token: `sheet.curve`
  static const Cubic curve = Cubic(0.25, 0.46, 0.45, 0.94);

  /// Token: `sheet.spring`
  static const SpringDescription spring = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 36,
  );

  /// Ref LOAD SOUND row step 140 - row 132 px = 8px
  ///
  /// Token: `sheet.itemGap`
  static const double itemGap = 4;

  /// Token: `sheet.footerHeight`
  static const double footerHeight = 50;

  /// Token: `sheet.maxWidth`
  static const double maxWidth = 250;
}

/// Component tokens for `badge` (theme-independent geometry, motion and glow recipes).
abstract final class UpBadgeTokens {
  /// Token: `badge.height`
  static const double height = 16;

  /// Token: `badge.radius`
  static const double radius = 999;

  /// Token: `badge.paddingX`
  static const double paddingX = 6;
}

/// Component tokens for `button` (theme-independent geometry, motion and glow recipes).
abstract final class UpButtonTokens {
  /// Ref btn 500x100 px
  ///
  /// Token: `button.width`
  static const double width = 250;

  /// Token: `button.height`
  static const double height = 50;

  /// Token: `button.heightSm`
  static const double heightSm = 33.5;

  /// Token: `button.heightLg`
  static const double heightLg = 62;

  /// UP
  ///
  /// Token: `button.minWidth`
  static const double minWidth = 88;

  /// Token: `button.seeAllWidth`
  static const double seeAllWidth = 168;

  /// Token: `button.radius`
  static const double radius = 4;

  /// Token: `button.pillRadius`
  static const double pillRadius = 999;

  /// Token: `button.paddingX`
  static const double paddingX = 16;

  /// Token: `button.iconSize`
  static const double iconSize = 20;

  /// Token: `button.gap`
  static const double gap = 8;

  /// Token: `button.borderWidth`
  static const double borderWidth = 2;

  /// UP
  ///
  /// Token: `button.pressScale`
  static const double pressScale = 0.97;

  /// Token: `button.press`
  static const Duration press = Duration(milliseconds: 100);

  /// Ref btn 500px
  ///
  /// Token: `button.wideWidth`
  static const double wideWidth = 250;
}

/// Component tokens for `input` (theme-independent geometry, motion and glow recipes).
abstract final class UpInputTokens {
  /// Token: `input.width`
  static const double width = 333.5;

  /// Token: `input.height`
  static const double height = 60.5;

  /// Ref label move + colour 0.4 s QuadOut
  ///
  /// Token: `input.labelFloat`
  static const Duration labelFloat = Duration(milliseconds: 400);

  /// Token: `input.curve`
  static const Cubic curve = Cubic(0.25, 0.46, 0.45, 0.94);
}

/// Component tokens for `slider` (theme-independent geometry, motion and glow recipes).
abstract final class UpSliderTokens {
  /// Token: `slider.width`
  static const double width = 255.5;

  /// Token: `slider.trackHeight`
  static const double trackHeight = 5;

  /// Ref grip 50 px
  ///
  /// Token: `slider.thumbSize`
  static const double thumbSize = 25;

  /// Token: `slider.thumbSizeActive`
  static const double thumbSizeActive = 25;

  /// Token: `slider.insetX`
  static const double insetX = 20;
}

/// Component tokens for `dialog` (theme-independent geometry, motion and glow recipes).
abstract final class UpDialogTokens {
  /// Ref rate dialog 606 px
  ///
  /// Token: `dialog.width`
  static const double width = 303;

  /// Token: `dialog.radius`
  static const double radius = 12;

  /// Token: `dialog.padding`
  static const double padding = 24;

  /// Token: `dialog.gap`
  static const double gap = 16;

  /// Token: `dialog.maxWidth`
  static const double maxWidth = 337.5;

  /// Token: `dialog.shadow`
  static const List<BoxShadow> shadow = <BoxShadow>[
    BoxShadow(
      color: Color(0xA0000000),
      offset: Offset(0, 10),
      blurRadius: 28,
      spreadRadius: 0,
    ),
  ];

  /// Token: `dialog.enter`
  static const Duration enter = Duration(milliseconds: 300);

  /// Token: `dialog.curve`
  static const Cubic curve = Cubic(0.25, 0.46, 0.45, 0.94);
}

/// Component tokens for `toast` (theme-independent geometry, motion and glow recipes).
abstract final class UpToastTokens {
  /// Token: `toast.radius`
  static const double radius = 8;

  /// Token: `toast.padding`
  static const double padding = 12;

  /// Token: `toast.visible`
  static const Duration visible = Duration(milliseconds: 2500);
}

/// Component tokens for `meter` (theme-independent geometry, motion and glow recipes).
abstract final class UpMeterTokens {
  /// Token: `meter.width`
  static const double width = 6;

  /// Token: `meter.radius`
  static const double radius = 3;

  /// Token: `meter.segmentGap`
  static const double segmentGap = 1;

  /// Token: `meter.midThreshold`
  static const double midThreshold = 0.7;

  /// Token: `meter.highThreshold`
  static const double highThreshold = 0.9;

  /// Token: `meter.peakHold`
  static const Duration peakHold = Duration(milliseconds: 1000);

  /// Token: `meter.decay`
  static const Duration decay = Duration(milliseconds: 300);
}

/// Component tokens for `waveform` (theme-independent geometry, motion and glow recipes).
abstract final class UpWaveformTokens {
  /// Token: `waveform.width`
  static const double width = 390.5;

  /// Token: `waveform.height`
  static const double height = 111;

  /// UP
  ///
  /// Token: `waveform.barWidth`
  static const double barWidth = 3;

  /// Token: `waveform.barGap`
  static const double barGap = 2;

  /// Token: `waveform.barRadius`
  static const double barRadius = 1.5;

  /// Token: `waveform.minBarHeight`
  static const double minBarHeight = 4;

  /// Token: `waveform.markerWidth`
  static const double markerWidth = 2;
}

/// Component tokens for `progressRing` (theme-independent geometry, motion and glow recipes).
abstract final class UpProgressRingTokens {
  /// Old ref circular.xml (old)
  ///
  /// Token: `progressRing.innerRadius`
  static const double innerRadius = 64;

  /// Token: `progressRing.thickness`
  static const double thickness = 8;

  /// Ref 3x3 loading grid shifts alpha every 0.1 s
  ///
  /// Token: `progressRing.loadingStep`
  static const Duration loadingStep = Duration(milliseconds: 100);

  /// Token: `progressRing.duration`
  static const Duration duration = Duration(milliseconds: 1000);

  /// Token: `progressRing.curve`
  static const Cubic curve = Cubic(0.25, 0.46, 0.45, 0.94);
}

/// Component tokens for `record` (theme-independent geometry, motion and glow recipes).
abstract final class UpRecordTokens {
  /// Token: `record.buttonSize`
  static const double buttonSize = 85;

  /// Ref 0.6 s QuadOut: ring x1.2 red, dot x0.5
  ///
  /// Token: `record.pulse`
  static const Duration pulse = Duration(milliseconds: 600);

  /// Token: `record.pulseScale`
  static const double pulseScale = 1.2;

  /// Token: `record.dotScale`
  static const double dotScale = 0.5;

  /// Ref ripple 1.0 s CircOut to 4x, alpha 1 -> 0
  ///
  /// Token: `record.ripple`
  static const Duration ripple = Duration(milliseconds: 1000);

  /// Token: `record.rippleScale`
  static const double rippleScale = 4;

  /// Token: `record.rippleCurve`
  static const Cubic rippleCurve = Cubic(0.075, 0.82, 0.165, 1);

  /// Ref save recording play button 110 px
  ///
  /// Token: `record.playSize`
  static const double playSize = 55;
}

/// Component tokens for `swatch` (theme-independent geometry, motion and glow recipes).
abstract final class UpSwatchTokens {
  /// Ref 70 px colour dots, 8 colours
  ///
  /// Token: `swatch.size`
  static const double size = 35;

  /// Token: `swatch.ringWidth`
  static const double ringWidth = 2;

  /// Token: `swatch.ringWidthSelected`
  static const double ringWidthSelected = 4;
}

/// Component tokens for `pad` (theme-independent geometry, motion and glow recipes).
abstract final class UpPadTokens {
  /// Ref 4px between pads
  ///
  /// Token: `pad.gap`
  static const double gap = 2;

  /// Token: `pad.minSize`
  static const double minSize = 44;

  /// Ref pad component 256px (scaled to the cell)
  ///
  /// Token: `pad.designSize`
  static const double designSize = 128;

  /// Ref cell 267/268 x 255-257 px (not square)
  ///
  /// Token: `pad.cellWidth`
  static const double cellWidth = 133.5;

  /// Token: `pad.cellHeight`
  static const double cellHeight = 128;

  /// Token: `pad.numberSizeRatio`
  static const double numberSizeRatio = 0.12;

  /// Token: `pad.numberInsetEndRatio`
  static const double numberInsetEndRatio = 0.1;

  /// Token: `pad.numberInsetBottomRatio`
  static const double numberInsetBottomRatio = 0.03;

  /// Ref loop glyph 120x136 on a 256 pad
  ///
  /// Token: `pad.loopIconRatio`
  static const double loopIconRatio = 0.47;

  /// UP neon glow
  ///
  /// Token: `pad.glowPressed`
  static const UpGlowSpec glowPressed = UpGlowSpec(<UpGlowLayer>[
    UpGlowLayer(opacity: 0.75, blur: 16, spread: 1, dx: 0, dy: 0),
    UpGlowLayer(opacity: 0.35, blur: 40, spread: 6, dx: 0, dy: 0),
  ]);

  /// UP neon glow
  ///
  /// Token: `pad.glowPlaying`
  static const UpGlowSpec glowPlaying = UpGlowSpec(<UpGlowLayer>[
    UpGlowLayer(opacity: 0.65, blur: 12, spread: 0, dx: 0, dy: 0),
    UpGlowLayer(opacity: 0.3, blur: 28, spread: 2, dx: 0, dy: 0),
  ]);

  /// Token: `pad.bevel`
  static const List<BoxShadow> bevel = <BoxShadow>[
    BoxShadow(
      color: Color(0x80000000),
      offset: Offset(0, 3),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  /// Ref: lit state on the next frame (no tween)
  ///
  /// Token: `pad.pressAttack`
  static const Duration pressAttack = Duration(milliseconds: 17);

  /// Ref: 0.1 s QuadOut back to idle
  ///
  /// Token: `pad.pressRelease`
  static const Duration pressRelease = Duration(milliseconds: 100);

  /// Token: `pad.pressCurve`
  static const Cubic pressCurve = Cubic(0.25, 0.46, 0.45, 0.94);

  /// Ref: 0.6 s one way, yoyo, infinite (1.2 s period)
  ///
  /// Token: `pad.loopFlashHalf`
  static const Duration loopFlashHalf = Duration(milliseconds: 600);

  /// Token: `pad.loopFlashCurve`
  static const Cubic loopFlashCurve = Cubic(0.25, 0.46, 0.45, 0.94);

  /// Ref: loop icon 360° per 1.2 s
  ///
  /// Token: `pad.loopRevolution`
  static const Duration loopRevolution = Duration(milliseconds: 1200);

  /// Token: `pad.loopCurve`
  static const Cubic loopCurve = Cubic(0, 0, 1, 1);

  /// UP
  ///
  /// Token: `pad.pendingBlink`
  static const Duration pendingBlink = Duration(milliseconds: 400);

  /// Ref Square skin: layer shrink 0.05 s, stagger 17 ms
  ///
  /// Token: `pad.pressScaleIn`
  static const Duration pressScaleIn = Duration(milliseconds: 50);

  /// Ref Circle/Square: back to 1.0 in 0.1 s QuadOut
  ///
  /// Token: `pad.pressScaleOut`
  static const Duration pressScaleOut = Duration(milliseconds: 100);

  /// Token: `pad.scaleSpring`
  static const SpringDescription scaleSpring = SpringDescription(
    mass: 1,
    stiffness: 900,
    damping: 38,
  );

  /// Ref loop flash period 1.2 s
  ///
  /// Token: `pad.loopFlashCycle`
  static const Duration loopFlashCycle = Duration(milliseconds: 1200);
}

/// Component tokens for `padGrid` (theme-independent geometry, motion and glow recipes).
abstract final class UpPadGridTokens {
  /// Token: `padGrid.columns`
  static const int columns = 3;

  /// Token: `padGrid.rows`
  static const int rows = 4;

  /// A / B
  ///
  /// Token: `padGrid.banks`
  static const int banks = 2;

  /// Ref pad area x 9..819 px
  ///
  /// Token: `padGrid.pageInset`
  static const double pageInset = 4.5;

  /// Ref pad area y 286 px
  ///
  /// Token: `padGrid.top`
  static const double top = 143;

  /// Ref pad area ends at y 1321 of 1472 px
  ///
  /// Token: `padGrid.bottomInset`
  static const double bottomInset = 75.5;

  /// Token: `padGrid.maxWidth`
  static const double maxWidth = 600;

  /// Ref A/B 0.2 s QuadOut, page slides 100%
  ///
  /// Token: `padGrid.bankSwitch`
  static const Duration bankSwitch = Duration(milliseconds: 200);

  /// Token: `padGrid.bankSwitchCurve`
  static const Cubic bankSwitchCurve = Cubic(0.25, 0.46, 0.45, 0.94);

  /// Old ref 6dp (old; Ref uses absolute y 286px)
  ///
  /// Token: `padGrid.marginTop`
  static const double marginTop = 6;

  /// Old ref 12dp (old)
  ///
  /// Token: `padGrid.marginBottom`
  static const double marginBottom = 12;
}

/// Component tokens for `topBar` (theme-independent geometry, motion and glow recipes).
abstract final class UpTopBarTokens {
  /// Token: `topBar.songsWidth`
  static const double songsWidth = 89.5;

  /// Token: `topBar.songsHeight`
  static const double songsHeight = 31.5;

  /// Ref (20,33) px
  ///
  /// Token: `topBar.songsX`
  static const double songsX = 10;

  /// Token: `topBar.songsY`
  static const double songsY = 16.5;

  /// Ref KIT title at (216,45) px
  ///
  /// Token: `topBar.titleX`
  static const double titleX = 108;

  /// Token: `topBar.youtubeWidth`
  static const double youtubeWidth = 71;

  /// Token: `topBar.youtubeHeight`
  static const double youtubeHeight = 44;

  /// Ref function row y 126 px
  ///
  /// Token: `topBar.functionRowY`
  static const double functionRowY = 63;

  /// Token: `topBar.functionRowHeight`
  static const double functionRowHeight = 50;

  /// Ref 100x100 px
  ///
  /// Token: `topBar.functionButton`
  static const double functionButton = 50;

  /// Ref inner block 84 px
  ///
  /// Token: `topBar.functionButtonInner`
  static const double functionButtonInner = 42;

  /// Token: `topBar.tutorialWidth`
  static const double tutorialWidth = 210;

  /// Token: `topBar.moreWidth`
  static const double moreWidth = 32.5;

  /// Token: `topBar.bankButtonWidth`
  static const double bankButtonWidth = 64.5;

  /// Ref 129x126 px
  ///
  /// Token: `topBar.bankButtonHeight`
  static const double bankButtonHeight = 63;

  /// Token: `topBar.iconSize`
  static const double iconSize = 23.5;

  /// Ref SONGS glow 1 -> 0.5 -> 1 per 0.783 s linear
  ///
  /// Token: `topBar.songsBreathe`
  static const Duration songsBreathe = Duration(milliseconds: 783);

  /// Ref function row collapse CircIn / return CircOut
  ///
  /// Token: `topBar.collapse`
  static const Duration collapse = Duration(milliseconds: 300);

  /// Token: `topBar.collapseCurve`
  static const Cubic collapseCurve = Cubic(0.6, 0.04, 0.98, 0.335);

  /// Token: `topBar.expandCurve`
  static const Cubic expandCurve = Cubic(0.075, 0.82, 0.165, 1);

  /// Ref top region above the function row (0..113px)
  ///
  /// Token: `topBar.height`
  static const double height = 56.5;

  /// Ref SONGS x 20px
  ///
  /// Token: `topBar.paddingX`
  static const double paddingX = 10;

  /// Token: `topBar.gap`
  static const double gap = 8;

  /// Ref A/B 129px
  ///
  /// Token: `topBar.bankButtonSize`
  static const double bankButtonSize = 64.5;

  /// Ref record block 84px
  ///
  /// Token: `topBar.recIconSize`
  static const double recIconSize = 42;
}

/// Component tokens for `navBar` (theme-independent geometry, motion and glow recipes).
abstract final class UpNavBarTokens {
  /// Token: `navBar.height`
  static const double height = 50;

  /// Token: `navBar.buttonSize`
  static const double buttonSize = 40;

  /// Token: `navBar.paddingX`
  static const double paddingX = 10;
}

/// Component tokens for `tabBar` (theme-independent geometry, motion and glow recipes).
abstract final class UpTabBarTokens {
  /// Token: `tabBar.height`
  static const double height = 50;

  /// Token: `tabBar.iconSize`
  static const double iconSize = 23.5;

  /// Token: `tabBar.selectedCircle`
  static const double selectedCircle = 31.5;

  /// Ref underline 3 px
  ///
  /// Token: `tabBar.indicatorHeight`
  static const double indicatorHeight = 1.5;

  /// Token: `tabBar.subTabWidth`
  static const double subTabWidth = 115.5;

  /// Token: `tabBar.subTabHeight`
  static const double subTabHeight = 31;
}

/// Component tokens for `kitCard` (theme-independent geometry, motion and glow recipes).
abstract final class UpKitCardTokens {
  /// Ref kit row 132 px
  ///
  /// Token: `kitCard.height`
  static const double height = 66;

  /// Token: `kitCard.thumbWidth`
  static const double thumbWidth = 73.5;

  /// Token: `kitCard.thumbHeight`
  static const double thumbHeight = 54.5;

  /// Token: `kitCard.thumbInset`
  static const double thumbInset = 5.5;

  /// Token: `kitCard.textInset`
  static const double textInset = 86;

  /// Ref selection bar 9 px
  ///
  /// Token: `kitCard.indicatorWidth`
  static const double indicatorWidth = 4.5;

  /// Token: `kitCard.radius`
  static const double radius = 0;

  /// Token: `kitCard.coverRadius`
  static const double coverRadius = 3;

  /// Token: `kitCard.bigWidth`
  static const double bigWidth = 202.5;

  /// Token: `kitCard.bigHeight`
  static const double bigHeight = 150.5;

  /// Token: `kitCard.smallWidth`
  static const double smallWidth = 69.5;

  /// Token: `kitCard.smallHeight`
  static const double smallHeight = 87;

  /// Ref KIT stamp rotation (degrees)
  ///
  /// Token: `kitCard.bigLabelAngle`
  static const double bigLabelAngle = 6.8;

  /// Token: `kitCard.padding`
  static const double padding = 12;

  /// Token: `kitCard.gap`
  static const double gap = 12;

  /// Token: `kitCard.shadow`
  static const List<BoxShadow> shadow = <BoxShadow>[
    BoxShadow(
      color: Color(0xA0000000),
      offset: Offset(0, 10),
      blurRadius: 28,
      spreadRadius: 0,
    ),
  ];

  /// Ref thumbnail height 109px
  ///
  /// Token: `kitCard.coverSize`
  static const double coverSize = 54.5;

  /// Ref thumbnail width 147px
  ///
  /// Token: `kitCard.coverSizeLarge`
  static const double coverSizeLarge = 73.5;

  /// Ref kit row 132px
  ///
  /// Token: `kitCard.heightLarge`
  static const double heightLarge = 66;

  /// Old ref (old)
  ///
  /// Token: `kitCard.marginTop`
  static const double marginTop = 6;

  /// SHOT stacked carousel focus
  ///
  /// Token: `kitCard.focusScale`
  static const double focusScale = 1.06;
}

/// Component tokens for `modal` (theme-independent geometry, motion and glow recipes).
abstract final class UpModalTokens {
  /// Token: `modal.width`
  static const double width = 337.5;

  /// Token: `modal.height`
  static const double height = 462;

  /// Token: `modal.thumbHeight`
  static const double thumbHeight = 207;

  /// Token: `modal.buttonWidth`
  static const double buttonWidth = 277.5;

  /// Token: `modal.buttonHeight`
  static const double buttonHeight = 62;

  /// Token: `modal.speedWidth`
  static const double speedWidth = 113;

  /// Token: `modal.speedHeight`
  static const double speedHeight = 140;

  /// Ref speed picker in 0.5 s
  ///
  /// Token: `modal.speedIn`
  static const Duration speedIn = Duration(milliseconds: 500);

  /// Ref out 1.0 s
  ///
  /// Token: `modal.speedOut`
  static const Duration speedOut = Duration(milliseconds: 1000);

  /// Token: `modal.curve`
  static const Cubic curve = Cubic(0.25, 0.46, 0.45, 0.94);
}

/// Component tokens for `page` (theme-independent geometry, motion and glow recipes).
abstract final class UpPageTokens {
  /// UP (scene transitions are code-driven in the original)
  ///
  /// Token: `page.push`
  static const Duration push = Duration(milliseconds: 300);

  /// Token: `page.pushCurve`
  static const Cubic pushCurve = Cubic(0.25, 0.46, 0.45, 0.94);

  /// Token: `page.paddingX`
  static const double paddingX = 20;
}

/// Component tokens for `listItem` (theme-independent geometry, motion and glow recipes).
abstract final class UpListItemTokens {
  /// Ref LOAD SOUND row 132 px
  ///
  /// Token: `listItem.height`
  static const double height = 66;

  /// Ref row step 140 px
  ///
  /// Token: `listItem.step`
  static const double step = 70;

  /// Token: `listItem.paddingX`
  static const double paddingX = 5.5;

  /// Token: `listItem.gap`
  static const double gap = 12;

  /// Token: `listItem.iconBoxSize`
  static const double iconBoxSize = 42;

  /// Token: `listItem.iconSize`
  static const double iconSize = 23.5;

  /// Token: `listItem.radius`
  static const double radius = 0;

  /// Ref profile entry 111 px
  ///
  /// Token: `listItem.profileRowHeight`
  static const double profileRowHeight = 55.5;
}

/// Component tokens for `kitEditor` (theme-independent geometry, motion and glow recipes).
abstract final class UpKitEditorTokens {
  /// Token: `kitEditor.navHeight`
  static const double navHeight = 50;

  /// Token: `kitEditor.miniPad`
  static const double miniPad = 45;

  /// Token: `kitEditor.miniPadGap`
  static const double miniPadGap = 4;

  /// Token: `kitEditor.panelWidth`
  static const double panelWidth = 165;

  /// Token: `kitEditor.panelHeight`
  static const double panelHeight = 214.5;

  /// Token: `kitEditor.editPadWidth`
  static const double editPadWidth = 375;

  /// Ref SALVAR 150x60 px
  ///
  /// Token: `kitEditor.saveWidth`
  static const double saveWidth = 75;

  /// Token: `kitEditor.saveHeight`
  static const double saveHeight = 30;

  /// Ref close 95 px
  ///
  /// Token: `kitEditor.closeSize`
  static const double closeSize = 47.5;

  /// Ref trim max 30 s
  ///
  /// Token: `kitEditor.maxTrim`
  static const Duration maxTrim = Duration(milliseconds: 30000);
}

/// Component tokens for `iconButton` (theme-independent geometry, motion and glow recipes).
abstract final class UpIconButtonTokens {
  /// Token: `iconButton.size`
  static const double size = 50;

  /// Token: `iconButton.iconSize`
  static const double iconSize = 23.5;
}

/// Component tokens for `genreIcon` (theme-independent geometry, motion and glow recipes).
abstract final class UpGenreIconTokens {
  /// Token: `genreIcon.size`
  static const double size = 44;

  /// Token: `genreIcon.iconSize`
  static const double iconSize = 23.5;

  /// Token: `genreIcon.labelGap`
  static const double labelGap = 6;

  /// Token: `genreIcon.ringWidth`
  static const double ringWidth = 2;

  /// Token: `genreIcon.gap`
  static const double gap = 12;

  /// Ref genre list 659x96 px
  ///
  /// Token: `genreIcon.rowHeight`
  static const double rowHeight = 48;

  /// Token: `genreIcon.rowWidth`
  static const double rowWidth = 329.5;
}

/// Component tokens for `trackCard` (theme-independent geometry, motion and glow recipes).
abstract final class UpTrackCardTokens {
  /// Token: `trackCard.radius`
  static const double radius = 8;

  /// Token: `trackCard.padding`
  static const double padding = 16;

  /// Token: `trackCard.gap`
  static const double gap = 12;

  /// Token: `trackCard.shadow`
  static const List<BoxShadow> shadow = <BoxShadow>[
    BoxShadow(
      color: Color(0xA0000000),
      offset: Offset(0, 10),
      blurRadius: 28,
      spreadRadius: 0,
    ),
  ];

  /// Ref record pulse 0.6 s
  ///
  /// Token: `trackCard.recTransition`
  static const Duration recTransition = Duration(milliseconds: 600);

  /// Ref record ripple 1.0 s
  ///
  /// Token: `trackCard.recLoop`
  static const Duration recLoop = Duration(milliseconds: 1000);
}

/// Component tokens for `tutorial` (theme-independent geometry, motion and glow recipes).
abstract final class UpTutorialTokens {
  /// Ref tutorial pad fills bottom->top in 1.0 s linear
  ///
  /// Token: `tutorial.fill`
  static const Duration fill = Duration(milliseconds: 1000);

  /// Token: `tutorial.fillCurve`
  static const Cubic fillCurve = Cubic(0, 0, 1, 1);

  /// Token: `tutorial.bubbleWidth`
  static const double bubbleWidth = 210.5;

  /// Token: `tutorial.bubbleHeight`
  static const double bubbleHeight = 132.5;

  /// Ref 100 px cut-out
  ///
  /// Token: `tutorial.highlightHole`
  static const double highlightHole = 50;

  /// Ref hand moves 200 px
  ///
  /// Token: `tutorial.handTravel`
  static const double handTravel = 100;

  /// Token: `tutorial.hand`
  static const Duration hand = Duration(milliseconds: 1000);

  /// Token: `tutorial.handCurve`
  static const Cubic handCurve = Cubic(0.55, 0.085, 0.68, 0.53);

  /// Ref PERFECT rises 55 px in 0.3 s
  ///
  /// Token: `tutorial.perfectRise`
  static const double perfectRise = 27.5;

  /// Token: `tutorial.perfectDuration`
  static const Duration perfectDuration = Duration(milliseconds: 300);

  /// Ref green circle grows to 20x in 0.4 s
  ///
  /// Token: `tutorial.perfectCircleScale`
  static const double perfectCircleScale = 20;

  /// Token: `tutorial.perfectCircle`
  static const Duration perfectCircle = Duration(milliseconds: 400);

  /// Ref TOO FAST/SLOW tilt degrees
  ///
  /// Token: `tutorial.missTilt`
  static const double missTilt = 6;

  /// Token: `tutorial.wrongIn`
  static const Duration wrongIn = Duration(milliseconds: 100);

  /// Token: `tutorial.wrongOut`
  static const Duration wrongOut = Duration(milliseconds: 900);

  /// Token: `tutorial.wrongScale`
  static const double wrongScale = 1.3;

  /// Ref step label slides in 160 px
  ///
  /// Token: `tutorial.stepSlide`
  static const double stepSlide = 80;

  /// Token: `tutorial.textIn`
  static const Duration textIn = Duration(milliseconds: 200);

  /// Token: `tutorial.skipSlide`
  static const Duration skipSlide = Duration(milliseconds: 250);

  /// Token: `tutorial.ringWidth`
  static const double ringWidth = 3;

  /// Token: `tutorial.barHeight`
  static const double barHeight = 50;

  /// Ref tutorial pad fill 1.0 s
  ///
  /// Token: `tutorial.pulse`
  static const Duration pulse = Duration(milliseconds: 1000);
}

/// Component tokens for `searchField` (theme-independent geometry, motion and glow recipes).
abstract final class UpSearchFieldTokens {
  /// Token: `searchField.width`
  static const double width = 375;

  /// Token: `searchField.height`
  static const double height = 36;

  /// Token: `searchField.radius`
  static const double radius = 4;

  /// Token: `searchField.paddingX`
  static const double paddingX = 12;
}

/// Component tokens for `skinItem` (theme-independent geometry, motion and glow recipes).
abstract final class UpSkinItemTokens {
  /// Token: `skinItem.size`
  static const double size = 115;

  /// Token: `skinItem.thumbSize`
  static const double thumbSize = 75;

  /// Token: `skinItem.radius`
  static const double radius = 8;

  /// Old ref (old)
  ///
  /// Token: `skinItem.marginStart`
  static const double marginStart = 20;

  /// Old ref (old)
  ///
  /// Token: `skinItem.marginY`
  static const double marginY = 10;
}
