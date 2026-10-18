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
  /// Token: `transport.height`
  static const double height = 56;

  /// Token: `transport.stopSize`
  static const double stopSize = 34;

  /// Token: `transport.speedHeight`
  static const double speedHeight = 24;

  /// Token: `transport.gap`
  static const double gap = 12;
}

/// Component tokens for `chip` (theme-independent geometry, motion and glow recipes).
abstract final class UpChipTokens {
  /// Token: `chip.height`
  static const double height = 34;

  /// Token: `chip.radius`
  static const double radius = 3;

  /// Token: `chip.paddingX`
  static const double paddingX = 12;

  /// Token: `chip.iconBoxWidth`
  static const double iconBoxWidth = 34;

  /// Token: `chip.iconSize`
  static const double iconSize = 20;

  /// Token: `chip.gap`
  static const double gap = 8;
}

/// Component tokens for `banner` (theme-independent geometry, motion and glow recipes).
abstract final class UpBannerTokens {
  /// Token: `banner.width`
  static const double width = 300;

  /// Token: `banner.height`
  static const double height = 160;

  /// Token: `banner.holderHeight`
  static const double holderHeight = 175;

  /// Token: `banner.radius`
  static const double radius = 8;

  /// Token: `banner.indicatorSize`
  static const double indicatorSize = 6;

  /// Token: `banner.indicatorGap`
  static const double indicatorGap = 6;

  /// Token: `banner.autoplay`
  static const Duration autoplay = Duration(milliseconds: 4000);

  /// Token: `banner.transition`
  static const Duration transition = Duration(milliseconds: 300);

  /// Token: `banner.transitionCurve`
  static const Cubic transitionCurve = Cubic(0.42, 0, 0.58, 1);
}

/// Component tokens for `sheet` (theme-independent geometry, motion and glow recipes).
abstract final class UpSheetTokens {
  /// Token: `sheet.radius`
  static const double radius = 12;

  /// Token: `sheet.headerHeight`
  static const double headerHeight = 44;

  /// Token: `sheet.footerHeight`
  static const double footerHeight = 50;

  /// Token: `sheet.handleWidth`
  static const double handleWidth = 36;

  /// Token: `sheet.handleHeight`
  static const double handleHeight = 4;

  /// Token: `sheet.itemHeight`
  static const double itemHeight = 54;

  /// Token: `sheet.itemGap`
  static const double itemGap = 2;

  /// Token: `sheet.maxWidth`
  static const double maxWidth = 335;

  /// Token: `sheet.enter`
  static const Duration enter = Duration(milliseconds: 300);

  /// Token: `sheet.exit`
  static const Duration exit = Duration(milliseconds: 300);

  /// Token: `sheet.curve`
  static const Cubic curve = Cubic(0.42, 0, 0.58, 1);

  /// Token: `sheet.spring`
  static const SpringDescription spring = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 36,
  );
}

/// Component tokens for `badge` (theme-independent geometry, motion and glow recipes).
abstract final class UpBadgeTokens {
  /// Token: `badge.height`
  static const double height = 16;

  /// Token: `badge.radius`
  static const double radius = 3;

  /// Token: `badge.paddingX`
  static const double paddingX = 6;
}

/// Component tokens for `button` (theme-independent geometry, motion and glow recipes).
abstract final class UpButtonTokens {
  /// Token: `button.height`
  static const double height = 44;

  /// Token: `button.heightSm`
  static const double heightSm = 34;

  /// Token: `button.heightLg`
  static const double heightLg = 54;

  /// Token: `button.minWidth`
  static const double minWidth = 88;

  /// Token: `button.wideWidth`
  static const double wideWidth = 335;

  /// Token: `button.radius`
  static const double radius = 4;

  /// Token: `button.paddingX`
  static const double paddingX = 16;

  /// Token: `button.iconSize`
  static const double iconSize = 20;

  /// Token: `button.gap`
  static const double gap = 8;

  /// Token: `button.borderWidth`
  static const double borderWidth = 2;

  /// Token: `button.pressScale`
  static const double pressScale = 0.97;

  /// Token: `button.press`
  static const Duration press = Duration(milliseconds: 100);
}

/// Component tokens for `slider` (theme-independent geometry, motion and glow recipes).
abstract final class UpSliderTokens {
  /// Token: `slider.trackHeight`
  static const double trackHeight = 4;

  /// APK thumb_seekbar 20dp
  ///
  /// Token: `slider.thumbSize`
  static const double thumbSize = 20;

  /// Token: `slider.thumbSizeActive`
  static const double thumbSizeActive = 24;

  /// Token: `slider.insetX`
  static const double insetX = 20;
}

/// Component tokens for `dialog` (theme-independent geometry, motion and glow recipes).
abstract final class UpDialogTokens {
  /// Token: `dialog.radius`
  static const double radius = 12;

  /// Token: `dialog.padding`
  static const double padding = 24;

  /// Token: `dialog.gap`
  static const double gap = 16;

  /// Token: `dialog.maxWidth`
  static const double maxWidth = 335;

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
  static const Duration enter = Duration(milliseconds: 200);

  /// Token: `dialog.curve`
  static const Cubic curve = Cubic(0.2, 0, 0, 1);
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
  static const Duration peakHold = Duration(milliseconds: 1250);

  /// Token: `meter.decay`
  static const Duration decay = Duration(milliseconds: 300);
}

/// Component tokens for `waveform` (theme-independent geometry, motion and glow recipes).
abstract final class UpWaveformTokens {
  /// Token: `waveform.height`
  static const double height = 40;

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
  /// APK circular.xml
  ///
  /// Token: `progressRing.innerRadius`
  static const double innerRadius = 64;

  /// Token: `progressRing.thickness`
  static const double thickness = 8;

  /// Token: `progressRing.duration`
  static const Duration duration = Duration(milliseconds: 1250);

  /// Token: `progressRing.curve`
  static const Cubic curve = Cubic(0, 0, 0.2, 1);
}

/// Component tokens for `swatch` (theme-independent geometry, motion and glow recipes).
abstract final class UpSwatchTokens {
  /// APK 32x32 colour dots
  ///
  /// Token: `swatch.size`
  static const double size = 32;

  /// Token: `swatch.ringWidth`
  static const double ringWidth = 2;

  /// Token: `swatch.ringWidthSelected`
  static const double ringWidthSelected = 4;
}

/// Component tokens for `pad` (theme-independent geometry, motion and glow recipes).
abstract final class UpPadTokens {
  /// APK cell margin 1 => 2 between pads
  ///
  /// Token: `pad.gap`
  static const double gap = 2;

  /// Token: `pad.minSize`
  static const double minSize = 44;

  /// Token: `pad.numberSizeRatio`
  static const double numberSizeRatio = 0.12;

  /// Token: `pad.numberInsetEndRatio`
  static const double numberInsetEndRatio = 0.1;

  /// Token: `pad.numberInsetBottomRatio`
  static const double numberInsetBottomRatio = 0.03;

  /// Loop glyph size relative to pad short side (SHOT)
  ///
  /// Token: `pad.loopIconRatio`
  static const double loopIconRatio = 0.22;

  /// Token: `pad.glowPressed`
  static const UpGlowSpec glowPressed = UpGlowSpec(<UpGlowLayer>[
    UpGlowLayer(opacity: 0.75, blur: 16, spread: 1, dx: 0, dy: 0),
    UpGlowLayer(opacity: 0.35, blur: 40, spread: 6, dx: 0, dy: 0),
  ]);

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

  /// Flash 0 -> peak while finger down
  ///
  /// Token: `pad.pressAttack`
  static const Duration pressAttack = Duration(milliseconds: 158);

  /// Flash peak -> 0 after release
  ///
  /// Token: `pad.pressRelease`
  static const Duration pressRelease = Duration(milliseconds: 158);

  /// Token: `pad.pressCurve`
  static const Cubic pressCurve = Cubic(0.6, 0, 0.4, 1);

  /// Token: `pad.loopRevolution`
  static const Duration loopRevolution = Duration(milliseconds: 817);

  /// Token: `pad.loopFlashPeak`
  static const Duration loopFlashPeak = Duration(milliseconds: 250);

  /// Token: `pad.loopFlashCycle`
  static const Duration loopFlashCycle = Duration(milliseconds: 500);

  /// Token: `pad.loopCurve`
  static const Cubic loopCurve = Cubic(0, 0, 1, 1);

  /// Token: `pad.pendingBlink`
  static const Duration pendingBlink = Duration(milliseconds: 300);

  /// Token: `pad.scaleSpring`
  static const SpringDescription scaleSpring = SpringDescription(
    mass: 1,
    stiffness: 900,
    damping: 38,
  );
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

  /// APK page width = screen - 20 (10 each side)
  ///
  /// Token: `padGrid.pageInset`
  static const double pageInset = 10;

  /// Token: `padGrid.marginTop`
  static const double marginTop = 6;

  /// Token: `padGrid.marginBottom`
  static const double marginBottom = 12;

  /// Token: `padGrid.maxWidth`
  static const double maxWidth = 600;

  /// Token: `padGrid.bankSwitch`
  static const Duration bankSwitch = Duration(milliseconds: 100);

  /// Token: `padGrid.bankSwitchCurve`
  static const Cubic bankSwitchCurve = Cubic(0, 0, 0.2, 1);
}

/// Component tokens for `topBar` (theme-independent geometry, motion and glow recipes).
abstract final class UpTopBarTokens {
  /// Token: `topBar.height`
  static const double height = 56;

  /// Token: `topBar.menuHeight`
  static const double menuHeight = 36;

  /// Token: `topBar.menuSlotWidth`
  static const double menuSlotWidth = 50;

  /// Token: `topBar.paddingX`
  static const double paddingX = 8;

  /// Token: `topBar.gap`
  static const double gap = 8;

  /// Token: `topBar.iconSize`
  static const double iconSize = 24;

  /// Token: `topBar.bankButtonSize`
  static const double bankButtonSize = 56;

  /// Token: `topBar.recIconSize`
  static const double recIconSize = 30;
}

/// Component tokens for `tabBar` (theme-independent geometry, motion and glow recipes).
abstract final class UpTabBarTokens {
  /// Token: `tabBar.height`
  static const double height = 50;

  /// Token: `tabBar.iconSize`
  static const double iconSize = 24;

  /// Token: `tabBar.indicatorHeight`
  static const double indicatorHeight = 2;
}

/// Component tokens for `kitCard` (theme-independent geometry, motion and glow recipes).
abstract final class UpKitCardTokens {
  /// Token: `kitCard.height`
  static const double height = 60;

  /// Token: `kitCard.heightLarge`
  static const double heightLarge = 96;

  /// Token: `kitCard.coverSize`
  static const double coverSize = 60;

  /// Token: `kitCard.coverSizeLarge`
  static const double coverSizeLarge = 96;

  /// Token: `kitCard.radius`
  static const double radius = 6;

  /// Token: `kitCard.coverRadius`
  static const double coverRadius = 3;

  /// Token: `kitCard.padding`
  static const double padding = 12;

  /// Token: `kitCard.gap`
  static const double gap = 12;

  /// Token: `kitCard.marginTop`
  static const double marginTop = 6;

  /// Token: `kitCard.indicatorWidth`
  static const double indicatorWidth = 3;

  /// Centred card in the stacked carousel (SHOT)
  ///
  /// Token: `kitCard.focusScale`
  static const double focusScale = 1.06;

  /// Token: `kitCard.shadow`
  static const List<BoxShadow> shadow = <BoxShadow>[
    BoxShadow(
      color: Color(0xA0000000),
      offset: Offset(0, 10),
      blurRadius: 28,
      spreadRadius: 0,
    ),
  ];

  /// Token: `kitCard.carouselItemWidth`
  static const double carouselItemWidth = 96;

  /// Token: `kitCard.carouselItemHeight`
  static const double carouselItemHeight = 48;
}

/// Component tokens for `page` (theme-independent geometry, motion and glow recipes).
abstract final class UpPageTokens {
  /// Token: `page.push`
  static const Duration push = Duration(milliseconds: 300);

  /// Token: `page.pushCurve`
  static const Cubic pushCurve = Cubic(0.42, 0, 0.58, 1);

  /// Token: `page.paddingX`
  static const double paddingX = 20;
}

/// Component tokens for `listItem` (theme-independent geometry, motion and glow recipes).
abstract final class UpListItemTokens {
  /// Token: `listItem.height`
  static const double height = 54;

  /// Token: `listItem.paddingX`
  static const double paddingX = 16;

  /// Token: `listItem.gap`
  static const double gap = 12;

  /// Token: `listItem.iconBoxSize`
  static const double iconBoxSize = 34;

  /// Token: `listItem.iconSize`
  static const double iconSize = 20;

  /// Token: `listItem.radius`
  static const double radius = 4;
}

/// Component tokens for `skinItem` (theme-independent geometry, motion and glow recipes).
abstract final class UpSkinItemTokens {
  /// Token: `skinItem.thumbSize`
  static const double thumbSize = 96;

  /// Token: `skinItem.marginStart`
  static const double marginStart = 20;

  /// Token: `skinItem.marginY`
  static const double marginY = 10;

  /// Token: `skinItem.radius`
  static const double radius = 8;
}

/// Component tokens for `iconButton` (theme-independent geometry, motion and glow recipes).
abstract final class UpIconButtonTokens {
  /// Token: `iconButton.size`
  static const double size = 44;

  /// Token: `iconButton.iconSize`
  static const double iconSize = 24;
}

/// Component tokens for `genreIcon` (theme-independent geometry, motion and glow recipes).
abstract final class UpGenreIconTokens {
  /// Token: `genreIcon.size`
  static const double size = 44;

  /// Token: `genreIcon.iconSize`
  static const double iconSize = 24;

  /// Token: `genreIcon.labelGap`
  static const double labelGap = 6;

  /// Token: `genreIcon.ringWidth`
  static const double ringWidth = 2;

  /// Token: `genreIcon.gap`
  static const double gap = 12;
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

  /// Token: `trackCard.recTransition`
  static const Duration recTransition = Duration(milliseconds: 367);

  /// Token: `trackCard.recLoop`
  static const Duration recLoop = Duration(milliseconds: 2000);
}

/// Component tokens for `tutorial` (theme-independent geometry, motion and glow recipes).
abstract final class UpTutorialTokens {
  /// Token: `tutorial.barHeight`
  static const double barHeight = 36;

  /// Token: `tutorial.ringWidth`
  static const double ringWidth = 3;

  /// Token: `tutorial.pulse`
  static const Duration pulse = Duration(milliseconds: 900);
}

/// Component tokens for `searchField` (theme-independent geometry, motion and glow recipes).
abstract final class UpSearchFieldTokens {
  /// Token: `searchField.height`
  static const double height = 44;

  /// Token: `searchField.radius`
  static const double radius = 4;

  /// Token: `searchField.paddingX`
  static const double paddingX = 12;
}
