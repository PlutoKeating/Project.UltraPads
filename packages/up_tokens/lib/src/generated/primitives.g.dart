// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: design/tokens/src (W3C DTCG) -> Style Dictionary -> design/tokens/scripts/build.mjs
// Regenerate with `just tokens` (cd design/tokens && pnpm run build).
// ignore_for_file: type=lint, unused_import

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../runtime/glow.dart';
import '../runtime/gradient.dart';
import '../runtime/text_role.dart';

/// Primitive colour palette. UI code must use semantic colours from `UpTheme.of(context).colors` instead.
abstract final class UpPrimitiveColors {
  /// Token: `color.base.white`
  static const Color baseWhite = Color(0xFFFFFFFF);

  /// Token: `color.base.black`
  static const Color baseBlack = Color(0xFF000000);

  /// Token: `color.base.transparent`
  static const Color baseTransparent = Color(0x00000000);

  /// Token: `color.grey.50`
  static const Color grey50 = Color(0xFFF6F7F8);

  /// Token: `color.grey.100`
  static const Color grey100 = Color(0xFFECEFF1);

  /// Token: `color.grey.200`
  static const Color grey200 = Color(0xFFD9DEE2);

  /// Token: `color.grey.300`
  static const Color grey300 = Color(0xFFB9C0C6);

  /// APK coolgrey (secondary text)
  ///
  /// Token: `color.grey.400`
  static const Color grey400 = Color(0xFF939BA3);

  /// SHOT muted text
  ///
  /// Token: `color.grey.500`
  static const Color grey500 = Color(0xFF686C6E);

  /// Token: `color.grey.600`
  static const Color grey600 = Color(0xFF4A5155);

  /// SHOT chip / raised
  ///
  /// Token: `color.grey.700`
  static const Color grey700 = Color(0xFF3C4145);

  /// APK charcoal_grey / item_kit
  ///
  /// Token: `color.grey.800`
  static const Color grey800 = Color(0xFF2C3336);

  /// SHOT pad area
  ///
  /// Token: `color.grey.820`
  static const Color grey820 = Color(0xFF262D31);

  /// APK charcoal (tab pages)
  ///
  /// Token: `color.grey.840`
  static const Color grey840 = Color(0xFF242B2E);

  /// APK app_color / black (pads page)
  ///
  /// Token: `color.grey.850`
  static const Color grey850 = Color(0xFF242B2D);

  /// APK primary / dark_grey (window, toolbar)
  ///
  /// Token: `color.grey.900`
  static const Color grey900 = Color(0xFF202629);

  /// SHOT secondary toolbar
  ///
  /// Token: `color.grey.920`
  static const Color grey920 = Color(0xFF1E1E1F);

  /// APK pad border_black
  ///
  /// Token: `color.grey.930`
  static const Color grey930 = Color(0xFF1B1D1D);

  /// APK A/B button background
  ///
  /// Token: `color.grey.940`
  static const Color grey940 = Color(0xFF191E20);

  /// APK dark_grey_two / search_color
  ///
  /// Token: `color.grey.950`
  static const Color grey950 = Color(0xFF181B1C);

  /// APK empty pad gradient start
  ///
  /// Token: `color.grey.960`
  static const Color grey960 = Color(0xFF171B1C);

  /// APK empty pad gradient mid
  ///
  /// Token: `color.grey.975`
  static const Color grey975 = Color(0xFF111314);

  /// APK empty pad gradient end
  ///
  /// Token: `color.grey.1000`
  static const Color grey1000 = Color(0xFF0B0D0D);

  /// APK kit_background
  ///
  /// Token: `color.alpha.white.4`
  static const Color alphaWhite4 = Color(0x0AFFFFFF);

  /// Token: `color.alpha.white.8`
  static const Color alphaWhite8 = Color(0x14FFFFFF);

  /// Token: `color.alpha.white.12`
  static const Color alphaWhite12 = Color(0x1FFFFFFF);

  /// APK white_20 (empty pad)
  ///
  /// Token: `color.alpha.white.20`
  static const Color alphaWhite20 = Color(0x33FFFFFF);

  /// APK white_30
  ///
  /// Token: `color.alpha.white.30`
  static const Color alphaWhite30 = Color(0x4CFFFFFF);

  /// APK white_40 (pads container)
  ///
  /// Token: `color.alpha.white.40`
  static const Color alphaWhite40 = Color(0x66FFFFFF);

  /// APK white_50
  ///
  /// Token: `color.alpha.white.50`
  static const Color alphaWhite50 = Color(0x7FFFFFFF);

  /// Token: `color.alpha.white.70`
  static const Color alphaWhite70 = Color(0xB3FFFFFF);

  /// APK pad press flash peak
  ///
  /// Token: `color.alpha.white.75`
  static const Color alphaWhite75 = Color(0xBFFFFFFF);

  /// Token: `color.alpha.white.90`
  static const Color alphaWhite90 = Color(0xE6FFFFFF);

  /// Token: `color.alpha.black.8`
  static const Color alphaBlack8 = Color(0x14000000);

  /// Token: `color.alpha.black.12`
  static const Color alphaBlack12 = Color(0x1F000000);

  /// APK black_alpha_20 (skin panel dim)
  ///
  /// Token: `color.alpha.black.20`
  static const Color alphaBlack20 = Color(0x33000000);

  /// APK social media chip
  ///
  /// Token: `color.alpha.black.25`
  static const Color alphaBlack25 = Color(0x40000000);

  /// APK black_50
  ///
  /// Token: `color.alpha.black.50`
  static const Color alphaBlack50 = Color(0x80000000);

  /// APK black_opacity (scrim)
  ///
  /// Token: `color.alpha.black.63`
  static const Color alphaBlack63 = Color(0xA0000000);

  /// APK background_download_kit
  ///
  /// Token: `color.alpha.black.67`
  static const Color alphaBlack67 = Color(0xAC000000);

  /// APK red_pink — primary accent (save, seekbar thumb, selected underline)
  ///
  /// Token: `color.brand.rose`
  static const Color brandRose = Color(0xFFF73873);

  /// APK selected_kit / skin_price
  ///
  /// Token: `color.brand.roseLight`
  static const Color brandRoseLight = Color(0xFFF93E78);

  /// APK red_pink_two; SHOT SONGS chip
  ///
  /// Token: `color.brand.raspberry`
  static const Color brandRaspberry = Color(0xFFFD1A68);

  /// SHOT SONGS chip icon box
  ///
  /// Token: `color.brand.raspberryDeep`
  static const Color brandRaspberryDeep = Color(0xFF8E1546);

  /// APK electric_pink
  ///
  /// Token: `color.brand.electric`
  static const Color brandElectric = Color(0xFFFD1B99);

  /// SHOT brand gradient start
  ///
  /// Token: `color.brand.magenta`
  static const Color brandMagenta = Color(0xFFD2066D);

  /// SHOT brand gradient mid
  ///
  /// Token: `color.brand.berry`
  static const Color brandBerry = Color(0xFFB3076B);

  /// SHOT brand gradient end (purple)
  ///
  /// Token: `color.brand.plum`
  static const Color brandPlum = Color(0xFF6E1470);

  /// APK Kit colorBackground default rgb(248,69,62)
  ///
  /// Token: `color.brand.kitDefault`
  static const Color brandKitDefault = Color(0xFFF8453E);

  /// Token: `color.classic.blue.300`
  static const Color classicBlue300 = Color(0xFF54E0FF);

  /// Token: `color.classic.blue.500`
  static const Color classicBlue500 = Color(0xFF2AD5FA);

  /// Token: `color.classic.blue.700`
  static const Color classicBlue700 = Color(0xFF00CAF7);

  /// Token: `color.classic.green.300`
  static const Color classicGreen300 = Color(0xFF1BEB00);

  /// Token: `color.classic.green.500`
  static const Color classicGreen500 = Color(0xFF0DD600);

  /// Token: `color.classic.green.700`
  static const Color classicGreen700 = Color(0xFF00C200);

  /// Token: `color.classic.orange.300`
  static const Color classicOrange300 = Color(0xFFFFB100);

  /// Token: `color.classic.orange.500`
  static const Color classicOrange500 = Color(0xFFF49600);

  /// Token: `color.classic.orange.700`
  static const Color classicOrange700 = Color(0xFFE97A00);

  /// Token: `color.classic.pink.300`
  static const Color classicPink300 = Color(0xFFFF6B97);

  /// Token: `color.classic.pink.500`
  static const Color classicPink500 = Color(0xFFFA4F84);

  /// Token: `color.classic.pink.700`
  static const Color classicPink700 = Color(0xFFF7346F);

  /// Token: `color.neon.yellow.300`
  static const Color neonYellow300 = Color(0xFFF9E21D);

  /// Token: `color.neon.yellow.500`
  static const Color neonYellow500 = Color(0xFFF9D01D);

  /// Token: `color.neon.yellow.700`
  static const Color neonYellow700 = Color(0xFFFBB418);

  /// Token: `color.neon.green.300`
  static const Color neonGreen300 = Color(0xFFC8DC2A);

  /// Token: `color.neon.green.500`
  static const Color neonGreen500 = Color(0xFF9BCD35);

  /// Token: `color.neon.green.700`
  static const Color neonGreen700 = Color(0xFF51BC44);

  /// Token: `color.neon.magenta.300`
  static const Color neonMagenta300 = Color(0xFFF23CF0);

  /// Token: `color.neon.magenta.500`
  static const Color neonMagenta500 = Color(0xFFEA20D3);

  /// Token: `color.neon.magenta.700`
  static const Color neonMagenta700 = Color(0xFFAF27A6);

  /// Token: `color.neon.blue.300`
  static const Color neonBlue300 = Color(0xFF01B4FE);

  /// Token: `color.neon.blue.500`
  static const Color neonBlue500 = Color(0xFF0194FE);

  /// Token: `color.neon.blue.700`
  static const Color neonBlue700 = Color(0xFF015BFE);

  /// Token: `color.neon.pink.300`
  static const Color neonPink300 = Color(0xFFFF3CD8);

  /// Token: `color.neon.pink.500`
  static const Color neonPink500 = Color(0xFFFD169D);

  /// Token: `color.neon.pink.700`
  static const Color neonPink700 = Color(0xFFFC0579);

  /// Token: `color.neon.cyan.300`
  static const Color neonCyan300 = Color(0xFF5AD8F5);

  /// Token: `color.neon.cyan.500`
  static const Color neonCyan500 = Color(0xFF0FB6E3);

  /// Token: `color.neon.cyan.700`
  static const Color neonCyan700 = Color(0xFF0A8FB8);

  /// Token: `color.neon.orange.300`
  static const Color neonOrange300 = Color(0xFFF1B37E);

  /// Token: `color.neon.orange.500`
  static const Color neonOrange500 = Color(0xFFE9993F);

  /// Token: `color.neon.orange.700`
  static const Color neonOrange700 = Color(0xFFE07D28);

  /// Token: `color.neon.rose.300`
  static const Color neonRose300 = Color(0xFFEE4989);

  /// Token: `color.neon.rose.500`
  static const Color neonRose500 = Color(0xFFE6347A);

  /// Token: `color.neon.rose.700`
  static const Color neonRose700 = Color(0xFFDD1F69);

  /// SHOT loop pad idle fill
  ///
  /// Token: `color.neon.violet.500`
  static const Color neonViolet500 = Color(0xFF4A12A8);

  /// Token: `color.neon.violet.700`
  static const Color neonViolet700 = Color(0xFF3A0E8A);

  /// Token: `color.neon.violet.900`
  static const Color neonViolet900 = Color(0xFF2A0A66);

  /// Token: `color.swatch.aquaMarine`
  static const Color swatchAquaMarine = Color(0xFF50E3C2);

  /// Token: `color.swatch.darkSky`
  static const Color swatchDarkSky = Color(0xFF4A90E2);

  /// Token: `color.swatch.skyBlue`
  static const Color swatchSkyBlue = Color(0xFF2B98F0);

  /// Token: `color.swatch.greenYellow`
  static const Color swatchGreenYellow = Color(0xFFBBD809);

  /// Token: `color.swatch.orangeyRed`
  static const Color swatchOrangeyRed = Color(0xFFFC6530);

  /// Token: `color.swatch.redPink`
  static const Color swatchRedPink = Color(0xFFF73873);

  /// Token: `color.swatch.scarlet`
  static const Color swatchScarlet = Color(0xFFD0021B);

  /// Token: `color.swatch.vibrantGreen`
  static const Color swatchVibrantGreen = Color(0xFF00CF02);

  /// Token: `color.swatch.vividPurple`
  static const Color swatchVividPurple = Color(0xFF9013FE);

  /// Token: `color.swatch.dandelion`
  static const Color swatchDandelion = Color(0xFFFFEC00);

  /// Token: `color.swatch.mediumPink`
  static const Color swatchMediumPink = Color(0xFFEE4286);

  /// Token: `color.swatch.lavenderPink`
  static const Color swatchLavenderPink = Color(0xFFC86DD7);
}

/// Primitive gradients.
abstract final class UpGradients {
  /// Marketing / hero background (SHOT).
  ///
  /// Token: `gradient.brand`
  static const UpGradient brand = UpGradient(
    colors: <Color>[Color(0xFFD2066D), Color(0xFFB3076B), Color(0xFF6E1470)],
    stops: <double>[0, 0.5, 1],
  );

  /// Token: `gradient.scrimBottom`
  static const UpGradient scrimBottom = UpGradient(
    colors: <Color>[Color(0x00000000), Color(0xA0000000)],
    stops: <double>[0, 1],
  );

  /// APK placeholder pad gradient.
  ///
  /// Token: `gradient.emptyPad`
  static const UpGradient emptyPad = UpGradient(
    colors: <Color>[Color(0xFF171B1C), Color(0xFF111314), Color(0xFF0B0D0D)],
    stops: <double>[0, 0.95, 1],
  );
}

/// Opacity scale.
abstract final class UpOpacities {
  /// Token: `opacity.none`
  static const double none = 0;

  /// Token: `opacity.faint`
  static const double faint = 0.08;

  /// Token: `opacity.subtle`
  static const double subtle = 0.12;

  /// APK tutorial non-target pad alpha; skin panel dim
  ///
  /// Token: `opacity.dim`
  static const double dim = 0.2;

  /// Token: `opacity.disabled`
  static const double disabled = 0.35;

  /// Token: `opacity.muted`
  static const double muted = 0.5;

  /// Token: `opacity.strong`
  static const double strong = 0.7;

  /// APK pad flash peak
  ///
  /// Token: `opacity.flash`
  static const double flash = 0.75;

  /// Token: `opacity.full`
  static const double full = 1;
}

/// Blur radii (logical px).
abstract final class UpBlurs {
  /// Token: `blur.none`
  static const double none = 0;

  /// Token: `blur.sm`
  static const double sm = 4;

  /// Token: `blur.md`
  static const double md = 12;

  /// Token: `blur.lg`
  static const double lg = 24;

  /// Token: `blur.xl`
  static const double xl = 40;
}

/// Stacking order.
abstract final class UpZIndex {
  /// Token: `zIndex.base`
  static const int baseValue = 0;

  /// Token: `zIndex.raised`
  static const int raised = 1;

  /// Token: `zIndex.sticky`
  static const int sticky = 10;

  /// Token: `zIndex.overlay`
  static const int overlay = 20;

  /// Token: `zIndex.sheet`
  static const int sheet = 30;

  /// Token: `zIndex.dialog`
  static const int dialog = 40;

  /// Token: `zIndex.toast`
  static const int toast = 50;

  /// Token: `zIndex.tutorial`
  static const int tutorial = 60;
}

/// Border widths (logical px).
abstract final class UpBorderWidths {
  /// Token: `borderWidth.none`
  static const double none = 0;

  /// Token: `borderWidth.hairline`
  static const double hairline = 0.5;

  /// APK pad border_black
  ///
  /// Token: `borderWidth.thin`
  static const double thin = 1;

  /// APK selected pad / edit button / swatch
  ///
  /// Token: `borderWidth.regular`
  static const double regular = 2;

  /// APK kit selected indicator
  ///
  /// Token: `borderWidth.thick`
  static const double thick = 3;

  /// APK selected swatch
  ///
  /// Token: `borderWidth.heavy`
  static const double heavy = 4;
}

/// Motion durations.
abstract final class UpDurations {
  /// Token: `motion.duration.instant`
  static const Duration instant = Duration(milliseconds: 0);

  /// Token: `motion.duration.xfast`
  static const Duration xfast = Duration(milliseconds: 50);

  /// APK A/B page scroll; material buttons/chips
  ///
  /// Token: `motion.duration.fast`
  static const Duration fast = Duration(milliseconds: 100);

  /// APK bottom sheet slide
  ///
  /// Token: `motion.duration.quick`
  static const Duration quick = Duration(milliseconds: 150);

  /// APK one-shot Lottie first half (frames 0..9.5 @60fps)
  ///
  /// Token: `motion.duration.padPressHalf`
  static const Duration padPressHalf = Duration(milliseconds: 158);

  /// APK unzip delay
  ///
  /// Token: `motion.duration.medium`
  static const Duration medium = Duration(milliseconds: 200);

  /// APK loop flash peak (frame 15)
  ///
  /// Token: `motion.duration.loopFlash`
  static const Duration loopFlash = Duration(milliseconds: 250);

  /// APK panel/sub-page enter & exit
  ///
  /// Token: `motion.duration.slow`
  static const Duration slow = Duration(milliseconds: 300);

  /// APK one-shot Lottie total (19 frames @60fps)
  ///
  /// Token: `motion.duration.padPress`
  static const Duration padPress = Duration(milliseconds: 317);

  /// APK bt_rec_transition
  ///
  /// Token: `motion.duration.recTransition`
  static const Duration recTransition = Duration(milliseconds: 367);

  /// Token: `motion.duration.slower`
  static const Duration slower = Duration(milliseconds: 450);

  /// APK loop flash back to 0 (frame 30)
  ///
  /// Token: `motion.duration.loopFlashCycle`
  static const Duration loopFlashCycle = Duration(milliseconds: 500);

  /// APK loop icon one revolution (49 frames)
  ///
  /// Token: `motion.duration.loopRevolution`
  static const Duration loopRevolution = Duration(milliseconds: 817);

  /// Token: `motion.duration.loadingKit`
  static const Duration loadingKit = Duration(milliseconds: 868);

  /// Token: `motion.duration.pulse`
  static const Duration pulse = Duration(milliseconds: 900);

  /// APK loading progress bar
  ///
  /// Token: `motion.duration.progress`
  static const Duration progress = Duration(milliseconds: 1250);

  /// APK bt_rec_animation loop
  ///
  /// Token: `motion.duration.recLoop`
  static const Duration recLoop = Duration(milliseconds: 2000);

  /// Token: `motion.duration.download`
  static const Duration download = Duration(milliseconds: 2202);

  /// Token: `motion.duration.toast`
  static const Duration toast = Duration(milliseconds: 2500);

  /// Token: `motion.duration.carousel`
  static const Duration carousel = Duration(milliseconds: 4000);
}

/// Motion easing curves.
abstract final class UpEasings {
  /// Token: `motion.easing.linear`
  static const Cubic linear = Cubic(0, 0, 1, 1);

  /// Android AccelerateDecelerate (APK default for panels)
  ///
  /// Token: `motion.easing.standard`
  static const Cubic standard = Cubic(0.42, 0, 0.58, 1);

  /// Android Decelerate (APK A/B scroll, progress)
  ///
  /// Token: `motion.easing.decelerate`
  static const Cubic decelerate = Cubic(0, 0, 0.2, 1);

  /// Token: `motion.easing.accelerate`
  static const Cubic accelerate = Cubic(0.4, 0, 1, 1);

  /// Token: `motion.easing.emphasized`
  static const Cubic emphasized = Cubic(0.2, 0, 0, 1);

  /// APK pad flash Lottie bezier (o.x 0.6, i.x 0.4)
  ///
  /// Token: `motion.easing.lottiePad`
  static const Cubic lottiePad = Cubic(0.6, 0, 0.4, 1);

  /// APK loop Lottie
  ///
  /// Token: `motion.easing.lottieLinear`
  static const Cubic lottieLinear = Cubic(0.167, 0.167, 0.833, 0.833);
}

/// Physics spring descriptions.
abstract final class UpSprings {
  /// Token: `motion.spring.snappy`
  static const SpringDescription snappy = SpringDescription(
    mass: 1,
    stiffness: 900,
    damping: 38,
  );

  /// Token: `motion.spring.standard`
  static const SpringDescription standard = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 36,
  );

  /// Token: `motion.spring.gentle`
  static const SpringDescription gentle = SpringDescription(
    mass: 1,
    stiffness: 170,
    damping: 26,
  );

  /// Token: `motion.spring.bouncy`
  static const SpringDescription bouncy = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 16,
  );
}

/// Corner radius scale (logical px).
abstract final class UpRadii {
  /// Token: `radius.none`
  static const double none = 0;

  /// Token: `radius.xs`
  static const double xs = 2;

  /// APK kit_shape
  ///
  /// Token: `radius.sm`
  static const double sm = 3;

  /// APK pad xml / mini / edit / save buttons
  ///
  /// Token: `radius.md`
  static const double md = 4;

  /// APK kit card / not-downloaded
  ///
  /// Token: `radius.lg`
  static const double lg = 6;

  /// APK save record / preview kit
  ///
  /// Token: `radius.xl`
  static const double xl = 8;

  /// APK social media
  ///
  /// Token: `radius.xxl`
  static const double xxl = 12;

  /// Token: `radius.xxxl`
  static const double xxxl = 16;

  /// Token: `radius.pill`
  static const double pill = 999;
}

/// Proportional ratios (value = side * ratio).
abstract final class UpRatios {
  /// APK Lottie 16/133 ≈ 12% of pad side
  ///
  /// Token: `ratio.padRadius`
  static const double padRadius = 0.12;

  /// APK pad number text = pad width * 0.12
  ///
  /// Token: `ratio.padNumberSize`
  static const double padNumberSize = 0.12;

  /// Token: `ratio.padNumberInsetEnd`
  static const double padNumberInsetEnd = 0.1;

  /// Token: `ratio.padNumberInsetBottom`
  static const double padNumberInsetBottom = 0.03;

  /// Token: `ratio.circle`
  static const double circle = 0.5;
}

/// Elevation shadows.
abstract final class UpShadows {
  /// Token: `shadow.none`
  static const List<BoxShadow> none = <BoxShadow>[];

  /// Token: `shadow.sm`
  static const List<BoxShadow> sm = <BoxShadow>[
    BoxShadow(
      color: Color(0x33000000),
      offset: Offset(0, 1),
      blurRadius: 3,
      spreadRadius: 0,
    ),
  ];

  /// Token: `shadow.md`
  static const List<BoxShadow> md = <BoxShadow>[
    BoxShadow(
      color: Color(0x80000000),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  /// Floating kit cards / track card (SHOT)
  ///
  /// Token: `shadow.lg`
  static const List<BoxShadow> lg = <BoxShadow>[
    BoxShadow(
      color: Color(0xA0000000),
      offset: Offset(0, 10),
      blurRadius: 28,
      spreadRadius: 0,
    ),
  ];

  /// Hard bottom edge under neon pads (SHOT)
  ///
  /// Token: `shadow.padBevel`
  static const List<BoxShadow> padBevel = <BoxShadow>[
    BoxShadow(
      color: Color(0x80000000),
      offset: Offset(0, 3),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];
}

/// Glow recipes; colour is supplied at runtime.
abstract final class UpGlows {
  /// Token: `glow.none`
  static const UpGlowSpec none = UpGlowSpec(<UpGlowLayer>[]);

  /// Token: `glow.sm`
  static const UpGlowSpec sm = UpGlowSpec(<UpGlowLayer>[
    UpGlowLayer(opacity: 0.55, blur: 8, spread: 0, dx: 0, dy: 0),
  ]);

  /// Token: `glow.md`
  static const UpGlowSpec md = UpGlowSpec(<UpGlowLayer>[
    UpGlowLayer(opacity: 0.65, blur: 12, spread: 0, dx: 0, dy: 0),
    UpGlowLayer(opacity: 0.3, blur: 28, spread: 2, dx: 0, dy: 0),
  ]);

  /// Token: `glow.lg`
  static const UpGlowSpec lg = UpGlowSpec(<UpGlowLayer>[
    UpGlowLayer(opacity: 0.75, blur: 16, spread: 1, dx: 0, dy: 0),
    UpGlowLayer(opacity: 0.35, blur: 40, spread: 6, dx: 0, dy: 0),
  ]);
}

/// Size scale (logical px).
abstract final class UpSizes {
  /// Token: `size.icon.xs`
  static const double iconXs = 12;

  /// Token: `size.icon.sm`
  static const double iconSm = 16;

  /// Token: `size.icon.md`
  static const double iconMd = 20;

  /// Token: `size.icon.lg`
  static const double iconLg = 24;

  /// Token: `size.icon.xl`
  static const double iconXl = 32;

  /// Token: `size.icon.xxl`
  static const double iconXxl = 48;

  /// Token: `size.touch.min`
  static const double touchMin = 44;

  /// Token: `size.touch.comfortable`
  static const double touchComfortable = 48;

  /// APK toolbar
  ///
  /// Token: `size.bar.toolbar`
  static const double barToolbar = 56;

  /// APK tab bar / appbar
  ///
  /// Token: `size.bar.tabbar`
  static const double barTabbar = 50;

  /// APK pads menu bar / tutorial bar
  ///
  /// Token: `size.bar.menu`
  static const double barMenu = 36;

  /// APK edit pad header
  ///
  /// Token: `size.bar.header`
  static const double barHeader = 44;

  /// Token: `size.bar.banner`
  static const double barBanner = 54;

  /// Token: `size.control.xs`
  static const double controlXs = 20;

  /// Token: `size.control.sm`
  static const double controlSm = 28;

  /// APK edit pad buttons 34-36
  ///
  /// Token: `size.control.md`
  static const double controlMd = 34;

  /// Token: `size.control.lg`
  static const double controlLg = 44;

  /// APK sub_button height
  ///
  /// Token: `size.control.xl`
  static const double controlXl = 54;

  /// APK A/B button 56x56
  ///
  /// Token: `size.control.ab`
  static const double controlAb = 56;

  /// Token: `size.content.subButtonWidth`
  static const double contentSubButtonWidth = 335;

  /// Token: `size.content.featuredWidth`
  static const double contentFeaturedWidth = 300;

  /// Token: `size.content.featuredHeight`
  static const double contentFeaturedHeight = 160;

  /// Token: `size.content.featuredHolderHeight`
  static const double contentFeaturedHolderHeight = 175;

  /// Token: `size.content.videoHeight`
  static const double contentVideoHeight = 211;

  /// Token: `size.content.kitCellHeight`
  static const double contentKitCellHeight = 60;

  /// Token: `size.content.editRowHeight`
  static const double contentEditRowHeight = 100;

  /// Token: `size.content.tabletMaxWidth`
  static const double contentTabletMaxWidth = 600;
}

/// Spacing scale (logical px).
abstract final class UpSpacing {
  /// Token: `spacing.none`
  static const double none = 0;

  /// APK pad cell margin
  ///
  /// Token: `spacing.hair`
  static const double hair = 1;

  /// APK gap between pads
  ///
  /// Token: `spacing.xxs`
  static const double xxs = 2;

  /// Token: `spacing.xs`
  static const double xs = 4;

  /// Token: `spacing.sm`
  static const double sm = 6;

  /// Token: `spacing.md`
  static const double md = 8;

  /// APK pads page horizontal margin
  ///
  /// Token: `spacing.lg`
  static const double lg = 10;

  /// Token: `spacing.xl`
  static const double xl = 12;

  /// APK fab_margin / text_margin
  ///
  /// Token: `spacing.xxl`
  static const double xxl = 16;

  /// Token: `spacing.xxxl`
  static const double xxxl = 20;

  /// Token: `spacing.huge`
  static const double huge = 24;

  /// Token: `spacing.giant`
  static const double giant = 32;

  /// Token: `spacing.massive`
  static const double massive = 48;
}

/// Font family stacks: [private family, open fallback].
abstract final class UpFontFamilies {
  /// APK Calligraphy global default
  ///
  /// Token: `font.family.regular`
  static const List<String> regular = <String>['Uni Sans', 'Montserrat'];

  /// Titles, buttons, pad numbers
  ///
  /// Token: `font.family.heavy`
  static const List<String> heavy = <String>['Uni Sans Heavy', 'Montserrat'];

  /// INSPIRED BY
  ///
  /// Token: `font.family.thin`
  static const List<String> thin = <String>['Uni Sans Thin', 'Montserrat'];
}

/// Font weights.
abstract final class UpFontWeights {
  /// Token: `font.weight.thin`
  static const FontWeight thin = FontWeight.w100;

  /// Token: `font.weight.regular`
  static const FontWeight regular = FontWeight.w400;

  /// Token: `font.weight.heavy`
  static const FontWeight heavy = FontWeight.w800;
}

/// Font sizes (logical px).
abstract final class UpFontSizes {
  /// APK INSPIRED BY
  ///
  /// Token: `font.size.xxxs`
  static const double xxxs = 8;

  /// Token: `font.size.xxs`
  static const double xxs = 9;

  /// Token: `font.size.xs`
  static const double xs = 10;

  /// APK kit name
  ///
  /// Token: `font.size.sm`
  static const double sm = 12;

  /// Token: `font.size.md`
  static const double md = 14;

  /// APK body max
  ///
  /// Token: `font.size.lg`
  static const double lg = 15;

  /// APK title / A-B button
  ///
  /// Token: `font.size.xl`
  static const double xl = 16;

  /// Token: `font.size.xxl`
  static const double xxl = 20;

  /// Token: `font.size.xxxl`
  static const double xxxl = 24;

  /// Token: `font.size.display`
  static const double display = 32;

  /// Token: `font.size.hero`
  static const double hero = 44;
}

/// Letter spacing (logical px).
abstract final class UpLetterSpacings {
  /// Token: `font.letterSpacing.tight`
  static const double tight = -0.2;

  /// Token: `font.letterSpacing.none`
  static const double none = 0;

  /// All-caps labels
  ///
  /// Token: `font.letterSpacing.caps`
  static const double caps = 0.5;

  /// All-caps overlines
  ///
  /// Token: `font.letterSpacing.capsWide`
  static const double capsWide = 1.2;
}

/// Line height multipliers.
abstract final class UpLineHeights {
  /// Token: `font.lineHeight.tight`
  static const double tight = 1;

  /// Token: `font.lineHeight.snug`
  static const double snug = 1.15;

  /// Token: `font.lineHeight.normal`
  static const double normal = 1.3;

  /// Token: `font.lineHeight.relaxed`
  static const double relaxed = 1.5;
}

/// Text role specs. Build a TextStyle via `UpTheme.of(context).text`.
abstract final class UpTextRoles {
  /// Token: `typography.hero`
  static const UpTextRoleSpec hero = UpTextRoleSpec(
    family: 'Uni Sans Heavy',
    fallbackFamily: 'Montserrat',
    size: 44,
    weight: FontWeight.w800,
    letterSpacing: -0.2,
    height: 1,
    textCase: UpTextCase.none,
  );

  /// Token: `typography.display`
  static const UpTextRoleSpec display = UpTextRoleSpec(
    family: 'Uni Sans Heavy',
    fallbackFamily: 'Montserrat',
    size: 32,
    weight: FontWeight.w800,
    letterSpacing: 0,
    height: 1,
    textCase: UpTextCase.upper,
  );

  /// Token: `typography.headline`
  static const UpTextRoleSpec headline = UpTextRoleSpec(
    family: 'Uni Sans Heavy',
    fallbackFamily: 'Montserrat',
    size: 24,
    weight: FontWeight.w800,
    letterSpacing: 0,
    height: 1.15,
    textCase: UpTextCase.upper,
  );

  /// Token: `typography.title`
  static const UpTextRoleSpec title = UpTextRoleSpec(
    family: 'Uni Sans Heavy',
    fallbackFamily: 'Montserrat',
    size: 16,
    weight: FontWeight.w800,
    letterSpacing: 0.5,
    height: 1.15,
    textCase: UpTextCase.upper,
  );

  /// Token: `typography.titleSm`
  static const UpTextRoleSpec titleSm = UpTextRoleSpec(
    family: 'Uni Sans Heavy',
    fallbackFamily: 'Montserrat',
    size: 14,
    weight: FontWeight.w800,
    letterSpacing: 0.5,
    height: 1.15,
    textCase: UpTextCase.upper,
  );

  /// Token: `typography.label`
  static const UpTextRoleSpec label = UpTextRoleSpec(
    family: 'Uni Sans Heavy',
    fallbackFamily: 'Montserrat',
    size: 12,
    weight: FontWeight.w800,
    letterSpacing: 0.5,
    height: 1.15,
    textCase: UpTextCase.upper,
  );

  /// Token: `typography.labelSm`
  static const UpTextRoleSpec labelSm = UpTextRoleSpec(
    family: 'Uni Sans Heavy',
    fallbackFamily: 'Montserrat',
    size: 10,
    weight: FontWeight.w800,
    letterSpacing: 0.5,
    height: 1.15,
    textCase: UpTextCase.upper,
  );

  /// Token: `typography.overline`
  static const UpTextRoleSpec overline = UpTextRoleSpec(
    family: 'Uni Sans',
    fallbackFamily: 'Montserrat',
    size: 8,
    weight: FontWeight.w400,
    letterSpacing: 1.2,
    height: 1.15,
    textCase: UpTextCase.upper,
  );

  /// Token: `typography.inspired`
  static const UpTextRoleSpec inspired = UpTextRoleSpec(
    family: 'Uni Sans Thin',
    fallbackFamily: 'Montserrat',
    size: 8,
    weight: FontWeight.w100,
    letterSpacing: 1.2,
    height: 1.15,
    textCase: UpTextCase.upper,
  );

  /// Token: `typography.body`
  static const UpTextRoleSpec body = UpTextRoleSpec(
    family: 'Uni Sans',
    fallbackFamily: 'Montserrat',
    size: 14,
    weight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.3,
    textCase: UpTextCase.none,
  );

  /// Token: `typography.bodySm`
  static const UpTextRoleSpec bodySm = UpTextRoleSpec(
    family: 'Uni Sans',
    fallbackFamily: 'Montserrat',
    size: 12,
    weight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.3,
    textCase: UpTextCase.none,
  );

  /// Token: `typography.caption`
  static const UpTextRoleSpec caption = UpTextRoleSpec(
    family: 'Uni Sans',
    fallbackFamily: 'Montserrat',
    size: 10,
    weight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.3,
    textCase: UpTextCase.none,
  );

  /// Token: `typography.button`
  static const UpTextRoleSpec button = UpTextRoleSpec(
    family: 'Uni Sans Heavy',
    fallbackFamily: 'Montserrat',
    size: 14,
    weight: FontWeight.w800,
    letterSpacing: 0.5,
    height: 1,
    textCase: UpTextCase.upper,
  );

  /// Token: `typography.tab`
  static const UpTextRoleSpec tab = UpTextRoleSpec(
    family: 'Uni Sans Heavy',
    fallbackFamily: 'Montserrat',
    size: 10,
    weight: FontWeight.w800,
    letterSpacing: 0.5,
    height: 1,
    textCase: UpTextCase.upper,
  );

  /// Token: `typography.padBank`
  static const UpTextRoleSpec padBank = UpTextRoleSpec(
    family: 'Uni Sans Heavy',
    fallbackFamily: 'Montserrat',
    size: 16,
    weight: FontWeight.w800,
    letterSpacing: 0,
    height: 1,
    textCase: UpTextCase.upper,
  );

  /// fontSize is a design-time default; runtime size = pad width * ratio.padNumberSize.
  ///
  /// Token: `typography.padNumber`
  static const UpTextRoleSpec padNumber = UpTextRoleSpec(
    family: 'Uni Sans Heavy',
    fallbackFamily: 'Montserrat',
    size: 16,
    weight: FontWeight.w800,
    letterSpacing: 0,
    height: 1,
    textCase: UpTextCase.upper,
  );

  /// Token: `typography.numeric`
  static const UpTextRoleSpec numeric = UpTextRoleSpec(
    family: 'Uni Sans Heavy',
    fallbackFamily: 'Montserrat',
    size: 12,
    weight: FontWeight.w800,
    letterSpacing: 0,
    height: 1,
    textCase: UpTextCase.none,
  );
}

/// Typography roles (DTCG `typography.*`). Resolve a TextStyle with
/// `UpTheme.of(context).text[UpTextRole.title]`.
enum UpTextRole {
  /// Token: `typography.hero`
  hero(UpTextRoles.hero),

  /// Token: `typography.display`
  display(UpTextRoles.display),

  /// Token: `typography.headline`
  headline(UpTextRoles.headline),

  /// Token: `typography.title`
  title(UpTextRoles.title),

  /// Token: `typography.titleSm`
  titleSm(UpTextRoles.titleSm),

  /// Token: `typography.label`
  label(UpTextRoles.label),

  /// Token: `typography.labelSm`
  labelSm(UpTextRoles.labelSm),

  /// Token: `typography.overline`
  overline(UpTextRoles.overline),

  /// Token: `typography.inspired`
  inspired(UpTextRoles.inspired),

  /// Token: `typography.body`
  body(UpTextRoles.body),

  /// Token: `typography.bodySm`
  bodySm(UpTextRoles.bodySm),

  /// Token: `typography.caption`
  caption(UpTextRoles.caption),

  /// Token: `typography.button`
  button(UpTextRoles.button),

  /// Token: `typography.tab`
  tab(UpTextRoles.tab),

  /// Token: `typography.padBank`
  padBank(UpTextRoles.padBank),

  /// fontSize is a design-time default; runtime size = pad width * ratio.padNumberSize.
  ///
  /// Token: `typography.padNumber`
  padNumber(UpTextRoles.padNumber),

  /// Token: `typography.numeric`
  numeric(UpTextRoles.numeric);

  const UpTextRole(this.spec);

  /// Raw token values for this role.
  final UpTextRoleSpec spec;
}
