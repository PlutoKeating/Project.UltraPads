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

  /// IPA dividers / tab bar top line (img_white α0.1)
  ///
  /// Token: `color.alpha.white.10`
  static const Color alphaWhite10 = Color(0x1AFFFFFF);

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

  /// IPA INSPIRED BY text α0.6
  ///
  /// Token: `color.alpha.white.60`
  static const Color alphaWhite60 = Color(0x99FFFFFF);

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

  /// IPA kit editor separator / selection outside
  ///
  /// Token: `color.alpha.black.40`
  static const Color alphaBlack40 = Color(0x66000000);

  /// APK black_50
  ///
  /// Token: `color.alpha.black.50`
  static const Color alphaBlack50 = Color(0x80000000);

  /// IPA nav bar shadow 60%
  ///
  /// Token: `color.alpha.black.60`
  static const Color alphaBlack60 = Color(0x99000000);

  /// APK black_opacity (scrim)
  ///
  /// Token: `color.alpha.black.63`
  static const Color alphaBlack63 = Color(0xA0000000);

  /// APK background_download_kit
  ///
  /// Token: `color.alpha.black.67`
  static const Color alphaBlack67 = Color(0xAC000000);

  /// IPA tutorial / full-page dark overlay 70%
  ///
  /// Token: `color.alpha.black.70`
  static const Color alphaBlack70 = Color(0xB3000000);

  /// IPA kit preview overlay 80%
  ///
  /// Token: `color.alpha.black.80`
  static const Color alphaBlack80 = Color(0xCC000000);

  /// IPA secondary: skin panel divider, SAVE text, input focus (APK primary)
  ///
  /// Token: `color.brand.rose`
  static const Color brandRose = Color(0xFFF73873);

  /// APK selected_kit / skin_price
  ///
  /// Token: `color.brand.roseLight`
  static const Color brandRoseLight = Color(0xFFF93E78);

  /// alias of brand.pink (APK red_pink_two)
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

  /// IPA primary accent: SONGS button, tab underline, kit selection bar, progress
  ///
  /// Token: `color.brand.pink`
  static const Color brandPink = Color(0xFFFD1A68);

  /// IPA secondary: skin price, genre check
  ///
  /// Token: `color.brand.rosePad`
  static const Color brandRosePad = Color(0xFFF73470);

  /// IPA kit editor page background
  ///
  /// Token: `color.brand.create`
  static const Color brandCreate = Color(0xFFEE4286);

  /// IPA rate dialog NO / CANCEL outline
  ///
  /// Token: `color.brand.alert`
  static const Color brandAlert = Color(0xFFFD155F);

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

  /// IPA perform page, nav bars, skin panel, kit preview modal
  ///
  /// Token: `color.ui.bgPads`
  static const Color uiBgPads = Color(0xFF242B2E);

  /// IPA library / search / save-kit pages, tab bar
  ///
  /// Token: `color.ui.bgMenu`
  static const Color uiBgMenu = Color(0xFF262B2F);

  /// IPA kit row, LOAD SOUND row, recording row
  ///
  /// Token: `color.ui.cell`
  static const Color uiCell = Color(0xFF2C3336);

  /// IPA kit row pressed
  ///
  /// Token: `color.ui.cellPressed`
  static const Color uiCellPressed = Color(0xFF252B2E);

  /// IPA featured card placeholder
  ///
  /// Token: `color.ui.placeholder`
  static const Color uiPlaceholder = Color(0xFF1E2225);

  /// IPA social bar / feedback button
  ///
  /// Token: `color.ui.social`
  static const Color uiSocial = Color(0xFF1A1D20);

  /// IPA watch-video unlock button / action sheet
  ///
  /// Token: `color.ui.modalButton`
  static const Color uiModalButton = Color(0xFF363F43);

  /// IPA library ads banner area
  ///
  /// Token: `color.ui.adsArea`
  static const Color uiAdsArea = Color(0xFF15181A);

  /// IPA featured pagination
  ///
  /// Token: `color.ui.paginationDot`
  static const Color uiPaginationDot = Color(0xFF484C4F);

  /// IPA speed button digits
  ///
  /// Token: `color.ui.textDark`
  static const Color uiTextDark = Color(0xFF282828);

  /// IPA library section titles
  ///
  /// Token: `color.ui.textSection`
  static const Color uiTextSection = Color(0xFF939BA3);

  /// IPA download counter
  ///
  /// Token: `color.ui.textMuted`
  static const Color uiTextMuted = Color(0xFF999999);

  /// IPA rate dialog input / toggle
  ///
  /// Token: `color.ui.inputText`
  static const Color uiInputText = Color(0xFF666666);

  /// IPA record button / timer
  ///
  /// Token: `color.ui.recRed`
  static const Color uiRecRed = Color(0xFFFF0000);

  /// IPA tutorial pad fill
  ///
  /// Token: `color.ui.tutorialFill`
  static const Color uiTutorialFill = Color(0xFF10CEF8);

  /// IPA tutorial pad outline
  ///
  /// Token: `color.ui.tutorialOutline`
  static const Color uiTutorialOutline = Color(0xFFBD1555);

  /// IPA tutorial loop icon
  ///
  /// Token: `color.ui.tutorialLoop`
  static const Color uiTutorialLoop = Color(0xFF02BCEB);

  /// IPA PERFECT feedback circle
  ///
  /// Token: `color.ui.perfect`
  static const Color uiPerfect = Color(0xFF1CCB19);

  /// IPA paywall background
  ///
  /// Token: `color.ui.premium`
  static const Color uiPremium = Color(0xFFFF156C);

  /// IPA paywall top
  ///
  /// Token: `color.ui.premiumTop`
  static const Color uiPremiumTop = Color(0xFFFD1A86);

  /// IPA offer badge
  ///
  /// Token: `color.ui.premiumBadge`
  static const Color uiPremiumBadge = Color(0xFFFBC800);

  /// IPA paywall privacy band
  ///
  /// Token: `color.ui.premiumCyan`
  static const Color uiPremiumCyan = Color(0xFF00CCFF);

  /// IPA subscription banner slash
  ///
  /// Token: `color.ui.signatureCyan`
  static const Color uiSignatureCyan = Color(0xFF00CBFE);

  /// IPA subscription banner glow
  ///
  /// Token: `color.ui.signatureMagenta`
  static const Color uiSignatureMagenta = Color(0xFFFD1AD8);

  /// IPA kit thumbnail glow
  ///
  /// Token: `color.ui.thumbCyan`
  static const Color uiThumbCyan = Color(0xFF52DAFF);

  /// IPA kit thumbnail glow
  ///
  /// Token: `color.ui.thumbMagenta`
  static const Color uiThumbMagenta = Color(0xFFFF52DD);

  /// IPA Halloween live-ops modal
  ///
  /// Token: `color.ui.liveOps`
  static const Color uiLiveOps = Color(0xFF371D55);

  /// Token: `color.pad.blue.base`
  static const Color padBlueBase = Color(0xFF00CBF7);

  /// Token: `color.pad.blue.highlight`
  static const Color padBlueHighlight = Color(0xFF3FDDFE);

  /// Token: `color.pad.blue.edge`
  static const Color padBlueEdge = Color(0xFF22D7FD);

  /// Token: `color.pad.blue.pressed`
  static const Color padBluePressed = Color(0xFFC2F2FC);

  /// Token: `color.pad.blue.pressedAlt`
  static const Color padBluePressedAlt = Color(0xFFB3EFFC);

  /// Token: `color.pad.orange.base`
  static const Color padOrangeBase = Color(0xFFEB7F00);

  /// Token: `color.pad.orange.bitmap`
  static const Color padOrangeBitmap = Color(0xFFE97B00);

  /// Token: `color.pad.orange.highlight`
  static const Color padOrangeHighlight = Color(0xFFFAA600);

  /// Token: `color.pad.orange.edge`
  static const Color padOrangeEdge = Color(0xFFF29300);

  /// Token: `color.pad.orange.pressed`
  static const Color padOrangePressed = Color(0xFFFDE7BF);

  /// Token: `color.pad.green.base`
  static const Color padGreenBase = Color(0xFF00C200);

  /// Token: `color.pad.green.highlight`
  static const Color padGreenHighlight = Color(0xFF14E200);

  /// Token: `color.pad.green.edge`
  static const Color padGreenEdge = Color(0xFF0BD300);

  /// Token: `color.pad.green.pressed`
  static const Color padGreenPressed = Color(0xFFC4F7C0);

  /// Token: `color.pad.pink.base`
  static const Color padPinkBase = Color(0xFFF73470);

  /// Token: `color.pad.pink.highlight`
  static const Color padPinkHighlight = Color(0xFFF9508B);

  /// Token: `color.pad.pink.edge`
  static const Color padPinkEdge = Color(0xFFF9508A);

  /// Token: `color.pad.pink.pressed`
  static const Color padPinkPressed = Color(0xFFFFD9E4);

  /// Token: `color.skin.circle.blue`
  static const Color skinCircleBlue = Color(0xFF04C9E2);

  /// Token: `color.skin.circle.orange`
  static const Color skinCircleOrange = Color(0xFFFE9F4C);

  /// Token: `color.skin.circle.green`
  static const Color skinCircleGreen = Color(0xFF28D13A);

  /// Token: `color.skin.circle.pink`
  static const Color skinCirclePink = Color(0xFFFE54AE);

  /// Token: `color.skin.broken.bluePressed`
  static const Color skinBrokenBluePressed = Color(0xFFB3EFFC);

  /// Token: `color.skin.broken.orangePressed`
  static const Color skinBrokenOrangePressed = Color(0xFFF7CB99);

  /// Token: `color.skin.broken.greenPressed`
  static const Color skinBrokenGreenPressed = Color(0xFF99E699);

  /// Token: `color.skin.broken.pinkPressed`
  static const Color skinBrokenPinkPressed = Color(0xFFFBADC5);

  /// Token: `color.skin.square.1`
  static const Color skinSquare1 = Color(0xFF006673);

  /// Token: `color.skin.square.2`
  static const Color skinSquare2 = Color(0xFF008D9F);

  /// Token: `color.skin.square.3`
  static const Color skinSquare3 = Color(0xFF00B4CB);

  /// Token: `color.skin.square.4`
  static const Color skinSquare4 = Color(0xFF01D1EB);

  /// Token: `color.skin.square.5`
  static const Color skinSquare5 = Color(0xFF2DE8FF);

  /// Token: `color.skin.polished.blue.core`
  static const Color skinPolishedBlueCore = Color(0xFF8AE7FC);

  /// Token: `color.skin.polished.blue.mid`
  static const Color skinPolishedBlueMid = Color(0xFF57E1FF);

  /// Token: `color.skin.polished.blue.edge`
  static const Color skinPolishedBlueEdge = Color(0xFF0ECFF8);

  /// Token: `color.skin.polished.green.core`
  static const Color skinPolishedGreenCore = Color(0xFF83E481);

  /// Token: `color.skin.polished.green.mid`
  static const Color skinPolishedGreenMid = Color(0xFF1BEC00);

  /// Token: `color.skin.polished.green.edge`
  static const Color skinPolishedGreenEdge = Color(0xFF04C800);

  /// Token: `color.skin.polished.orange.core`
  static const Color skinPolishedOrangeCore = Color(0xFFF6C381);

  /// Token: `color.skin.polished.orange.mid`
  static const Color skinPolishedOrangeMid = Color(0xFFFFB200);

  /// Token: `color.skin.polished.orange.edge`
  static const Color skinPolishedOrangeEdge = Color(0xFFEC8300);

  /// Token: `color.skin.polished.pink.core`
  static const Color skinPolishedPinkCore = Color(0xFFFCA0BC);

  /// Token: `color.skin.polished.pink.mid`
  static const Color skinPolishedPinkMid = Color(0xFFFF6B99);

  /// Token: `color.skin.polished.pink.edge`
  static const Color skinPolishedPinkEdge = Color(0xFFF83C76);

  /// Token: `color.skin.clean.blue.core`
  static const Color skinCleanBlueCore = Color(0xFF04C8E1);

  /// Token: `color.skin.clean.blue.mid`
  static const Color skinCleanBlueMid = Color(0xFF02C0D8);

  /// Token: `color.skin.clean.blue.edge`
  static const Color skinCleanBlueEdge = Color(0xFF01B9D1);

  /// Token: `color.skin.clean.green.core`
  static const Color skinCleanGreenCore = Color(0xFF28CF39);

  /// Token: `color.skin.clean.green.mid`
  static const Color skinCleanGreenMid = Color(0xFF25C335);

  /// Token: `color.skin.clean.green.edge`
  static const Color skinCleanGreenEdge = Color(0xFF23B732);

  /// Token: `color.skin.clean.orange.core`
  static const Color skinCleanOrangeCore = Color(0xFFFB9C49);

  /// Token: `color.skin.clean.orange.mid`
  static const Color skinCleanOrangeMid = Color(0xFFEE8D38);

  /// Token: `color.skin.clean.orange.edge`
  static const Color skinCleanOrangeEdge = Color(0xFFE27E28);

  /// Token: `color.skin.clean.pink.core`
  static const Color skinCleanPinkCore = Color(0xFFF852A9);

  /// Token: `color.skin.clean.pink.mid`
  static const Color skinCleanPinkMid = Color(0xFFDF4A99);

  /// Token: `color.skin.clean.pink.edge`
  static const Color skinCleanPinkEdge = Color(0xFFC74388);

  /// Token: `color.skin.christmas.greenCore`
  static const Color skinChristmasGreenCore = Color(0xFF8CE38C);

  /// Token: `color.skin.christmas.greenMid`
  static const Color skinChristmasGreenMid = Color(0xFF54D654);

  /// Token: `color.skin.christmas.greenPressed`
  static const Color skinChristmasGreenPressed = Color(0xFFCBF2CB);

  /// Token: `color.skin.christmas.orangePressed`
  static const Color skinChristmasOrangePressed = Color(0xFFFAE4CB);

  /// Token: `color.skin.christmas.pinkPressed`
  static const Color skinChristmasPinkPressed = Color(0xFFFCC1D3);

  /// Token: `color.skin.muertos.greenCore`
  static const Color skinMuertosGreenCore = Color(0xFF009B00);

  /// Token: `color.skin.muertos.pinkCore`
  static const Color skinMuertosPinkCore = Color(0xFFF86291);

  /// Token: `color.skin.muertos.pinkEdge`
  static const Color skinMuertosPinkEdge = Color(0xFFD62D61);

  /// Token: `color.skin.pets.greenEdge`
  static const Color skinPetsGreenEdge = Color(0xFF00A800);

  /// Token: `color.skin.pets.orangeMid`
  static const Color skinPetsOrangeMid = Color(0xFFFF9F00);

  /// Token: `color.skin.pets.orangeEdge`
  static const Color skinPetsOrangeEdge = Color(0xFFCC6E00);

  /// Token: `color.skin.halloween.blue.core`
  static const Color skinHalloweenBlueCore = Color(0xFF2663BA);

  /// Token: `color.skin.halloween.blue.mid`
  static const Color skinHalloweenBlueMid = Color(0xFF164295);

  /// Token: `color.skin.halloween.blue.edge`
  static const Color skinHalloweenBlueEdge = Color(0xFF052171);

  /// Token: `color.skin.halloween.blue.pressed`
  static const Color skinHalloweenBluePressed = Color(0xFF618DF9);

  /// Token: `color.skin.halloween.green.core`
  static const Color skinHalloweenGreenCore = Color(0xFFC0E13B);

  /// Token: `color.skin.halloween.green.mid`
  static const Color skinHalloweenGreenMid = Color(0xFFB5D630);

  /// Token: `color.skin.halloween.green.edge`
  static const Color skinHalloweenGreenEdge = Color(0xFFA4C51D);

  /// Token: `color.skin.halloween.green.pressed`
  static const Color skinHalloweenGreenPressed = Color(0xFFE1FC76);

  /// Token: `color.skin.halloween.orange.core`
  static const Color skinHalloweenOrangeCore = Color(0xFFFEAD0D);

  /// Token: `color.skin.halloween.orange.mid`
  static const Color skinHalloweenOrangeMid = Color(0xFFFDA90C);

  /// Token: `color.skin.halloween.orange.edge`
  static const Color skinHalloweenOrangeEdge = Color(0xFFEB760A);

  /// Token: `color.skin.halloween.orange.pressed`
  static const Color skinHalloweenOrangePressed = Color(0xFFFFCB71);

  /// Token: `color.skin.halloween.pink.core`
  static const Color skinHalloweenPinkCore = Color(0xFFFE76AF);

  /// Token: `color.skin.halloween.pink.mid`
  static const Color skinHalloweenPinkMid = Color(0xFFE73F80);

  /// Token: `color.skin.halloween.pink.edge`
  static const Color skinHalloweenPinkEdge = Color(0xFFD91F64);

  /// Token: `color.skin.halloween.pink.pressed`
  static const Color skinHalloweenPinkPressed = Color(0xFFFF60A3);

  /// Token: `color.skin.halloween.purple.core`
  static const Color skinHalloweenPurpleCore = Color(0xFFC784E4);

  /// Token: `color.skin.halloween.purple.mid`
  static const Color skinHalloweenPurpleMid = Color(0xFFAF67CE);

  /// Token: `color.skin.halloween.purple.edge`
  static const Color skinHalloweenPurpleEdge = Color(0xFF7E4398);

  /// Token: `color.skin.halloween.purple.pressed`
  static const Color skinHalloweenPurplePressed = Color(0xFFE3A5FE);

  /// Token: `color.skin.lgbt.red`
  static const Color skinLgbtRed = Color(0xFFE9493F);

  /// Token: `color.skin.lgbt.yellow`
  static const Color skinLgbtYellow = Color(0xFFFEDF28);
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

  /// IPA pad press / loop flash white overlay peak (orange 0.8, green/pink 0.7)
  ///
  /// Token: `opacity.flash`
  static const double flash = 0.8;

  /// Token: `opacity.full`
  static const double full = 1;

  /// IPA green / pink press overlay peak
  ///
  /// Token: `opacity.flashSoft`
  static const double flashSoft = 0.7;

  /// IPA INSPIRED BY
  ///
  /// Token: `opacity.secondary`
  static const double secondary = 0.6;

  /// IPA empty pad dashed frame alpha
  ///
  /// Token: `opacity.emptyPad`
  static const double emptyPad = 0.2;
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

  /// APK selected pad 2dp; IPA skin panel divider 2px->1pt uses hairline
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

  /// IPA tab underline 3px
  ///
  /// Token: `borderWidth.tab`
  static const double tab = 1.5;

  /// IPA kit row selection bar 9px
  ///
  /// Token: `borderWidth.selection`
  static const double selection = 4.5;
}

/// Motion durations.
abstract final class UpDurations {
  /// Token: `motion.duration.instant`
  static const Duration instant = Duration(milliseconds: 0);

  /// IPA pad press: jump to lit state on the next frame (1/60 s)
  ///
  /// Token: `motion.duration.frame`
  static const Duration frame = Duration(milliseconds: 17);

  /// IPA pad release (QuadOut), loading grid step, wrong-mark fade-in
  ///
  /// Token: `motion.duration.fast`
  static const Duration fast = Duration(milliseconds: 100);

  /// APK bottom sheet slide (no IPA equivalent)
  ///
  /// Token: `motion.duration.quick`
  static const Duration quick = Duration(milliseconds: 150);

  /// IPA A/B page switch, text box / step label
  ///
  /// Token: `motion.duration.short`
  static const Duration short = Duration(milliseconds: 200);

  /// IPA skip-tutorial button slide-in
  ///
  /// Token: `motion.duration.skipSlide`
  static const Duration skipSlide = Duration(milliseconds: 250);

  /// IPA nav row collapse (Circ), list play/stop cross-scale, PERFECT rise
  ///
  /// Token: `motion.duration.medium`
  static const Duration medium = Duration(milliseconds: 300);

  /// IPA skin panel in/out, input label float
  ///
  /// Token: `motion.duration.slow`
  static const Duration slow = Duration(milliseconds: 400);

  /// IPA speed picker in, import OPEN KIT button
  ///
  /// Token: `motion.duration.modalIn`
  static const Duration modalIn = Duration(milliseconds: 500);

  /// IPA loop flash one way (yoyo); record button pulse
  ///
  /// Token: `motion.duration.loopHalf`
  static const Duration loopHalf = Duration(milliseconds: 600);

  /// IPA SONGS button glow segment
  ///
  /// Token: `motion.duration.breathe`
  static const Duration breathe = Duration(milliseconds: 783);

  /// IPA wrong-pad cross fade-out
  ///
  /// Token: `motion.duration.wrongOut`
  static const Duration wrongOut = Duration(milliseconds: 900);

  /// IPA speed picker out, record ripple, tutorial pad fill, first-open hand
  ///
  /// Token: `motion.duration.slower`
  static const Duration slower = Duration(milliseconds: 1000);

  /// IPA loop flash period and loop icon revolution
  ///
  /// Token: `motion.duration.loopCycle`
  static const Duration loopCycle = Duration(milliseconds: 1200);

  /// IPA splash logo
  ///
  /// Token: `motion.duration.splash`
  static const Duration splash = Duration(milliseconds: 1200);

  /// UP
  ///
  /// Token: `motion.duration.toast`
  static const Duration toast = Duration(milliseconds: 2500);

  /// UP featured carousel autoplay (not in IPA data)
  ///
  /// Token: `motion.duration.carousel`
  static const Duration carousel = Duration(milliseconds: 4000);

  /// IPA Square skin layer step (0.05 s)
  ///
  /// Token: `motion.duration.xfast`
  static const Duration xfast = Duration(milliseconds: 50);

  /// Press attack (IPA: next frame). Kept name for existing callers.
  ///
  /// Token: `motion.duration.padPressHalf`
  static const Duration padPressHalf = Duration(milliseconds: 17);

  /// IPA press flash total: 1 frame attack + 0.1 s release
  ///
  /// Token: `motion.duration.padPress`
  static const Duration padPress = Duration(milliseconds: 117);
}

/// Motion easing curves.
abstract final class UpEasings {
  /// IPA rotation / fill
  ///
  /// Token: `motion.easing.linear`
  static const Cubic linear = Cubic(0, 0, 1, 1);

  /// IPA default ease (most transitions)
  ///
  /// Token: `motion.easing.quadOut`
  static const Cubic quadOut = Cubic(0.25, 0.46, 0.45, 0.94);

  /// IPA first-open hand
  ///
  /// Token: `motion.easing.quadIn`
  static const Cubic quadIn = Cubic(0.55, 0.085, 0.68, 0.53);

  /// IPA nav row return, record ripple
  ///
  /// Token: `motion.easing.circOut`
  static const Cubic circOut = Cubic(0.075, 0.82, 0.165, 1);

  /// IPA nav row collapse
  ///
  /// Token: `motion.easing.circIn`
  static const Cubic circIn = Cubic(0.6, 0.04, 0.98, 0.335);

  /// APK AccelerateDecelerate (old)
  ///
  /// Token: `motion.easing.standard`
  static const Cubic standard = Cubic(0.42, 0, 0.58, 1);

  /// APK Decelerate (old)
  ///
  /// Token: `motion.easing.decelerate`
  static const Cubic decelerate = Cubic(0, 0, 0.2, 1);

  /// UP dialogs
  ///
  /// Token: `motion.easing.emphasized`
  static const Cubic emphasized = Cubic(0.2, 0, 0, 1);

  /// UP/APK accelerate
  ///
  /// Token: `motion.easing.accelerate`
  static const Cubic accelerate = Cubic(0.4, 0, 1, 1);
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

  /// APK save record / preview kit; IPA Default pad 9-slice corner ~ 13pt on 128pt pad
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
  /// IPA: 9-slice source 72px with ~26px corner -> ~10% of a 256px pad side (APK Lottie was 12%)
  ///
  /// Token: `ratio.padRadius`
  static const double padRadius = 0.1;

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
  /// IPA design canvas 828px
  ///
  /// Token: `size.canvas.width`
  static const double canvasWidth = 414;

  /// IPA design canvas 1472px
  ///
  /// Token: `size.canvas.height`
  static const double canvasHeight = 736;

  /// Token: `size.icon.xs`
  static const double iconXs = 12;

  /// Token: `size.icon.sm`
  static const double iconSm = 16;

  /// Token: `size.icon.md`
  static const double iconMd = 20;

  /// IPA tab bar icon 47px
  ///
  /// Token: `size.icon.lg`
  static const double iconLg = 23.5;

  /// Token: `size.icon.xl`
  static const double iconXl = 32;

  /// Token: `size.icon.xxl`
  static const double iconXxl = 48;

  /// Token: `size.touch.min`
  static const double touchMin = 44;

  /// IPA function buttons 100px
  ///
  /// Token: `size.touch.comfortable`
  static const double touchComfortable = 50;

  /// IPA library / kit editor navigation bar 100px
  ///
  /// Token: `size.bar.nav`
  static const double barNav = 50;

  /// IPA tab bar 100px
  ///
  /// Token: `size.bar.tabbar`
  static const double barTabbar = 50;

  /// IPA perform function button row 100px
  ///
  /// Token: `size.bar.functionRow`
  static const double barFunctionRow = 50;

  /// IPA ads banner 103px
  ///
  /// Token: `size.bar.banner`
  static const double barBanner = 51.5;

  /// IPA perform bottom logo area 106px
  ///
  /// Token: `size.bar.bottom`
  static const double barBottom = 53;

  /// APK toolbar (old)
  ///
  /// Token: `size.bar.toolbar`
  static const double barToolbar = 56;

  /// APK menu / tutorial bar (old)
  ///
  /// Token: `size.bar.menu`
  static const double barMenu = 36;

  /// APK seekbar thumb
  ///
  /// Token: `size.control.xs`
  static const double controlXs = 20;

  /// IPA tutorial slider grip 50px
  ///
  /// Token: `size.control.slider`
  static const double controlSlider = 25;

  /// IPA colour dot 70px
  ///
  /// Token: `size.control.swatch`
  static const double controlSwatch = 35;

  /// IPA SONGS button height 63px
  ///
  /// Token: `size.control.sm`
  static const double controlSm = 31.5;

  /// IPA function button inner block 84px
  ///
  /// Token: `size.control.md`
  static const double controlMd = 42;

  /// IPA nav close / search button 80px
  ///
  /// Token: `size.control.mdBox`
  static const double controlMdBox = 40;

  /// IPA generic btn 100px
  ///
  /// Token: `size.control.lg`
  static const double controlLg = 50;

  /// IPA modal buttons 124px
  ///
  /// Token: `size.control.xl`
  static const double controlXl = 62;

  /// IPA kit / LOAD SOUND row 132px
  ///
  /// Token: `size.control.row`
  static const double controlRow = 66;

  /// IPA A/B button 129x126px
  ///
  /// Token: `size.control.ab`
  static const double controlAb = 64.5;

  /// IPA microphone record button 170px
  ///
  /// Token: `size.control.rec`
  static const double controlRec = 85;

  /// IPA SONGS button 179px
  ///
  /// Token: `size.content.songsButtonWidth`
  static const double contentSongsButtonWidth = 89.5;

  /// IPA YouTube button 142x88px
  ///
  /// Token: `size.content.youtubeWidth`
  static const double contentYoutubeWidth = 71;

  /// Token: `size.content.youtubeHeight`
  static const double contentYoutubeHeight = 44;

  /// IPA LEARN TO PLAY button 420px
  ///
  /// Token: `size.content.tutorialButtonWidth`
  static const double contentTutorialButtonWidth = 210;

  /// IPA more button 65px
  ///
  /// Token: `size.content.moreButtonWidth`
  static const double contentMoreButtonWidth = 32.5;

  /// IPA speed button 146x78px
  ///
  /// Token: `size.content.speedButtonWidth`
  static const double contentSpeedButtonWidth = 73;

  /// Token: `size.content.speedButtonHeight`
  static const double contentSpeedButtonHeight = 39;

  /// IPA speed picker 226x280px
  ///
  /// Token: `size.content.speedModalWidth`
  static const double contentSpeedModalWidth = 113;

  /// Token: `size.content.speedModalHeight`
  static const double contentSpeedModalHeight = 140;

  /// IPA tutorial slider 511px
  ///
  /// Token: `size.content.sliderWidth`
  static const double contentSliderWidth = 255.5;

  /// IPA slider bar 10px
  ///
  /// Token: `size.content.sliderHeight`
  static const double contentSliderHeight = 5;

  /// IPA btn 500px
  ///
  /// Token: `size.content.buttonWidth`
  static const double contentButtonWidth = 250;

  /// IPA kit preview modal 675x924px
  ///
  /// Token: `size.content.modalWidth`
  static const double contentModalWidth = 337.5;

  /// Token: `size.content.modalHeight`
  static const double contentModalHeight = 462;

  /// IPA modal thumbnail 414px
  ///
  /// Token: `size.content.modalThumbHeight`
  static const double contentModalThumbHeight = 207;

  /// IPA modal button 555px
  ///
  /// Token: `size.content.modalButtonWidth`
  static const double contentModalButtonWidth = 277.5;

  /// IPA kit row thumbnail 147x109px
  ///
  /// Token: `size.content.kitThumbWidth`
  static const double contentKitThumbWidth = 73.5;

  /// Token: `size.content.kitThumbHeight`
  static const double contentKitThumbHeight = 54.5;

  /// IPA kit row text x 172px
  ///
  /// Token: `size.content.kitTextInset`
  static const double contentKitTextInset = 86;

  /// IPA featured card 489x274px
  ///
  /// Token: `size.content.featuredWidth`
  static const double contentFeaturedWidth = 244.5;

  /// Token: `size.content.featuredHeight`
  static const double contentFeaturedHeight = 137;

  /// IPA latest card 405x301px
  ///
  /// Token: `size.content.kitBigWidth`
  static const double contentKitBigWidth = 202.5;

  /// Token: `size.content.kitBigHeight`
  static const double contentKitBigHeight = 150.5;

  /// IPA artist card 139x174px
  ///
  /// Token: `size.content.kitSmallWidth`
  static const double contentKitSmallWidth = 69.5;

  /// Token: `size.content.kitSmallHeight`
  static const double contentKitSmallHeight = 87;

  /// IPA SEE ALL 336x67px
  ///
  /// Token: `size.content.seeAllWidth`
  static const double contentSeeAllWidth = 168;

  /// Token: `size.content.seeAllHeight`
  static const double contentSeeAllHeight = 33.5;

  /// IPA subscription banner 208px
  ///
  /// Token: `size.content.signatureHeight`
  static const double contentSignatureHeight = 104;

  /// IPA skin panel 488px
  ///
  /// Token: `size.content.skinPanelHeight`
  static const double contentSkinPanelHeight = 244;

  /// IPA skin item 230px
  ///
  /// Token: `size.content.skinItem`
  static const double contentSkinItem = 115;

  /// IPA skin thumbnail 150px
  ///
  /// Token: `size.content.skinThumb`
  static const double contentSkinThumb = 75;

  /// IPA kit editor mini pad 90px
  ///
  /// Token: `size.content.miniPad`
  static const double contentMiniPad = 45;

  /// IPA mini pad gap 8px
  ///
  /// Token: `size.content.miniPadGap`
  static const double contentMiniPadGap = 4;

  /// IPA mini pad panel 330x429px
  ///
  /// Token: `size.content.miniPanelWidth`
  static const double contentMiniPanelWidth = 165;

  /// Token: `size.content.miniPanelHeight`
  static const double contentMiniPanelHeight = 214.5;

  /// IPA edit pad panel 750x533px
  ///
  /// Token: `size.content.editPadWidth`
  static const double contentEditPadWidth = 375;

  /// IPA trim waveform 781x222px
  ///
  /// Token: `size.content.waveformWidth`
  static const double contentWaveformWidth = 390.5;

  /// Token: `size.content.waveformHeight`
  static const double contentWaveformHeight = 111;

  /// IPA search 750x72px
  ///
  /// Token: `size.content.searchFieldWidth`
  static const double contentSearchFieldWidth = 375;

  /// Token: `size.content.searchFieldHeight`
  static const double contentSearchFieldHeight = 36;

  /// IPA save-kit input 667x121px
  ///
  /// Token: `size.content.inputWidth`
  static const double contentInputWidth = 333.5;

  /// Token: `size.content.inputHeight`
  static const double contentInputHeight = 60.5;

  /// IPA first-open bubble 421x265px
  ///
  /// Token: `size.content.bubbleWidth`
  static const double contentBubbleWidth = 210.5;

  /// Token: `size.content.bubbleHeight`
  static const double contentBubbleHeight = 132.5;

  /// IPA tab selected circle 63px
  ///
  /// Token: `size.content.tabSelectedCircle`
  static const double contentTabSelectedCircle = 31.5;

  /// IPA profile sub tab 231x62px
  ///
  /// Token: `size.content.subTabWidth`
  static const double contentSubTabWidth = 115.5;

  /// Token: `size.content.subTabHeight`
  static const double contentSubTabHeight = 31;

  /// IPA rate dialog 606x873px
  ///
  /// Token: `size.content.dialogWidth`
  static const double contentDialogWidth = 303;

  /// UP
  ///
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

  /// IPA gap between pads (4px)
  ///
  /// Token: `spacing.xxs`
  static const double xxs = 2;

  /// Token: `spacing.xs`
  static const double xs = 4;

  /// Token: `spacing.sm`
  static const double sm = 6;

  /// Token: `spacing.md`
  static const double md = 8;

  /// APK pads page margin; IPA top bar x (20px)
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

  /// IPA pad area side margin (9px)
  ///
  /// Token: `spacing.edge`
  static const double edge = 4.5;

  /// IPA kit row thumbnail inset (11px)
  ///
  /// Token: `spacing.kitRowInset`
  static const double kitRowInset = 5.5;
}

/// Font family stacks: [private family, open fallback].
abstract final class UpFontFamilies {
  /// IPA OpenSans-Regular (alias Uni Sans / UniSansRegular)
  ///
  /// Token: `font.family.regular`
  static const List<String> regular = <String>['Open Sans'];

  /// IPA OpenSans-ExtraBold (alias UniSansHeavy)
  ///
  /// Token: `font.family.heavy`
  static const List<String> heavy = <String>['Open Sans'];

  /// IPA OpenSans-Light (alias UniSansThin)
  ///
  /// Token: `font.family.light`
  static const List<String> light = <String>['Open Sans'];

  /// Optional private skin font (APK)
  ///
  /// Token: `font.family.uniSansRegular`
  static const List<String> uniSansRegular = <String>['Uni Sans'];

  /// Optional private skin font (APK)
  ///
  /// Token: `font.family.uniSansHeavy`
  static const List<String> uniSansHeavy = <String>['Uni Sans Heavy'];

  /// Optional private skin font (APK)
  ///
  /// Token: `font.family.uniSansThin`
  static const List<String> uniSansThin = <String>['Uni Sans Thin'];
}

/// Font weights.
abstract final class UpFontWeights {
  /// Token: `font.weight.light`
  static const FontWeight light = FontWeight.w300;

  /// Token: `font.weight.regular`
  static const FontWeight regular = FontWeight.w400;

  /// Open Sans ExtraBold
  ///
  /// Token: `font.weight.heavy`
  static const FontWeight heavy = FontWeight.w800;
}

/// Font sizes (logical px).
abstract final class UpFontSizes {
  /// UP small overline (IMPORT FROM); not measured
  ///
  /// Token: `font.size.xxxs`
  static const double xxxs = 10;

  /// IPA INSPIRED BY 23px
  ///
  /// Token: `font.size.xxs`
  static const double xxs = 11.5;

  /// IPA SONGS button / small buttons 25px
  ///
  /// Token: `font.size.xs`
  static const double xs = 12.5;

  /// IPA buttons 28px
  ///
  /// Token: `font.size.sm`
  static const double sm = 14;

  /// IPA KIT + name 29px
  ///
  /// Token: `font.size.md`
  static const double md = 14.5;

  /// IPA first-open bubble 30px
  ///
  /// Token: `font.size.lg`
  static const double lg = 15;

  /// IPA LOAD SOUND title 32px
  ///
  /// Token: `font.size.xl`
  static const double xl = 16;

  /// IPA library section title 34px
  ///
  /// Token: `font.size.xxl`
  static const double xxl = 17;

  /// IPA kit row title 35px
  ///
  /// Token: `font.size.xxxl`
  static const double xxxl = 17.5;

  /// IPA page title 36px
  ///
  /// Token: `font.size.page`
  static const double page = 18;

  /// IPA speed digits 38px
  ///
  /// Token: `font.size.speed`
  static const double speed = 19;

  /// IPA edit pad numeric values 48px
  ///
  /// Token: `font.size.value`
  static const double value = 24;

  /// IPA A/B letter 60px; paywall title 60px
  ///
  /// Token: `font.size.bank`
  static const double bank = 30;

  /// IPA rate dialog title 70px
  ///
  /// Token: `font.size.display`
  static const double display = 35;
}

/// Letter spacing (logical px).
abstract final class UpLetterSpacings {
  /// Token: `font.letterSpacing.tight`
  static const double tight = -0.2;

  /// Token: `font.letterSpacing.none`
  static const double none = 0;

  /// All-caps labels (IPA: no extra tracking)
  ///
  /// Token: `font.letterSpacing.caps`
  static const double caps = 0;

  /// UP: tiny all-caps overlines
  ///
  /// Token: `font.letterSpacing.capsWide`
  static const double capsWide = 0.5;
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
  /// IPA walkthrough / paywall title
  ///
  /// Token: `typography.hero`
  static const UpTextRoleSpec hero = UpTextRoleSpec(
    family: 'Open Sans',
    size: 30,
    weight: FontWeight.w800,
    letterSpacing: -0.2,
    height: 1,
    textCase: UpTextCase.upper,
  );

  /// IPA rate dialog title
  ///
  /// Token: `typography.display`
  static const UpTextRoleSpec display = UpTextRoleSpec(
    family: 'Open Sans',
    size: 35,
    weight: FontWeight.w800,
    letterSpacing: 0,
    height: 1,
    textCase: UpTextCase.none,
  );

  /// IPA page title (KITS)
  ///
  /// Token: `typography.headline`
  static const UpTextRoleSpec headline = UpTextRoleSpec(
    family: 'Open Sans',
    size: 18,
    weight: FontWeight.w800,
    letterSpacing: 0,
    height: 1.15,
    textCase: UpTextCase.upper,
  );

  /// IPA kit row song title
  ///
  /// Token: `typography.title`
  static const UpTextRoleSpec title = UpTextRoleSpec(
    family: 'Open Sans',
    size: 17.5,
    weight: FontWeight.w800,
    letterSpacing: 0,
    height: 1.15,
    textCase: UpTextCase.upper,
  );

  /// IPA top bar kit name
  ///
  /// Token: `typography.titleSm`
  static const UpTextRoleSpec titleSm = UpTextRoleSpec(
    family: 'Open Sans',
    size: 14.5,
    weight: FontWeight.w800,
    letterSpacing: 0,
    height: 1.15,
    textCase: UpTextCase.upper,
  );

  /// IPA library section title (use text.section colour)
  ///
  /// Token: `typography.section`
  static const UpTextRoleSpec section = UpTextRoleSpec(
    family: 'Open Sans',
    size: 17,
    weight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.15,
    textCase: UpTextCase.upper,
  );

  /// IPA LOAD SOUND / EDIT PAD header
  ///
  /// Token: `typography.sheetTitle`
  static const UpTextRoleSpec sheetTitle = UpTextRoleSpec(
    family: 'Open Sans',
    size: 16,
    weight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.15,
    textCase: UpTextCase.upper,
  );

  /// Token: `typography.label`
  static const UpTextRoleSpec label = UpTextRoleSpec(
    family: 'Open Sans',
    size: 14,
    weight: FontWeight.w800,
    letterSpacing: 0,
    height: 1.15,
    textCase: UpTextCase.upper,
  );

  /// IPA SONGS button
  ///
  /// Token: `typography.labelSm`
  static const UpTextRoleSpec labelSm = UpTextRoleSpec(
    family: 'Open Sans',
    size: 12.5,
    weight: FontWeight.w800,
    letterSpacing: 0,
    height: 1.15,
    textCase: UpTextCase.upper,
  );

  /// Token: `typography.overline`
  static const UpTextRoleSpec overline = UpTextRoleSpec(
    family: 'Open Sans',
    size: 10,
    weight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.15,
    textCase: UpTextCase.upper,
  );

  /// IPA INSPIRED BY (colour text.secondary = white 60%)
  ///
  /// Token: `typography.inspired`
  static const UpTextRoleSpec inspired = UpTextRoleSpec(
    family: 'Open Sans',
    size: 11.5,
    weight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.15,
    textCase: UpTextCase.upper,
  );

  /// Token: `typography.body`
  static const UpTextRoleSpec body = UpTextRoleSpec(
    family: 'Open Sans',
    size: 14,
    weight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.3,
    textCase: UpTextCase.none,
  );

  /// Token: `typography.bodySm`
  static const UpTextRoleSpec bodySm = UpTextRoleSpec(
    family: 'Open Sans',
    size: 12.5,
    weight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.3,
    textCase: UpTextCase.none,
  );

  /// Token: `typography.caption`
  static const UpTextRoleSpec caption = UpTextRoleSpec(
    family: 'Open Sans',
    size: 11.5,
    weight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.3,
    textCase: UpTextCase.none,
  );

  /// IPA buttons 25-28px
  ///
  /// Token: `typography.button`
  static const UpTextRoleSpec button = UpTextRoleSpec(
    family: 'Open Sans',
    size: 14,
    weight: FontWeight.w800,
    letterSpacing: 0,
    height: 1,
    textCase: UpTextCase.upper,
  );

  /// Token: `typography.tab`
  static const UpTextRoleSpec tab = UpTextRoleSpec(
    family: 'Open Sans',
    size: 12.5,
    weight: FontWeight.w800,
    letterSpacing: 0,
    height: 1,
    textCase: UpTextCase.upper,
  );

  /// IPA first-open guide bubble (black on white)
  ///
  /// Token: `typography.bubble`
  static const UpTextRoleSpec bubble = UpTextRoleSpec(
    family: 'Open Sans',
    size: 15,
    weight: FontWeight.w800,
    letterSpacing: 0,
    height: 1.15,
    textCase: UpTextCase.upper,
  );

  /// IPA A/B letter
  ///
  /// Token: `typography.padBank`
  static const UpTextRoleSpec padBank = UpTextRoleSpec(
    family: 'Open Sans',
    size: 30,
    weight: FontWeight.w800,
    letterSpacing: 0,
    height: 1,
    textCase: UpTextCase.upper,
  );

  /// Design-time default; runtime size = pad width * ratio.padNumberSize.
  ///
  /// Token: `typography.padNumber`
  static const UpTextRoleSpec padNumber = UpTextRoleSpec(
    family: 'Open Sans',
    size: 16,
    weight: FontWeight.w800,
    letterSpacing: 0,
    height: 1,
    textCase: UpTextCase.upper,
  );

  /// IPA speed 1.0 (colour transport.speedText)
  ///
  /// Token: `typography.numeric`
  static const UpTextRoleSpec numeric = UpTextRoleSpec(
    family: 'Open Sans',
    size: 19,
    weight: FontWeight.w800,
    letterSpacing: 0,
    height: 1,
    textCase: UpTextCase.none,
  );

  /// IPA edit pad VOLUME / PITCH / GROUP values
  ///
  /// Token: `typography.value`
  static const UpTextRoleSpec value = UpTextRoleSpec(
    family: 'Open Sans',
    size: 24,
    weight: FontWeight.w400,
    letterSpacing: 0,
    height: 1,
    textCase: UpTextCase.none,
  );
}

/// Typography roles (DTCG `typography.*`). Resolve a TextStyle with
/// `UpTheme.of(context).text[UpTextRole.title]`.
enum UpTextRole {
  /// IPA walkthrough / paywall title
  ///
  /// Token: `typography.hero`
  hero(UpTextRoles.hero),

  /// IPA rate dialog title
  ///
  /// Token: `typography.display`
  display(UpTextRoles.display),

  /// IPA page title (KITS)
  ///
  /// Token: `typography.headline`
  headline(UpTextRoles.headline),

  /// IPA kit row song title
  ///
  /// Token: `typography.title`
  title(UpTextRoles.title),

  /// IPA top bar kit name
  ///
  /// Token: `typography.titleSm`
  titleSm(UpTextRoles.titleSm),

  /// IPA library section title (use text.section colour)
  ///
  /// Token: `typography.section`
  section(UpTextRoles.section),

  /// IPA LOAD SOUND / EDIT PAD header
  ///
  /// Token: `typography.sheetTitle`
  sheetTitle(UpTextRoles.sheetTitle),

  /// Token: `typography.label`
  label(UpTextRoles.label),

  /// IPA SONGS button
  ///
  /// Token: `typography.labelSm`
  labelSm(UpTextRoles.labelSm),

  /// Token: `typography.overline`
  overline(UpTextRoles.overline),

  /// IPA INSPIRED BY (colour text.secondary = white 60%)
  ///
  /// Token: `typography.inspired`
  inspired(UpTextRoles.inspired),

  /// Token: `typography.body`
  body(UpTextRoles.body),

  /// Token: `typography.bodySm`
  bodySm(UpTextRoles.bodySm),

  /// Token: `typography.caption`
  caption(UpTextRoles.caption),

  /// IPA buttons 25-28px
  ///
  /// Token: `typography.button`
  button(UpTextRoles.button),

  /// Token: `typography.tab`
  tab(UpTextRoles.tab),

  /// IPA first-open guide bubble (black on white)
  ///
  /// Token: `typography.bubble`
  bubble(UpTextRoles.bubble),

  /// IPA A/B letter
  ///
  /// Token: `typography.padBank`
  padBank(UpTextRoles.padBank),

  /// Design-time default; runtime size = pad width * ratio.padNumberSize.
  ///
  /// Token: `typography.padNumber`
  padNumber(UpTextRoles.padNumber),

  /// IPA speed 1.0 (colour transport.speedText)
  ///
  /// Token: `typography.numeric`
  numeric(UpTextRoles.numeric),

  /// IPA edit pad VOLUME / PITCH / GROUP values
  ///
  /// Token: `typography.value`
  value(UpTextRoles.value);

  const UpTextRole(this.spec);

  /// Raw token values for this role.
  final UpTextRoleSpec spec;
}
