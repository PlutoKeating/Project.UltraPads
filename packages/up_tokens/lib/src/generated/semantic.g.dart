// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: design/tokens/src (W3C DTCG) -> Style Dictionary -> design/tokens/scripts/build.mjs
// Regenerate with `just tokens` (cd design/tokens && pnpm run build).
// ignore_for_file: type=lint, unused_import

import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../runtime/gradient.dart';
import '../runtime/pad_role.dart';

/// Value type of a semantic token (what a skin may override).
enum UpSemanticType { color, gradient, number, dimension }

/// Metadata for one semantic token (used by the skin editor and JSON codec).
@immutable
class UpSemanticTokenInfo {
  const UpSemanticTokenInfo(this.key, this.type, this.description);

  /// Dotted DTCG path, e.g. `pad.palette.0.core`. Stable JSON key.
  final String key;
  final UpSemanticType type;
  final String? description;

  /// First path segment (`surface`, `pad`, ...), for grouping in editors.
  String get group => key.split('.').first;
}

/// All semantic tokens of one skin. Generated from the DTCG semantic layer;
/// themes (neon / outline / light) and user skins are instances of this class.
@immutable
class UpSemantic {
  const UpSemantic({
    required this.transportBackground,
    required this.transportStopBackground,
    required this.transportStopIcon,
    required this.transportWaveformPlayed,
    required this.transportWaveformUnplayed,
    required this.transportProgressTrack,
    required this.transportProgressFill,
    required this.transportThumb,
    required this.transportSpeedBackground,
    required this.transportSpeedText,
    required this.chipBackground,
    required this.chipForeground,
    required this.chipIconBox,
    required this.chipSelectedBackground,
    required this.chipSelectedForeground,
    required this.chipSelectedIconBox,
    required this.chipHintBackground,
    required this.chipHintForeground,
    required this.cardBackground,
    required this.cardBackgroundSelected,
    required this.cardBorder,
    required this.cardTitle,
    required this.cardSubtitle,
    required this.cardOverline,
    required this.cardSelectedIndicator,
    required this.cardPlaceholder,
    required this.cardCounter,
    required this.bannerScrim,
    required this.bannerIndicator,
    required this.bannerIndicatorActive,
    required this.sheetBackground,
    required this.sheetHeader,
    required this.sheetHandle,
    required this.sheetItem,
    required this.sheetItemPressed,
    required this.sheetItemIconBox,
    required this.sheetUnderline,
    required this.listItem,
    required this.listItemPressed,
    required this.listSeparator,
    required this.badgeBackground,
    required this.badgeForeground,
    required this.badgeNew,
    required this.badgeTop,
    required this.badgeTopForeground,
    required this.buttonPrimaryBackground,
    required this.buttonPrimaryForeground,
    required this.buttonPrimaryPressed,
    required this.buttonSecondaryBackground,
    required this.buttonSecondaryForeground,
    required this.buttonOutlineBorder,
    required this.buttonGhostForeground,
    required this.buttonDangerBackground,
    required this.buttonDisabledBackground,
    required this.buttonDisabledForeground,
    required this.buttonAlertBorder,
    required this.buttonWhiteBackground,
    required this.buttonWhiteForeground,
    required this.inputBackground,
    required this.inputForeground,
    required this.inputPlaceholder,
    required this.inputCursor,
    required this.inputBorder,
    required this.inputFocus,
    required this.sliderTrack,
    required this.sliderFill,
    required this.sliderThumb,
    required this.dialogBackground,
    required this.dialogScrim,
    required this.dialogLight,
    required this.dialogLightTitle,
    required this.dialogLightText,
    required this.toastBackground,
    required this.toastForeground,
    required this.meterTrack,
    required this.meterLow,
    required this.meterMid,
    required this.meterHigh,
    required this.meterPeak,
    required this.waveformActive,
    required this.waveformInactive,
    required this.waveformSelection,
    required this.waveformMarker,
    required this.progressRingTrack,
    required this.progressRingFill,
    required this.recordIndicator,
    required this.recordTrackCard,
    required this.genreLabel,
    required this.genreRing,
    required this.genreCheck,
    required this.genreTabSelected,
    required this.swatchRing,
    required this.hubOnline,
    required this.hubPairing,
    required this.hubOffline,
    required this.padPalette0Core,
    required this.padPalette0Mid,
    required this.padPalette0Edge,
    required this.padPalette0Glow,
    required this.padPalette0Pressed,
    required this.padPalette1Core,
    required this.padPalette1Mid,
    required this.padPalette1Edge,
    required this.padPalette1Glow,
    required this.padPalette1Pressed,
    required this.padPalette2Core,
    required this.padPalette2Mid,
    required this.padPalette2Edge,
    required this.padPalette2Glow,
    required this.padPalette2Pressed,
    required this.padPalette3Core,
    required this.padPalette3Mid,
    required this.padPalette3Edge,
    required this.padPalette3Glow,
    required this.padPalette3Pressed,
    required this.padPalette4Core,
    required this.padPalette4Mid,
    required this.padPalette4Edge,
    required this.padPalette4Glow,
    required this.padPalette4Pressed,
    required this.padPalette5Core,
    required this.padPalette5Mid,
    required this.padPalette5Edge,
    required this.padPalette5Glow,
    required this.padPalette5Pressed,
    required this.padPalette6Core,
    required this.padPalette6Mid,
    required this.padPalette6Edge,
    required this.padPalette6Glow,
    required this.padPalette6Pressed,
    required this.padPalette7Core,
    required this.padPalette7Mid,
    required this.padPalette7Edge,
    required this.padPalette7Glow,
    required this.padPalette7Pressed,
    required this.padShapeRadiusRatio,
    required this.padFillRadial,
    required this.padShowNumber,
    required this.padFlash,
    required this.padBorder,
    required this.padLabel,
    required this.padIdleFillOpacity,
    required this.padIdleBorderWidth,
    required this.padIdleGlow,
    required this.padIdleBevel,
    required this.padPressedFillOpacity,
    required this.padPressedFlashOpacity,
    required this.padPressedGlow,
    required this.padPressedScale,
    required this.padPlayingFillOpacity,
    required this.padPlayingFlashOpacity,
    required this.padPlayingGlow,
    required this.padPendingOpacityMin,
    required this.padDisabledOpacity,
    required this.padSelectedBorder,
    required this.padSelectedBorderWidth,
    required this.padLoopIdleFill,
    required this.padLoopIdleFillOpacity,
    required this.padLoopBorderWidth,
    required this.padLoopIcon,
    required this.padLoopIconOpacity,
    required this.padEmptyFill,
    required this.padEmptyBorder,
    required this.padEmptyOpacity,
    required this.padTutorialDimOpacity,
    required this.padTutorialHighlight,
    required this.padTutorialFill,
    required this.padTutorialOutline,
    required this.padTutorialLoopIcon,
    required this.surfaceApp,
    required this.surfacePads,
    required this.surfacePage,
    required this.surfaceRaised,
    required this.surfaceRaisedHigh,
    required this.surfaceSunken,
    required this.surfaceToolbar,
    required this.surfaceBankButton,
    required this.surfacePadContainer,
    required this.surfaceScrim,
    required this.surfaceDim,
    required this.surfaceOverlayDownload,
    required this.surfaceScrimStrong,
    required this.surfaceKitEditor,
    required this.surfaceSocial,
    required this.surfaceTabBar,
    required this.surfaceNavShadow,
    required this.borderSubtle,
    required this.borderDefault,
    required this.borderStrong,
    required this.borderDivider,
    required this.borderInverse,
    required this.borderDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textFaint,
    required this.textDisabled,
    required this.textInverse,
    required this.textOnAccent,
    required this.textLink,
    required this.textSection,
    required this.textDark,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.iconDisabled,
    required this.iconOnAccent,
    required this.accentPrimary,
    required this.accentPrimaryPressed,
    required this.accentPrimaryMuted,
    required this.accentSelected,
    required this.accentSecondary,
    required this.accentPreview,
    required this.accentAlert,
    required this.accentCreate,
    required this.statusSuccess,
    required this.statusWarning,
    required this.statusDanger,
    required this.statusInfo,
    required this.statusRecording,
    required this.brandBackground,
    required this.focusRing,
    required this.focusRingWidth,
    required this.feedbackPerfect,
    required this.feedbackWrong,
    required this.feedbackBubble,
    required this.feedbackBubbleText,
  });

  /// Token: `transport.background`
  final Color transportBackground;

  /// Token: `transport.stopBackground`
  final Color transportStopBackground;

  /// Token: `transport.stopIcon`
  final Color transportStopIcon;

  /// Token: `transport.waveformPlayed`
  final Color transportWaveformPlayed;

  /// Token: `transport.waveformUnplayed`
  final Color transportWaveformUnplayed;

  /// Token: `transport.progressTrack`
  final Color transportProgressTrack;

  /// IPA progress bar
  ///
  /// Token: `transport.progressFill`
  final Color transportProgressFill;

  /// IPA slider grip
  ///
  /// Token: `transport.thumb`
  final Color transportThumb;

  /// Token: `transport.speedBackground`
  final Color transportSpeedBackground;

  /// IPA speed digits #282828
  ///
  /// Token: `transport.speedText`
  final Color transportSpeedText;

  /// IPA tutorial button block
  ///
  /// Token: `chip.background`
  final Color chipBackground;

  /// Token: `chip.foreground`
  final Color chipForeground;

  /// Token: `chip.iconBox`
  final Color chipIconBox;

  /// IPA SONGS button
  ///
  /// Token: `chip.selectedBackground`
  final Color chipSelectedBackground;

  /// Token: `chip.selectedForeground`
  final Color chipSelectedForeground;

  /// SHOT darker icon box
  ///
  /// Token: `chip.selectedIconBox`
  final Color chipSelectedIconBox;

  /// APK A/B tutorial hint inverts to white
  ///
  /// Token: `chip.hintBackground`
  final Color chipHintBackground;

  /// Token: `chip.hintForeground`
  final Color chipHintForeground;

  /// IPA kit row
  ///
  /// Token: `card.background`
  final Color cardBackground;

  /// IPA kit row pressed
  ///
  /// Token: `card.backgroundSelected`
  final Color cardBackgroundSelected;

  /// Token: `card.border`
  final Color cardBorder;

  /// Token: `card.title`
  final Color cardTitle;

  /// IPA INSPIRED BY
  ///
  /// Token: `card.subtitle`
  final Color cardSubtitle;

  /// Token: `card.overline`
  final Color cardOverline;

  /// IPA kit row selection bar
  ///
  /// Token: `card.selectedIndicator`
  final Color cardSelectedIndicator;

  /// IPA featured placeholder
  ///
  /// Token: `card.placeholder`
  final Color cardPlaceholder;

  /// IPA download counter
  ///
  /// Token: `card.counter`
  final Color cardCounter;

  /// Token: `banner.scrim`
  final UpGradient bannerScrim;

  /// IPA pagination dot
  ///
  /// Token: `banner.indicator`
  final Color bannerIndicator;

  /// Token: `banner.indicatorActive`
  final Color bannerIndicatorActive;

  /// IPA skin panel
  ///
  /// Token: `sheet.background`
  final Color sheetBackground;

  /// Token: `sheet.header`
  final Color sheetHeader;

  /// Token: `sheet.handle`
  final Color sheetHandle;

  /// Token: `sheet.item`
  final Color sheetItem;

  /// Token: `sheet.itemPressed`
  final Color sheetItemPressed;

  /// Token: `sheet.itemIconBox`
  final Color sheetItemIconBox;

  /// IPA skin panel title divider #F73873
  ///
  /// Token: `sheet.underline`
  final Color sheetUnderline;

  /// Token: `list.item`
  final Color listItem;

  /// Token: `list.itemPressed`
  final Color listItemPressed;

  /// Token: `list.separator`
  final Color listSeparator;

  /// IPA notification dot
  ///
  /// Token: `badge.background`
  final Color badgeBackground;

  /// Token: `badge.foreground`
  final Color badgeForeground;

  /// Token: `badge.new`
  final Color badgeNew;

  /// Token: `badge.top`
  final Color badgeTop;

  /// Token: `badge.topForeground`
  final Color badgeTopForeground;

  /// Token: `button.primaryBackground`
  final Color buttonPrimaryBackground;

  /// Token: `button.primaryForeground`
  final Color buttonPrimaryForeground;

  /// Token: `button.primaryPressed`
  final Color buttonPrimaryPressed;

  /// IPA unlock / action sheet button
  ///
  /// Token: `button.secondaryBackground`
  final Color buttonSecondaryBackground;

  /// Token: `button.secondaryForeground`
  final Color buttonSecondaryForeground;

  /// Token: `button.outlineBorder`
  final Color buttonOutlineBorder;

  /// Token: `button.ghostForeground`
  final Color buttonGhostForeground;

  /// Token: `button.dangerBackground`
  final Color buttonDangerBackground;

  /// Token: `button.disabledBackground`
  final Color buttonDisabledBackground;

  /// Token: `button.disabledForeground`
  final Color buttonDisabledForeground;

  /// IPA NO / CANCEL outline
  ///
  /// Token: `button.alertBorder`
  final Color buttonAlertBorder;

  /// IPA SAVE bar / pill buttons
  ///
  /// Token: `button.whiteBackground`
  final Color buttonWhiteBackground;

  /// IPA SAVE text #F73873
  ///
  /// Token: `button.whiteForeground`
  final Color buttonWhiteForeground;

  /// Token: `input.background`
  final Color inputBackground;

  /// Token: `input.foreground`
  final Color inputForeground;

  /// Token: `input.placeholder`
  final Color inputPlaceholder;

  /// Token: `input.cursor`
  final Color inputCursor;

  /// IPA search field outline α0.5
  ///
  /// Token: `input.border`
  final Color inputBorder;

  /// IPA label/underline focus #F73873
  ///
  /// Token: `input.focus`
  final Color inputFocus;

  /// Token: `slider.track`
  final Color sliderTrack;

  /// Token: `slider.fill`
  final Color sliderFill;

  /// IPA grip
  ///
  /// Token: `slider.thumb`
  final Color sliderThumb;

  /// IPA kit preview modal
  ///
  /// Token: `dialog.background`
  final Color dialogBackground;

  /// IPA kit preview overlay
  ///
  /// Token: `dialog.scrim`
  final Color dialogScrim;

  /// IPA rate dialog
  ///
  /// Token: `dialog.light`
  final Color dialogLight;

  /// Token: `dialog.lightTitle`
  final Color dialogLightTitle;

  /// Token: `dialog.lightText`
  final Color dialogLightText;

  /// Token: `toast.background`
  final Color toastBackground;

  /// Token: `toast.foreground`
  final Color toastForeground;

  /// Token: `meter.track`
  final Color meterTrack;

  /// Token: `meter.low`
  final Color meterLow;

  /// Token: `meter.mid`
  final Color meterMid;

  /// Token: `meter.high`
  final Color meterHigh;

  /// Token: `meter.peak`
  final Color meterPeak;

  /// Token: `waveform.active`
  final Color waveformActive;

  /// Token: `waveform.inactive`
  final Color waveformInactive;

  /// IPA area outside trim selection
  ///
  /// Token: `waveform.selection`
  final Color waveformSelection;

  /// Token: `waveform.marker`
  final Color waveformMarker;

  /// Token: `progressRing.track`
  final Color progressRingTrack;

  /// Token: `progressRing.fill`
  final Color progressRingFill;

  /// Token: `record.indicator`
  final Color recordIndicator;

  /// Token: `record.trackCard`
  final Color recordTrackCard;

  /// Token: `genre.label`
  final Color genreLabel;

  /// Token: `genre.ring`
  final Color genreRing;

  /// IPA genre check
  ///
  /// Token: `genre.check`
  final Color genreCheck;

  /// IPA tab selected circle
  ///
  /// Token: `genre.tabSelected`
  final Color genreTabSelected;

  /// Token: `swatch.ring`
  final Color swatchRing;

  /// Token: `hub.online`
  final Color hubOnline;

  /// Token: `hub.pairing`
  final Color hubPairing;

  /// Token: `hub.offline`
  final Color hubOffline;

  /// Token: `pad.palette.0.core`
  final Color padPalette0Core;

  /// Token: `pad.palette.0.mid`
  final Color padPalette0Mid;

  /// Token: `pad.palette.0.edge`
  final Color padPalette0Edge;

  /// Token: `pad.palette.0.glow`
  final Color padPalette0Glow;

  /// Token: `pad.palette.0.pressed`
  final Color padPalette0Pressed;

  /// Token: `pad.palette.1.core`
  final Color padPalette1Core;

  /// Token: `pad.palette.1.mid`
  final Color padPalette1Mid;

  /// Token: `pad.palette.1.edge`
  final Color padPalette1Edge;

  /// Token: `pad.palette.1.glow`
  final Color padPalette1Glow;

  /// Token: `pad.palette.1.pressed`
  final Color padPalette1Pressed;

  /// Token: `pad.palette.2.core`
  final Color padPalette2Core;

  /// Token: `pad.palette.2.mid`
  final Color padPalette2Mid;

  /// Token: `pad.palette.2.edge`
  final Color padPalette2Edge;

  /// Token: `pad.palette.2.glow`
  final Color padPalette2Glow;

  /// Token: `pad.palette.2.pressed`
  final Color padPalette2Pressed;

  /// Token: `pad.palette.3.core`
  final Color padPalette3Core;

  /// Token: `pad.palette.3.mid`
  final Color padPalette3Mid;

  /// Token: `pad.palette.3.edge`
  final Color padPalette3Edge;

  /// Token: `pad.palette.3.glow`
  final Color padPalette3Glow;

  /// Token: `pad.palette.3.pressed`
  final Color padPalette3Pressed;

  /// Token: `pad.palette.4.core`
  final Color padPalette4Core;

  /// Token: `pad.palette.4.mid`
  final Color padPalette4Mid;

  /// Token: `pad.palette.4.edge`
  final Color padPalette4Edge;

  /// Token: `pad.palette.4.glow`
  final Color padPalette4Glow;

  /// Token: `pad.palette.4.pressed`
  final Color padPalette4Pressed;

  /// Token: `pad.palette.5.core`
  final Color padPalette5Core;

  /// Token: `pad.palette.5.mid`
  final Color padPalette5Mid;

  /// Token: `pad.palette.5.edge`
  final Color padPalette5Edge;

  /// Token: `pad.palette.5.glow`
  final Color padPalette5Glow;

  /// Token: `pad.palette.5.pressed`
  final Color padPalette5Pressed;

  /// Token: `pad.palette.6.core`
  final Color padPalette6Core;

  /// Token: `pad.palette.6.mid`
  final Color padPalette6Mid;

  /// Token: `pad.palette.6.edge`
  final Color padPalette6Edge;

  /// Token: `pad.palette.6.glow`
  final Color padPalette6Glow;

  /// Token: `pad.palette.6.pressed`
  final Color padPalette6Pressed;

  /// Token: `pad.palette.7.core`
  final Color padPalette7Core;

  /// Token: `pad.palette.7.mid`
  final Color padPalette7Mid;

  /// Token: `pad.palette.7.edge`
  final Color padPalette7Edge;

  /// Token: `pad.palette.7.glow`
  final Color padPalette7Glow;

  /// Token: `pad.palette.7.pressed`
  final Color padPalette7Pressed;

  /// Corner radius = pad short side * ratio (IPA ~10%; Circle skin 0.5)
  ///
  /// Token: `pad.shape.radiusRatio`
  final double padShapeRadiusRatio;

  /// Token: `pad.fill.radial`
  final double padFillRadial;

  /// 1 = draw the pad number (IPA Number skin)
  ///
  /// Token: `pad.showNumber`
  final double padShowNumber;

  /// Default flash colour (IPA white overlay). Per-role colour: pad.palette.<i>.pressed.
  ///
  /// Token: `pad.flash`
  final Color padFlash;

  /// Token: `pad.border`
  final Color padBorder;

  /// Token: `pad.label`
  final Color padLabel;

  /// Token: `pad.idle.fillOpacity`
  final double padIdleFillOpacity;

  /// Token: `pad.idle.borderWidth`
  final double padIdleBorderWidth;

  /// Token: `pad.idle.glow`
  final double padIdleGlow;

  /// Strength of the hard bottom bevel shadow (SHOT)
  ///
  /// Token: `pad.idle.bevel`
  final double padIdleBevel;

  /// Token: `pad.pressed.fillOpacity`
  final double padPressedFillOpacity;

  /// Peak alpha of the palette 'pressed' layer (IPA white overlay 0.8; tint-swap skins use 1)
  ///
  /// Token: `pad.pressed.flashOpacity`
  final double padPressedFlashOpacity;

  /// Token: `pad.pressed.glow`
  final double padPressedGlow;

  /// IPA Default does not scale; Circle / Square skins 0.9
  ///
  /// Token: `pad.pressed.scale`
  final double padPressedScale;

  /// Token: `pad.playing.fillOpacity`
  final double padPlayingFillOpacity;

  /// IPA loop flash peak (yoyo 0 <-> 0.8)
  ///
  /// Token: `pad.playing.flashOpacity`
  final double padPlayingFlashOpacity;

  /// Token: `pad.playing.glow`
  final double padPlayingGlow;

  /// UP: blink floor while a loop waits for its quantised start
  ///
  /// Token: `pad.pending.opacityMin`
  final double padPendingOpacityMin;

  /// Token: `pad.disabled.opacity`
  final double padDisabledOpacity;

  /// Token: `pad.selected.border`
  final Color padSelectedBorder;

  /// Token: `pad.selected.borderWidth`
  final double padSelectedBorderWidth;

  /// SHOT idle loop pad body (used when idle.fillOpacity < 1)
  ///
  /// Token: `pad.loop.idleFill`
  final Color padLoopIdleFill;

  /// Token: `pad.loop.idleFillOpacity`
  final double padLoopIdleFillOpacity;

  /// Token: `pad.loop.borderWidth`
  final double padLoopBorderWidth;

  /// IPA loop glyph (white, α ~0.58 in Default bitmap)
  ///
  /// Token: `pad.loop.icon`
  final Color padLoopIcon;

  /// Token: `pad.loop.iconOpacity`
  final double padLoopIconOpacity;

  /// Token: `pad.empty.fill`
  final UpGradient padEmptyFill;

  /// IPA dashed rounded frame
  ///
  /// Token: `pad.empty.border`
  final Color padEmptyBorder;

  /// IPA empty pad frame alpha 0.2
  ///
  /// Token: `pad.empty.opacity`
  final double padEmptyOpacity;

  /// APK non-target pad alpha
  ///
  /// Token: `pad.tutorial.dimOpacity`
  final double padTutorialDimOpacity;

  /// Token: `pad.tutorial.highlight`
  final Color padTutorialHighlight;

  /// IPA tutorial pad fill (fills bottom->top in 1 s)
  ///
  /// Token: `pad.tutorial.fill`
  final Color padTutorialFill;

  /// Token: `pad.tutorial.outline`
  final Color padTutorialOutline;

  /// Token: `pad.tutorial.loopIcon`
  final Color padTutorialLoopIcon;

  /// IPA nav bars / window
  ///
  /// Token: `surface.app`
  final Color surfaceApp;

  /// IPA perform page
  ///
  /// Token: `surface.pads`
  final Color surfacePads;

  /// IPA library / search / save-kit pages
  ///
  /// Token: `surface.page`
  final Color surfacePage;

  /// IPA list rows
  ///
  /// Token: `surface.raised`
  final Color surfaceRaised;

  /// IPA secondary modal button / action sheet
  ///
  /// Token: `surface.raisedHigh`
  final Color surfaceRaisedHigh;

  /// IPA placeholders / wells
  ///
  /// Token: `surface.sunken`
  final Color surfaceSunken;

  /// IPA function button row
  ///
  /// Token: `surface.toolbar`
  final Color surfaceToolbar;

  /// IPA A/B button
  ///
  /// Token: `surface.bankButton`
  final Color surfaceBankButton;

  /// Token: `surface.padContainer`
  final Color surfacePadContainer;

  /// IPA tutorial / full-page overlay 70%
  ///
  /// Token: `surface.scrim`
  final Color surfaceScrim;

  /// IPA info overlay 50%
  ///
  /// Token: `surface.dim`
  final Color surfaceDim;

  /// Token: `surface.overlayDownload`
  final Color surfaceOverlayDownload;

  /// IPA kit preview overlay 80%
  ///
  /// Token: `surface.scrimStrong`
  final Color surfaceScrimStrong;

  /// IPA kit editor page background
  ///
  /// Token: `surface.kitEditor`
  final Color surfaceKitEditor;

  /// IPA social bar
  ///
  /// Token: `surface.social`
  final Color surfaceSocial;

  /// IPA tab bar
  ///
  /// Token: `surface.tabBar`
  final Color surfaceTabBar;

  /// IPA nav bar shadow
  ///
  /// Token: `surface.navShadow`
  final Color surfaceNavShadow;

  /// IPA dividers (white 10%)
  ///
  /// Token: `border.subtle`
  final Color borderSubtle;

  /// Token: `border.default`
  final Color borderDefault;

  /// Token: `border.strong`
  final Color borderStrong;

  /// IPA tab bar top line / list separators
  ///
  /// Token: `border.divider`
  final Color borderDivider;

  /// Token: `border.inverse`
  final Color borderInverse;

  /// IPA kit editor separator
  ///
  /// Token: `border.dark`
  final Color borderDark;

  /// Token: `text.primary`
  final Color textPrimary;

  /// IPA INSPIRED BY α0.6
  ///
  /// Token: `text.secondary`
  final Color textSecondary;

  /// IPA section titles
  ///
  /// Token: `text.muted`
  final Color textMuted;

  /// Token: `text.faint`
  final Color textFaint;

  /// Token: `text.disabled`
  final Color textDisabled;

  /// Token: `text.inverse`
  final Color textInverse;

  /// Token: `text.onAccent`
  final Color textOnAccent;

  /// Token: `text.link`
  final Color textLink;

  /// IPA library section titles
  ///
  /// Token: `text.section`
  final Color textSection;

  /// IPA dark text on white buttons
  ///
  /// Token: `text.dark`
  final Color textDark;

  /// Token: `icon.primary`
  final Color iconPrimary;

  /// Token: `icon.secondary`
  final Color iconSecondary;

  /// Token: `icon.disabled`
  final Color iconDisabled;

  /// Token: `icon.onAccent`
  final Color iconOnAccent;

  /// IPA #FD1A68 main accent
  ///
  /// Token: `accent.primary`
  final Color accentPrimary;

  /// Token: `accent.primaryPressed`
  final Color accentPrimaryPressed;

  /// Token: `accent.primaryMuted`
  final Color accentPrimaryMuted;

  /// IPA genre check / skin price
  ///
  /// Token: `accent.selected`
  final Color accentSelected;

  /// IPA divider under skin panel title, SAVE text, input focus
  ///
  /// Token: `accent.secondary`
  final Color accentSecondary;

  /// Token: `accent.preview`
  final Color accentPreview;

  /// IPA NO / CANCEL outline
  ///
  /// Token: `accent.alert`
  final Color accentAlert;

  /// IPA kit editor accent
  ///
  /// Token: `accent.create`
  final Color accentCreate;

  /// IPA PERFECT feedback
  ///
  /// Token: `status.success`
  final Color statusSuccess;

  /// Token: `status.warning`
  final Color statusWarning;

  /// IPA wrong-pad cross
  ///
  /// Token: `status.danger`
  final Color statusDanger;

  /// Token: `status.info`
  final Color statusInfo;

  /// IPA record button / timer
  ///
  /// Token: `status.recording`
  final Color statusRecording;

  /// Token: `brand.background`
  final UpGradient brandBackground;

  /// Token: `focus.ring`
  final Color focusRing;

  /// Token: `focus.ringWidth`
  final double focusRingWidth;

  /// IPA PERFECT circle
  ///
  /// Token: `feedback.perfect`
  final Color feedbackPerfect;

  /// IPA wrong cross
  ///
  /// Token: `feedback.wrong`
  final Color feedbackWrong;

  /// IPA first-open bubble
  ///
  /// Token: `feedback.bubble`
  final Color feedbackBubble;

  /// Token: `feedback.bubbleText`
  final Color feedbackBubbleText;

  /// Number of pad colour roles. Kit pad colours are role indices (wrap around).
  static const int padPaletteLength = 8;

  /// Colour role for a pad colour index (wraps modulo [padPaletteLength]).
  UpPadRole padRole(int index) {
    switch (index % padPaletteLength) {
      case 0:
        return UpPadRole(
          index: 0,
          core: padPalette0Core,
          mid: padPalette0Mid,
          edge: padPalette0Edge,
          glow: padPalette0Glow,
          pressed: padPalette0Pressed,
        );
      case 1:
        return UpPadRole(
          index: 1,
          core: padPalette1Core,
          mid: padPalette1Mid,
          edge: padPalette1Edge,
          glow: padPalette1Glow,
          pressed: padPalette1Pressed,
        );
      case 2:
        return UpPadRole(
          index: 2,
          core: padPalette2Core,
          mid: padPalette2Mid,
          edge: padPalette2Edge,
          glow: padPalette2Glow,
          pressed: padPalette2Pressed,
        );
      case 3:
        return UpPadRole(
          index: 3,
          core: padPalette3Core,
          mid: padPalette3Mid,
          edge: padPalette3Edge,
          glow: padPalette3Glow,
          pressed: padPalette3Pressed,
        );
      case 4:
        return UpPadRole(
          index: 4,
          core: padPalette4Core,
          mid: padPalette4Mid,
          edge: padPalette4Edge,
          glow: padPalette4Glow,
          pressed: padPalette4Pressed,
        );
      case 5:
        return UpPadRole(
          index: 5,
          core: padPalette5Core,
          mid: padPalette5Mid,
          edge: padPalette5Edge,
          glow: padPalette5Glow,
          pressed: padPalette5Pressed,
        );
      case 6:
        return UpPadRole(
          index: 6,
          core: padPalette6Core,
          mid: padPalette6Mid,
          edge: padPalette6Edge,
          glow: padPalette6Glow,
          pressed: padPalette6Pressed,
        );
      case 7:
        return UpPadRole(
          index: 7,
          core: padPalette7Core,
          mid: padPalette7Mid,
          edge: padPalette7Edge,
          glow: padPalette7Glow,
          pressed: padPalette7Pressed,
        );
      default:
        throw StateError('unreachable');
    }
  }

  /// All pad roles in order.
  List<UpPadRole> get padPalette =>
      List<UpPadRole>.generate(padPaletteLength, padRole, growable: false);

  /// Token metadata in declaration order.
  static const List<UpSemanticTokenInfo> tokens = <UpSemanticTokenInfo>[
    UpSemanticTokenInfo('transport.background', UpSemanticType.color, null),
    UpSemanticTokenInfo('transport.stopBackground', UpSemanticType.color, null),
    UpSemanticTokenInfo('transport.stopIcon', UpSemanticType.color, null),
    UpSemanticTokenInfo('transport.waveformPlayed', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'transport.waveformUnplayed',
      UpSemanticType.color,
      null,
    ),
    UpSemanticTokenInfo('transport.progressTrack', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'transport.progressFill',
      UpSemanticType.color,
      'IPA progress bar',
    ),
    UpSemanticTokenInfo(
      'transport.thumb',
      UpSemanticType.color,
      'IPA slider grip',
    ),
    UpSemanticTokenInfo(
      'transport.speedBackground',
      UpSemanticType.color,
      null,
    ),
    UpSemanticTokenInfo(
      'transport.speedText',
      UpSemanticType.color,
      'IPA speed digits #282828',
    ),
    UpSemanticTokenInfo(
      'chip.background',
      UpSemanticType.color,
      'IPA tutorial button block',
    ),
    UpSemanticTokenInfo('chip.foreground', UpSemanticType.color, null),
    UpSemanticTokenInfo('chip.iconBox', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'chip.selectedBackground',
      UpSemanticType.color,
      'IPA SONGS button',
    ),
    UpSemanticTokenInfo('chip.selectedForeground', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'chip.selectedIconBox',
      UpSemanticType.color,
      'SHOT darker icon box',
    ),
    UpSemanticTokenInfo(
      'chip.hintBackground',
      UpSemanticType.color,
      'APK A/B tutorial hint inverts to white',
    ),
    UpSemanticTokenInfo('chip.hintForeground', UpSemanticType.color, null),
    UpSemanticTokenInfo('card.background', UpSemanticType.color, 'IPA kit row'),
    UpSemanticTokenInfo(
      'card.backgroundSelected',
      UpSemanticType.color,
      'IPA kit row pressed',
    ),
    UpSemanticTokenInfo('card.border', UpSemanticType.color, null),
    UpSemanticTokenInfo('card.title', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'card.subtitle',
      UpSemanticType.color,
      'IPA INSPIRED BY',
    ),
    UpSemanticTokenInfo('card.overline', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'card.selectedIndicator',
      UpSemanticType.color,
      'IPA kit row selection bar',
    ),
    UpSemanticTokenInfo(
      'card.placeholder',
      UpSemanticType.color,
      'IPA featured placeholder',
    ),
    UpSemanticTokenInfo(
      'card.counter',
      UpSemanticType.color,
      'IPA download counter',
    ),
    UpSemanticTokenInfo('banner.scrim', UpSemanticType.gradient, null),
    UpSemanticTokenInfo(
      'banner.indicator',
      UpSemanticType.color,
      'IPA pagination dot',
    ),
    UpSemanticTokenInfo('banner.indicatorActive', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'sheet.background',
      UpSemanticType.color,
      'IPA skin panel',
    ),
    UpSemanticTokenInfo('sheet.header', UpSemanticType.color, null),
    UpSemanticTokenInfo('sheet.handle', UpSemanticType.color, null),
    UpSemanticTokenInfo('sheet.item', UpSemanticType.color, null),
    UpSemanticTokenInfo('sheet.itemPressed', UpSemanticType.color, null),
    UpSemanticTokenInfo('sheet.itemIconBox', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'sheet.underline',
      UpSemanticType.color,
      'IPA skin panel title divider #F73873',
    ),
    UpSemanticTokenInfo('list.item', UpSemanticType.color, null),
    UpSemanticTokenInfo('list.itemPressed', UpSemanticType.color, null),
    UpSemanticTokenInfo('list.separator', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'badge.background',
      UpSemanticType.color,
      'IPA notification dot',
    ),
    UpSemanticTokenInfo('badge.foreground', UpSemanticType.color, null),
    UpSemanticTokenInfo('badge.new', UpSemanticType.color, null),
    UpSemanticTokenInfo('badge.top', UpSemanticType.color, null),
    UpSemanticTokenInfo('badge.topForeground', UpSemanticType.color, null),
    UpSemanticTokenInfo('button.primaryBackground', UpSemanticType.color, null),
    UpSemanticTokenInfo('button.primaryForeground', UpSemanticType.color, null),
    UpSemanticTokenInfo('button.primaryPressed', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'button.secondaryBackground',
      UpSemanticType.color,
      'IPA unlock / action sheet button',
    ),
    UpSemanticTokenInfo(
      'button.secondaryForeground',
      UpSemanticType.color,
      null,
    ),
    UpSemanticTokenInfo('button.outlineBorder', UpSemanticType.color, null),
    UpSemanticTokenInfo('button.ghostForeground', UpSemanticType.color, null),
    UpSemanticTokenInfo('button.dangerBackground', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'button.disabledBackground',
      UpSemanticType.color,
      null,
    ),
    UpSemanticTokenInfo(
      'button.disabledForeground',
      UpSemanticType.color,
      null,
    ),
    UpSemanticTokenInfo(
      'button.alertBorder',
      UpSemanticType.color,
      'IPA NO / CANCEL outline',
    ),
    UpSemanticTokenInfo(
      'button.whiteBackground',
      UpSemanticType.color,
      'IPA SAVE bar / pill buttons',
    ),
    UpSemanticTokenInfo(
      'button.whiteForeground',
      UpSemanticType.color,
      'IPA SAVE text #F73873',
    ),
    UpSemanticTokenInfo('input.background', UpSemanticType.color, null),
    UpSemanticTokenInfo('input.foreground', UpSemanticType.color, null),
    UpSemanticTokenInfo('input.placeholder', UpSemanticType.color, null),
    UpSemanticTokenInfo('input.cursor', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'input.border',
      UpSemanticType.color,
      'IPA search field outline α0.5',
    ),
    UpSemanticTokenInfo(
      'input.focus',
      UpSemanticType.color,
      'IPA label/underline focus #F73873',
    ),
    UpSemanticTokenInfo('slider.track', UpSemanticType.color, null),
    UpSemanticTokenInfo('slider.fill', UpSemanticType.color, null),
    UpSemanticTokenInfo('slider.thumb', UpSemanticType.color, 'IPA grip'),
    UpSemanticTokenInfo(
      'dialog.background',
      UpSemanticType.color,
      'IPA kit preview modal',
    ),
    UpSemanticTokenInfo(
      'dialog.scrim',
      UpSemanticType.color,
      'IPA kit preview overlay',
    ),
    UpSemanticTokenInfo(
      'dialog.light',
      UpSemanticType.color,
      'IPA rate dialog',
    ),
    UpSemanticTokenInfo('dialog.lightTitle', UpSemanticType.color, null),
    UpSemanticTokenInfo('dialog.lightText', UpSemanticType.color, null),
    UpSemanticTokenInfo('toast.background', UpSemanticType.color, null),
    UpSemanticTokenInfo('toast.foreground', UpSemanticType.color, null),
    UpSemanticTokenInfo('meter.track', UpSemanticType.color, null),
    UpSemanticTokenInfo('meter.low', UpSemanticType.color, null),
    UpSemanticTokenInfo('meter.mid', UpSemanticType.color, null),
    UpSemanticTokenInfo('meter.high', UpSemanticType.color, null),
    UpSemanticTokenInfo('meter.peak', UpSemanticType.color, null),
    UpSemanticTokenInfo('waveform.active', UpSemanticType.color, null),
    UpSemanticTokenInfo('waveform.inactive', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'waveform.selection',
      UpSemanticType.color,
      'IPA area outside trim selection',
    ),
    UpSemanticTokenInfo('waveform.marker', UpSemanticType.color, null),
    UpSemanticTokenInfo('progressRing.track', UpSemanticType.color, null),
    UpSemanticTokenInfo('progressRing.fill', UpSemanticType.color, null),
    UpSemanticTokenInfo('record.indicator', UpSemanticType.color, null),
    UpSemanticTokenInfo('record.trackCard', UpSemanticType.color, null),
    UpSemanticTokenInfo('genre.label', UpSemanticType.color, null),
    UpSemanticTokenInfo('genre.ring', UpSemanticType.color, null),
    UpSemanticTokenInfo('genre.check', UpSemanticType.color, 'IPA genre check'),
    UpSemanticTokenInfo(
      'genre.tabSelected',
      UpSemanticType.color,
      'IPA tab selected circle',
    ),
    UpSemanticTokenInfo('swatch.ring', UpSemanticType.color, null),
    UpSemanticTokenInfo('hub.online', UpSemanticType.color, null),
    UpSemanticTokenInfo('hub.pairing', UpSemanticType.color, null),
    UpSemanticTokenInfo('hub.offline', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.0.core', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.0.mid', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.0.edge', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.0.glow', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.0.pressed', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.1.core', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.1.mid', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.1.edge', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.1.glow', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.1.pressed', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.2.core', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.2.mid', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.2.edge', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.2.glow', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.2.pressed', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.3.core', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.3.mid', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.3.edge', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.3.glow', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.3.pressed', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.4.core', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.4.mid', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.4.edge', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.4.glow', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.4.pressed', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.5.core', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.5.mid', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.5.edge', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.5.glow', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.5.pressed', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.6.core', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.6.mid', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.6.edge', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.6.glow', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.6.pressed', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.7.core', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.7.mid', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.7.edge', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.7.glow', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.palette.7.pressed', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'pad.shape.radiusRatio',
      UpSemanticType.number,
      'Corner radius = pad short side * ratio (IPA ~10%; Circle skin 0.5)',
    ),
    UpSemanticTokenInfo('pad.fill.radial', UpSemanticType.number, null),
    UpSemanticTokenInfo(
      'pad.showNumber',
      UpSemanticType.number,
      '1 = draw the pad number (IPA Number skin)',
    ),
    UpSemanticTokenInfo(
      'pad.flash',
      UpSemanticType.color,
      'Default flash colour (IPA white overlay). Per-role colour: pad.palette.<i>.pressed.',
    ),
    UpSemanticTokenInfo('pad.border', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.label', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.idle.fillOpacity', UpSemanticType.number, null),
    UpSemanticTokenInfo('pad.idle.borderWidth', UpSemanticType.dimension, null),
    UpSemanticTokenInfo('pad.idle.glow', UpSemanticType.number, null),
    UpSemanticTokenInfo(
      'pad.idle.bevel',
      UpSemanticType.number,
      'Strength of the hard bottom bevel shadow (SHOT)',
    ),
    UpSemanticTokenInfo('pad.pressed.fillOpacity', UpSemanticType.number, null),
    UpSemanticTokenInfo(
      'pad.pressed.flashOpacity',
      UpSemanticType.number,
      'Peak alpha of the palette \'pressed\' layer (IPA white overlay 0.8; tint-swap skins use 1)',
    ),
    UpSemanticTokenInfo('pad.pressed.glow', UpSemanticType.number, null),
    UpSemanticTokenInfo(
      'pad.pressed.scale',
      UpSemanticType.number,
      'IPA Default does not scale; Circle / Square skins 0.9',
    ),
    UpSemanticTokenInfo('pad.playing.fillOpacity', UpSemanticType.number, null),
    UpSemanticTokenInfo(
      'pad.playing.flashOpacity',
      UpSemanticType.number,
      'IPA loop flash peak (yoyo 0 <-> 0.8)',
    ),
    UpSemanticTokenInfo('pad.playing.glow', UpSemanticType.number, null),
    UpSemanticTokenInfo(
      'pad.pending.opacityMin',
      UpSemanticType.number,
      'UP: blink floor while a loop waits for its quantised start',
    ),
    UpSemanticTokenInfo('pad.disabled.opacity', UpSemanticType.number, null),
    UpSemanticTokenInfo('pad.selected.border', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'pad.selected.borderWidth',
      UpSemanticType.dimension,
      null,
    ),
    UpSemanticTokenInfo(
      'pad.loop.idleFill',
      UpSemanticType.color,
      'SHOT idle loop pad body (used when idle.fillOpacity < 1)',
    ),
    UpSemanticTokenInfo(
      'pad.loop.idleFillOpacity',
      UpSemanticType.number,
      null,
    ),
    UpSemanticTokenInfo('pad.loop.borderWidth', UpSemanticType.dimension, null),
    UpSemanticTokenInfo(
      'pad.loop.icon',
      UpSemanticType.color,
      'IPA loop glyph (white, α ~0.58 in Default bitmap)',
    ),
    UpSemanticTokenInfo('pad.loop.iconOpacity', UpSemanticType.number, null),
    UpSemanticTokenInfo('pad.empty.fill', UpSemanticType.gradient, null),
    UpSemanticTokenInfo(
      'pad.empty.border',
      UpSemanticType.color,
      'IPA dashed rounded frame',
    ),
    UpSemanticTokenInfo(
      'pad.empty.opacity',
      UpSemanticType.number,
      'IPA empty pad frame alpha 0.2',
    ),
    UpSemanticTokenInfo(
      'pad.tutorial.dimOpacity',
      UpSemanticType.number,
      'APK non-target pad alpha',
    ),
    UpSemanticTokenInfo('pad.tutorial.highlight', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'pad.tutorial.fill',
      UpSemanticType.color,
      'IPA tutorial pad fill (fills bottom->top in 1 s)',
    ),
    UpSemanticTokenInfo('pad.tutorial.outline', UpSemanticType.color, null),
    UpSemanticTokenInfo('pad.tutorial.loopIcon', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'surface.app',
      UpSemanticType.color,
      'IPA nav bars / window',
    ),
    UpSemanticTokenInfo(
      'surface.pads',
      UpSemanticType.color,
      'IPA perform page',
    ),
    UpSemanticTokenInfo(
      'surface.page',
      UpSemanticType.color,
      'IPA library / search / save-kit pages',
    ),
    UpSemanticTokenInfo(
      'surface.raised',
      UpSemanticType.color,
      'IPA list rows',
    ),
    UpSemanticTokenInfo(
      'surface.raisedHigh',
      UpSemanticType.color,
      'IPA secondary modal button / action sheet',
    ),
    UpSemanticTokenInfo(
      'surface.sunken',
      UpSemanticType.color,
      'IPA placeholders / wells',
    ),
    UpSemanticTokenInfo(
      'surface.toolbar',
      UpSemanticType.color,
      'IPA function button row',
    ),
    UpSemanticTokenInfo(
      'surface.bankButton',
      UpSemanticType.color,
      'IPA A/B button',
    ),
    UpSemanticTokenInfo('surface.padContainer', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'surface.scrim',
      UpSemanticType.color,
      'IPA tutorial / full-page overlay 70%',
    ),
    UpSemanticTokenInfo(
      'surface.dim',
      UpSemanticType.color,
      'IPA info overlay 50%',
    ),
    UpSemanticTokenInfo('surface.overlayDownload', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'surface.scrimStrong',
      UpSemanticType.color,
      'IPA kit preview overlay 80%',
    ),
    UpSemanticTokenInfo(
      'surface.kitEditor',
      UpSemanticType.color,
      'IPA kit editor page background',
    ),
    UpSemanticTokenInfo(
      'surface.social',
      UpSemanticType.color,
      'IPA social bar',
    ),
    UpSemanticTokenInfo('surface.tabBar', UpSemanticType.color, 'IPA tab bar'),
    UpSemanticTokenInfo(
      'surface.navShadow',
      UpSemanticType.color,
      'IPA nav bar shadow',
    ),
    UpSemanticTokenInfo(
      'border.subtle',
      UpSemanticType.color,
      'IPA dividers (white 10%)',
    ),
    UpSemanticTokenInfo('border.default', UpSemanticType.color, null),
    UpSemanticTokenInfo('border.strong', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'border.divider',
      UpSemanticType.color,
      'IPA tab bar top line / list separators',
    ),
    UpSemanticTokenInfo('border.inverse', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'border.dark',
      UpSemanticType.color,
      'IPA kit editor separator',
    ),
    UpSemanticTokenInfo('text.primary', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'text.secondary',
      UpSemanticType.color,
      'IPA INSPIRED BY α0.6',
    ),
    UpSemanticTokenInfo(
      'text.muted',
      UpSemanticType.color,
      'IPA section titles',
    ),
    UpSemanticTokenInfo('text.faint', UpSemanticType.color, null),
    UpSemanticTokenInfo('text.disabled', UpSemanticType.color, null),
    UpSemanticTokenInfo('text.inverse', UpSemanticType.color, null),
    UpSemanticTokenInfo('text.onAccent', UpSemanticType.color, null),
    UpSemanticTokenInfo('text.link', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'text.section',
      UpSemanticType.color,
      'IPA library section titles',
    ),
    UpSemanticTokenInfo(
      'text.dark',
      UpSemanticType.color,
      'IPA dark text on white buttons',
    ),
    UpSemanticTokenInfo('icon.primary', UpSemanticType.color, null),
    UpSemanticTokenInfo('icon.secondary', UpSemanticType.color, null),
    UpSemanticTokenInfo('icon.disabled', UpSemanticType.color, null),
    UpSemanticTokenInfo('icon.onAccent', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'accent.primary',
      UpSemanticType.color,
      'IPA #FD1A68 main accent',
    ),
    UpSemanticTokenInfo('accent.primaryPressed', UpSemanticType.color, null),
    UpSemanticTokenInfo('accent.primaryMuted', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'accent.selected',
      UpSemanticType.color,
      'IPA genre check / skin price',
    ),
    UpSemanticTokenInfo(
      'accent.secondary',
      UpSemanticType.color,
      'IPA divider under skin panel title, SAVE text, input focus',
    ),
    UpSemanticTokenInfo('accent.preview', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'accent.alert',
      UpSemanticType.color,
      'IPA NO / CANCEL outline',
    ),
    UpSemanticTokenInfo(
      'accent.create',
      UpSemanticType.color,
      'IPA kit editor accent',
    ),
    UpSemanticTokenInfo(
      'status.success',
      UpSemanticType.color,
      'IPA PERFECT feedback',
    ),
    UpSemanticTokenInfo('status.warning', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'status.danger',
      UpSemanticType.color,
      'IPA wrong-pad cross',
    ),
    UpSemanticTokenInfo('status.info', UpSemanticType.color, null),
    UpSemanticTokenInfo(
      'status.recording',
      UpSemanticType.color,
      'IPA record button / timer',
    ),
    UpSemanticTokenInfo('brand.background', UpSemanticType.gradient, null),
    UpSemanticTokenInfo('focus.ring', UpSemanticType.color, null),
    UpSemanticTokenInfo('focus.ringWidth', UpSemanticType.dimension, null),
    UpSemanticTokenInfo(
      'feedback.perfect',
      UpSemanticType.color,
      'IPA PERFECT circle',
    ),
    UpSemanticTokenInfo(
      'feedback.wrong',
      UpSemanticType.color,
      'IPA wrong cross',
    ),
    UpSemanticTokenInfo(
      'feedback.bubble',
      UpSemanticType.color,
      'IPA first-open bubble',
    ),
    UpSemanticTokenInfo('feedback.bubbleText', UpSemanticType.color, null),
  ];

  /// Token metadata by key.
  static final Map<String, UpSemanticTokenInfo> tokenInfo =
      <String, UpSemanticTokenInfo>{
        for (final UpSemanticTokenInfo info in tokens) info.key: info,
      };

  /// Reads a token by its dotted key. Throws [ArgumentError] for unknown keys.
  Object valueOf(String key) {
    switch (key) {
      case 'transport.background':
        return transportBackground;
      case 'transport.stopBackground':
        return transportStopBackground;
      case 'transport.stopIcon':
        return transportStopIcon;
      case 'transport.waveformPlayed':
        return transportWaveformPlayed;
      case 'transport.waveformUnplayed':
        return transportWaveformUnplayed;
      case 'transport.progressTrack':
        return transportProgressTrack;
      case 'transport.progressFill':
        return transportProgressFill;
      case 'transport.thumb':
        return transportThumb;
      case 'transport.speedBackground':
        return transportSpeedBackground;
      case 'transport.speedText':
        return transportSpeedText;
      case 'chip.background':
        return chipBackground;
      case 'chip.foreground':
        return chipForeground;
      case 'chip.iconBox':
        return chipIconBox;
      case 'chip.selectedBackground':
        return chipSelectedBackground;
      case 'chip.selectedForeground':
        return chipSelectedForeground;
      case 'chip.selectedIconBox':
        return chipSelectedIconBox;
      case 'chip.hintBackground':
        return chipHintBackground;
      case 'chip.hintForeground':
        return chipHintForeground;
      case 'card.background':
        return cardBackground;
      case 'card.backgroundSelected':
        return cardBackgroundSelected;
      case 'card.border':
        return cardBorder;
      case 'card.title':
        return cardTitle;
      case 'card.subtitle':
        return cardSubtitle;
      case 'card.overline':
        return cardOverline;
      case 'card.selectedIndicator':
        return cardSelectedIndicator;
      case 'card.placeholder':
        return cardPlaceholder;
      case 'card.counter':
        return cardCounter;
      case 'banner.scrim':
        return bannerScrim;
      case 'banner.indicator':
        return bannerIndicator;
      case 'banner.indicatorActive':
        return bannerIndicatorActive;
      case 'sheet.background':
        return sheetBackground;
      case 'sheet.header':
        return sheetHeader;
      case 'sheet.handle':
        return sheetHandle;
      case 'sheet.item':
        return sheetItem;
      case 'sheet.itemPressed':
        return sheetItemPressed;
      case 'sheet.itemIconBox':
        return sheetItemIconBox;
      case 'sheet.underline':
        return sheetUnderline;
      case 'list.item':
        return listItem;
      case 'list.itemPressed':
        return listItemPressed;
      case 'list.separator':
        return listSeparator;
      case 'badge.background':
        return badgeBackground;
      case 'badge.foreground':
        return badgeForeground;
      case 'badge.new':
        return badgeNew;
      case 'badge.top':
        return badgeTop;
      case 'badge.topForeground':
        return badgeTopForeground;
      case 'button.primaryBackground':
        return buttonPrimaryBackground;
      case 'button.primaryForeground':
        return buttonPrimaryForeground;
      case 'button.primaryPressed':
        return buttonPrimaryPressed;
      case 'button.secondaryBackground':
        return buttonSecondaryBackground;
      case 'button.secondaryForeground':
        return buttonSecondaryForeground;
      case 'button.outlineBorder':
        return buttonOutlineBorder;
      case 'button.ghostForeground':
        return buttonGhostForeground;
      case 'button.dangerBackground':
        return buttonDangerBackground;
      case 'button.disabledBackground':
        return buttonDisabledBackground;
      case 'button.disabledForeground':
        return buttonDisabledForeground;
      case 'button.alertBorder':
        return buttonAlertBorder;
      case 'button.whiteBackground':
        return buttonWhiteBackground;
      case 'button.whiteForeground':
        return buttonWhiteForeground;
      case 'input.background':
        return inputBackground;
      case 'input.foreground':
        return inputForeground;
      case 'input.placeholder':
        return inputPlaceholder;
      case 'input.cursor':
        return inputCursor;
      case 'input.border':
        return inputBorder;
      case 'input.focus':
        return inputFocus;
      case 'slider.track':
        return sliderTrack;
      case 'slider.fill':
        return sliderFill;
      case 'slider.thumb':
        return sliderThumb;
      case 'dialog.background':
        return dialogBackground;
      case 'dialog.scrim':
        return dialogScrim;
      case 'dialog.light':
        return dialogLight;
      case 'dialog.lightTitle':
        return dialogLightTitle;
      case 'dialog.lightText':
        return dialogLightText;
      case 'toast.background':
        return toastBackground;
      case 'toast.foreground':
        return toastForeground;
      case 'meter.track':
        return meterTrack;
      case 'meter.low':
        return meterLow;
      case 'meter.mid':
        return meterMid;
      case 'meter.high':
        return meterHigh;
      case 'meter.peak':
        return meterPeak;
      case 'waveform.active':
        return waveformActive;
      case 'waveform.inactive':
        return waveformInactive;
      case 'waveform.selection':
        return waveformSelection;
      case 'waveform.marker':
        return waveformMarker;
      case 'progressRing.track':
        return progressRingTrack;
      case 'progressRing.fill':
        return progressRingFill;
      case 'record.indicator':
        return recordIndicator;
      case 'record.trackCard':
        return recordTrackCard;
      case 'genre.label':
        return genreLabel;
      case 'genre.ring':
        return genreRing;
      case 'genre.check':
        return genreCheck;
      case 'genre.tabSelected':
        return genreTabSelected;
      case 'swatch.ring':
        return swatchRing;
      case 'hub.online':
        return hubOnline;
      case 'hub.pairing':
        return hubPairing;
      case 'hub.offline':
        return hubOffline;
      case 'pad.palette.0.core':
        return padPalette0Core;
      case 'pad.palette.0.mid':
        return padPalette0Mid;
      case 'pad.palette.0.edge':
        return padPalette0Edge;
      case 'pad.palette.0.glow':
        return padPalette0Glow;
      case 'pad.palette.0.pressed':
        return padPalette0Pressed;
      case 'pad.palette.1.core':
        return padPalette1Core;
      case 'pad.palette.1.mid':
        return padPalette1Mid;
      case 'pad.palette.1.edge':
        return padPalette1Edge;
      case 'pad.palette.1.glow':
        return padPalette1Glow;
      case 'pad.palette.1.pressed':
        return padPalette1Pressed;
      case 'pad.palette.2.core':
        return padPalette2Core;
      case 'pad.palette.2.mid':
        return padPalette2Mid;
      case 'pad.palette.2.edge':
        return padPalette2Edge;
      case 'pad.palette.2.glow':
        return padPalette2Glow;
      case 'pad.palette.2.pressed':
        return padPalette2Pressed;
      case 'pad.palette.3.core':
        return padPalette3Core;
      case 'pad.palette.3.mid':
        return padPalette3Mid;
      case 'pad.palette.3.edge':
        return padPalette3Edge;
      case 'pad.palette.3.glow':
        return padPalette3Glow;
      case 'pad.palette.3.pressed':
        return padPalette3Pressed;
      case 'pad.palette.4.core':
        return padPalette4Core;
      case 'pad.palette.4.mid':
        return padPalette4Mid;
      case 'pad.palette.4.edge':
        return padPalette4Edge;
      case 'pad.palette.4.glow':
        return padPalette4Glow;
      case 'pad.palette.4.pressed':
        return padPalette4Pressed;
      case 'pad.palette.5.core':
        return padPalette5Core;
      case 'pad.palette.5.mid':
        return padPalette5Mid;
      case 'pad.palette.5.edge':
        return padPalette5Edge;
      case 'pad.palette.5.glow':
        return padPalette5Glow;
      case 'pad.palette.5.pressed':
        return padPalette5Pressed;
      case 'pad.palette.6.core':
        return padPalette6Core;
      case 'pad.palette.6.mid':
        return padPalette6Mid;
      case 'pad.palette.6.edge':
        return padPalette6Edge;
      case 'pad.palette.6.glow':
        return padPalette6Glow;
      case 'pad.palette.6.pressed':
        return padPalette6Pressed;
      case 'pad.palette.7.core':
        return padPalette7Core;
      case 'pad.palette.7.mid':
        return padPalette7Mid;
      case 'pad.palette.7.edge':
        return padPalette7Edge;
      case 'pad.palette.7.glow':
        return padPalette7Glow;
      case 'pad.palette.7.pressed':
        return padPalette7Pressed;
      case 'pad.shape.radiusRatio':
        return padShapeRadiusRatio;
      case 'pad.fill.radial':
        return padFillRadial;
      case 'pad.showNumber':
        return padShowNumber;
      case 'pad.flash':
        return padFlash;
      case 'pad.border':
        return padBorder;
      case 'pad.label':
        return padLabel;
      case 'pad.idle.fillOpacity':
        return padIdleFillOpacity;
      case 'pad.idle.borderWidth':
        return padIdleBorderWidth;
      case 'pad.idle.glow':
        return padIdleGlow;
      case 'pad.idle.bevel':
        return padIdleBevel;
      case 'pad.pressed.fillOpacity':
        return padPressedFillOpacity;
      case 'pad.pressed.flashOpacity':
        return padPressedFlashOpacity;
      case 'pad.pressed.glow':
        return padPressedGlow;
      case 'pad.pressed.scale':
        return padPressedScale;
      case 'pad.playing.fillOpacity':
        return padPlayingFillOpacity;
      case 'pad.playing.flashOpacity':
        return padPlayingFlashOpacity;
      case 'pad.playing.glow':
        return padPlayingGlow;
      case 'pad.pending.opacityMin':
        return padPendingOpacityMin;
      case 'pad.disabled.opacity':
        return padDisabledOpacity;
      case 'pad.selected.border':
        return padSelectedBorder;
      case 'pad.selected.borderWidth':
        return padSelectedBorderWidth;
      case 'pad.loop.idleFill':
        return padLoopIdleFill;
      case 'pad.loop.idleFillOpacity':
        return padLoopIdleFillOpacity;
      case 'pad.loop.borderWidth':
        return padLoopBorderWidth;
      case 'pad.loop.icon':
        return padLoopIcon;
      case 'pad.loop.iconOpacity':
        return padLoopIconOpacity;
      case 'pad.empty.fill':
        return padEmptyFill;
      case 'pad.empty.border':
        return padEmptyBorder;
      case 'pad.empty.opacity':
        return padEmptyOpacity;
      case 'pad.tutorial.dimOpacity':
        return padTutorialDimOpacity;
      case 'pad.tutorial.highlight':
        return padTutorialHighlight;
      case 'pad.tutorial.fill':
        return padTutorialFill;
      case 'pad.tutorial.outline':
        return padTutorialOutline;
      case 'pad.tutorial.loopIcon':
        return padTutorialLoopIcon;
      case 'surface.app':
        return surfaceApp;
      case 'surface.pads':
        return surfacePads;
      case 'surface.page':
        return surfacePage;
      case 'surface.raised':
        return surfaceRaised;
      case 'surface.raisedHigh':
        return surfaceRaisedHigh;
      case 'surface.sunken':
        return surfaceSunken;
      case 'surface.toolbar':
        return surfaceToolbar;
      case 'surface.bankButton':
        return surfaceBankButton;
      case 'surface.padContainer':
        return surfacePadContainer;
      case 'surface.scrim':
        return surfaceScrim;
      case 'surface.dim':
        return surfaceDim;
      case 'surface.overlayDownload':
        return surfaceOverlayDownload;
      case 'surface.scrimStrong':
        return surfaceScrimStrong;
      case 'surface.kitEditor':
        return surfaceKitEditor;
      case 'surface.social':
        return surfaceSocial;
      case 'surface.tabBar':
        return surfaceTabBar;
      case 'surface.navShadow':
        return surfaceNavShadow;
      case 'border.subtle':
        return borderSubtle;
      case 'border.default':
        return borderDefault;
      case 'border.strong':
        return borderStrong;
      case 'border.divider':
        return borderDivider;
      case 'border.inverse':
        return borderInverse;
      case 'border.dark':
        return borderDark;
      case 'text.primary':
        return textPrimary;
      case 'text.secondary':
        return textSecondary;
      case 'text.muted':
        return textMuted;
      case 'text.faint':
        return textFaint;
      case 'text.disabled':
        return textDisabled;
      case 'text.inverse':
        return textInverse;
      case 'text.onAccent':
        return textOnAccent;
      case 'text.link':
        return textLink;
      case 'text.section':
        return textSection;
      case 'text.dark':
        return textDark;
      case 'icon.primary':
        return iconPrimary;
      case 'icon.secondary':
        return iconSecondary;
      case 'icon.disabled':
        return iconDisabled;
      case 'icon.onAccent':
        return iconOnAccent;
      case 'accent.primary':
        return accentPrimary;
      case 'accent.primaryPressed':
        return accentPrimaryPressed;
      case 'accent.primaryMuted':
        return accentPrimaryMuted;
      case 'accent.selected':
        return accentSelected;
      case 'accent.secondary':
        return accentSecondary;
      case 'accent.preview':
        return accentPreview;
      case 'accent.alert':
        return accentAlert;
      case 'accent.create':
        return accentCreate;
      case 'status.success':
        return statusSuccess;
      case 'status.warning':
        return statusWarning;
      case 'status.danger':
        return statusDanger;
      case 'status.info':
        return statusInfo;
      case 'status.recording':
        return statusRecording;
      case 'brand.background':
        return brandBackground;
      case 'focus.ring':
        return focusRing;
      case 'focus.ringWidth':
        return focusRingWidth;
      case 'feedback.perfect':
        return feedbackPerfect;
      case 'feedback.wrong':
        return feedbackWrong;
      case 'feedback.bubble':
        return feedbackBubble;
      case 'feedback.bubbleText':
        return feedbackBubbleText;
      default:
        throw ArgumentError.value(key, 'key', 'Unknown semantic token');
    }
  }

  /// Returns a copy where the given keys are replaced. Values must already be
  /// typed (Color / UpGradient / num). Unknown keys or wrong types throw.
  UpSemantic withValues(Map<String, Object> values) {
    if (values.isEmpty) return this;
    for (final String key in values.keys) {
      if (!tokenInfo.containsKey(key)) {
        throw ArgumentError.value(key, 'values', 'Unknown semantic token');
      }
    }
    T pick<T>(String key, T current) {
      final Object? v = values[key];
      if (v == null) return current;
      if (T == double && v is num) return v.toDouble() as T;
      if (v is T) return v as T;
      throw ArgumentError.value(v, key, 'Expected $T');
    }

    return UpSemantic(
      transportBackground: pick<Color>(
        'transport.background',
        transportBackground,
      ),
      transportStopBackground: pick<Color>(
        'transport.stopBackground',
        transportStopBackground,
      ),
      transportStopIcon: pick<Color>('transport.stopIcon', transportStopIcon),
      transportWaveformPlayed: pick<Color>(
        'transport.waveformPlayed',
        transportWaveformPlayed,
      ),
      transportWaveformUnplayed: pick<Color>(
        'transport.waveformUnplayed',
        transportWaveformUnplayed,
      ),
      transportProgressTrack: pick<Color>(
        'transport.progressTrack',
        transportProgressTrack,
      ),
      transportProgressFill: pick<Color>(
        'transport.progressFill',
        transportProgressFill,
      ),
      transportThumb: pick<Color>('transport.thumb', transportThumb),
      transportSpeedBackground: pick<Color>(
        'transport.speedBackground',
        transportSpeedBackground,
      ),
      transportSpeedText: pick<Color>(
        'transport.speedText',
        transportSpeedText,
      ),
      chipBackground: pick<Color>('chip.background', chipBackground),
      chipForeground: pick<Color>('chip.foreground', chipForeground),
      chipIconBox: pick<Color>('chip.iconBox', chipIconBox),
      chipSelectedBackground: pick<Color>(
        'chip.selectedBackground',
        chipSelectedBackground,
      ),
      chipSelectedForeground: pick<Color>(
        'chip.selectedForeground',
        chipSelectedForeground,
      ),
      chipSelectedIconBox: pick<Color>(
        'chip.selectedIconBox',
        chipSelectedIconBox,
      ),
      chipHintBackground: pick<Color>(
        'chip.hintBackground',
        chipHintBackground,
      ),
      chipHintForeground: pick<Color>(
        'chip.hintForeground',
        chipHintForeground,
      ),
      cardBackground: pick<Color>('card.background', cardBackground),
      cardBackgroundSelected: pick<Color>(
        'card.backgroundSelected',
        cardBackgroundSelected,
      ),
      cardBorder: pick<Color>('card.border', cardBorder),
      cardTitle: pick<Color>('card.title', cardTitle),
      cardSubtitle: pick<Color>('card.subtitle', cardSubtitle),
      cardOverline: pick<Color>('card.overline', cardOverline),
      cardSelectedIndicator: pick<Color>(
        'card.selectedIndicator',
        cardSelectedIndicator,
      ),
      cardPlaceholder: pick<Color>('card.placeholder', cardPlaceholder),
      cardCounter: pick<Color>('card.counter', cardCounter),
      bannerScrim: pick<UpGradient>('banner.scrim', bannerScrim),
      bannerIndicator: pick<Color>('banner.indicator', bannerIndicator),
      bannerIndicatorActive: pick<Color>(
        'banner.indicatorActive',
        bannerIndicatorActive,
      ),
      sheetBackground: pick<Color>('sheet.background', sheetBackground),
      sheetHeader: pick<Color>('sheet.header', sheetHeader),
      sheetHandle: pick<Color>('sheet.handle', sheetHandle),
      sheetItem: pick<Color>('sheet.item', sheetItem),
      sheetItemPressed: pick<Color>('sheet.itemPressed', sheetItemPressed),
      sheetItemIconBox: pick<Color>('sheet.itemIconBox', sheetItemIconBox),
      sheetUnderline: pick<Color>('sheet.underline', sheetUnderline),
      listItem: pick<Color>('list.item', listItem),
      listItemPressed: pick<Color>('list.itemPressed', listItemPressed),
      listSeparator: pick<Color>('list.separator', listSeparator),
      badgeBackground: pick<Color>('badge.background', badgeBackground),
      badgeForeground: pick<Color>('badge.foreground', badgeForeground),
      badgeNew: pick<Color>('badge.new', badgeNew),
      badgeTop: pick<Color>('badge.top', badgeTop),
      badgeTopForeground: pick<Color>(
        'badge.topForeground',
        badgeTopForeground,
      ),
      buttonPrimaryBackground: pick<Color>(
        'button.primaryBackground',
        buttonPrimaryBackground,
      ),
      buttonPrimaryForeground: pick<Color>(
        'button.primaryForeground',
        buttonPrimaryForeground,
      ),
      buttonPrimaryPressed: pick<Color>(
        'button.primaryPressed',
        buttonPrimaryPressed,
      ),
      buttonSecondaryBackground: pick<Color>(
        'button.secondaryBackground',
        buttonSecondaryBackground,
      ),
      buttonSecondaryForeground: pick<Color>(
        'button.secondaryForeground',
        buttonSecondaryForeground,
      ),
      buttonOutlineBorder: pick<Color>(
        'button.outlineBorder',
        buttonOutlineBorder,
      ),
      buttonGhostForeground: pick<Color>(
        'button.ghostForeground',
        buttonGhostForeground,
      ),
      buttonDangerBackground: pick<Color>(
        'button.dangerBackground',
        buttonDangerBackground,
      ),
      buttonDisabledBackground: pick<Color>(
        'button.disabledBackground',
        buttonDisabledBackground,
      ),
      buttonDisabledForeground: pick<Color>(
        'button.disabledForeground',
        buttonDisabledForeground,
      ),
      buttonAlertBorder: pick<Color>('button.alertBorder', buttonAlertBorder),
      buttonWhiteBackground: pick<Color>(
        'button.whiteBackground',
        buttonWhiteBackground,
      ),
      buttonWhiteForeground: pick<Color>(
        'button.whiteForeground',
        buttonWhiteForeground,
      ),
      inputBackground: pick<Color>('input.background', inputBackground),
      inputForeground: pick<Color>('input.foreground', inputForeground),
      inputPlaceholder: pick<Color>('input.placeholder', inputPlaceholder),
      inputCursor: pick<Color>('input.cursor', inputCursor),
      inputBorder: pick<Color>('input.border', inputBorder),
      inputFocus: pick<Color>('input.focus', inputFocus),
      sliderTrack: pick<Color>('slider.track', sliderTrack),
      sliderFill: pick<Color>('slider.fill', sliderFill),
      sliderThumb: pick<Color>('slider.thumb', sliderThumb),
      dialogBackground: pick<Color>('dialog.background', dialogBackground),
      dialogScrim: pick<Color>('dialog.scrim', dialogScrim),
      dialogLight: pick<Color>('dialog.light', dialogLight),
      dialogLightTitle: pick<Color>('dialog.lightTitle', dialogLightTitle),
      dialogLightText: pick<Color>('dialog.lightText', dialogLightText),
      toastBackground: pick<Color>('toast.background', toastBackground),
      toastForeground: pick<Color>('toast.foreground', toastForeground),
      meterTrack: pick<Color>('meter.track', meterTrack),
      meterLow: pick<Color>('meter.low', meterLow),
      meterMid: pick<Color>('meter.mid', meterMid),
      meterHigh: pick<Color>('meter.high', meterHigh),
      meterPeak: pick<Color>('meter.peak', meterPeak),
      waveformActive: pick<Color>('waveform.active', waveformActive),
      waveformInactive: pick<Color>('waveform.inactive', waveformInactive),
      waveformSelection: pick<Color>('waveform.selection', waveformSelection),
      waveformMarker: pick<Color>('waveform.marker', waveformMarker),
      progressRingTrack: pick<Color>('progressRing.track', progressRingTrack),
      progressRingFill: pick<Color>('progressRing.fill', progressRingFill),
      recordIndicator: pick<Color>('record.indicator', recordIndicator),
      recordTrackCard: pick<Color>('record.trackCard', recordTrackCard),
      genreLabel: pick<Color>('genre.label', genreLabel),
      genreRing: pick<Color>('genre.ring', genreRing),
      genreCheck: pick<Color>('genre.check', genreCheck),
      genreTabSelected: pick<Color>('genre.tabSelected', genreTabSelected),
      swatchRing: pick<Color>('swatch.ring', swatchRing),
      hubOnline: pick<Color>('hub.online', hubOnline),
      hubPairing: pick<Color>('hub.pairing', hubPairing),
      hubOffline: pick<Color>('hub.offline', hubOffline),
      padPalette0Core: pick<Color>('pad.palette.0.core', padPalette0Core),
      padPalette0Mid: pick<Color>('pad.palette.0.mid', padPalette0Mid),
      padPalette0Edge: pick<Color>('pad.palette.0.edge', padPalette0Edge),
      padPalette0Glow: pick<Color>('pad.palette.0.glow', padPalette0Glow),
      padPalette0Pressed: pick<Color>(
        'pad.palette.0.pressed',
        padPalette0Pressed,
      ),
      padPalette1Core: pick<Color>('pad.palette.1.core', padPalette1Core),
      padPalette1Mid: pick<Color>('pad.palette.1.mid', padPalette1Mid),
      padPalette1Edge: pick<Color>('pad.palette.1.edge', padPalette1Edge),
      padPalette1Glow: pick<Color>('pad.palette.1.glow', padPalette1Glow),
      padPalette1Pressed: pick<Color>(
        'pad.palette.1.pressed',
        padPalette1Pressed,
      ),
      padPalette2Core: pick<Color>('pad.palette.2.core', padPalette2Core),
      padPalette2Mid: pick<Color>('pad.palette.2.mid', padPalette2Mid),
      padPalette2Edge: pick<Color>('pad.palette.2.edge', padPalette2Edge),
      padPalette2Glow: pick<Color>('pad.palette.2.glow', padPalette2Glow),
      padPalette2Pressed: pick<Color>(
        'pad.palette.2.pressed',
        padPalette2Pressed,
      ),
      padPalette3Core: pick<Color>('pad.palette.3.core', padPalette3Core),
      padPalette3Mid: pick<Color>('pad.palette.3.mid', padPalette3Mid),
      padPalette3Edge: pick<Color>('pad.palette.3.edge', padPalette3Edge),
      padPalette3Glow: pick<Color>('pad.palette.3.glow', padPalette3Glow),
      padPalette3Pressed: pick<Color>(
        'pad.palette.3.pressed',
        padPalette3Pressed,
      ),
      padPalette4Core: pick<Color>('pad.palette.4.core', padPalette4Core),
      padPalette4Mid: pick<Color>('pad.palette.4.mid', padPalette4Mid),
      padPalette4Edge: pick<Color>('pad.palette.4.edge', padPalette4Edge),
      padPalette4Glow: pick<Color>('pad.palette.4.glow', padPalette4Glow),
      padPalette4Pressed: pick<Color>(
        'pad.palette.4.pressed',
        padPalette4Pressed,
      ),
      padPalette5Core: pick<Color>('pad.palette.5.core', padPalette5Core),
      padPalette5Mid: pick<Color>('pad.palette.5.mid', padPalette5Mid),
      padPalette5Edge: pick<Color>('pad.palette.5.edge', padPalette5Edge),
      padPalette5Glow: pick<Color>('pad.palette.5.glow', padPalette5Glow),
      padPalette5Pressed: pick<Color>(
        'pad.palette.5.pressed',
        padPalette5Pressed,
      ),
      padPalette6Core: pick<Color>('pad.palette.6.core', padPalette6Core),
      padPalette6Mid: pick<Color>('pad.palette.6.mid', padPalette6Mid),
      padPalette6Edge: pick<Color>('pad.palette.6.edge', padPalette6Edge),
      padPalette6Glow: pick<Color>('pad.palette.6.glow', padPalette6Glow),
      padPalette6Pressed: pick<Color>(
        'pad.palette.6.pressed',
        padPalette6Pressed,
      ),
      padPalette7Core: pick<Color>('pad.palette.7.core', padPalette7Core),
      padPalette7Mid: pick<Color>('pad.palette.7.mid', padPalette7Mid),
      padPalette7Edge: pick<Color>('pad.palette.7.edge', padPalette7Edge),
      padPalette7Glow: pick<Color>('pad.palette.7.glow', padPalette7Glow),
      padPalette7Pressed: pick<Color>(
        'pad.palette.7.pressed',
        padPalette7Pressed,
      ),
      padShapeRadiusRatio: pick<double>(
        'pad.shape.radiusRatio',
        padShapeRadiusRatio,
      ),
      padFillRadial: pick<double>('pad.fill.radial', padFillRadial),
      padShowNumber: pick<double>('pad.showNumber', padShowNumber),
      padFlash: pick<Color>('pad.flash', padFlash),
      padBorder: pick<Color>('pad.border', padBorder),
      padLabel: pick<Color>('pad.label', padLabel),
      padIdleFillOpacity: pick<double>(
        'pad.idle.fillOpacity',
        padIdleFillOpacity,
      ),
      padIdleBorderWidth: pick<double>(
        'pad.idle.borderWidth',
        padIdleBorderWidth,
      ),
      padIdleGlow: pick<double>('pad.idle.glow', padIdleGlow),
      padIdleBevel: pick<double>('pad.idle.bevel', padIdleBevel),
      padPressedFillOpacity: pick<double>(
        'pad.pressed.fillOpacity',
        padPressedFillOpacity,
      ),
      padPressedFlashOpacity: pick<double>(
        'pad.pressed.flashOpacity',
        padPressedFlashOpacity,
      ),
      padPressedGlow: pick<double>('pad.pressed.glow', padPressedGlow),
      padPressedScale: pick<double>('pad.pressed.scale', padPressedScale),
      padPlayingFillOpacity: pick<double>(
        'pad.playing.fillOpacity',
        padPlayingFillOpacity,
      ),
      padPlayingFlashOpacity: pick<double>(
        'pad.playing.flashOpacity',
        padPlayingFlashOpacity,
      ),
      padPlayingGlow: pick<double>('pad.playing.glow', padPlayingGlow),
      padPendingOpacityMin: pick<double>(
        'pad.pending.opacityMin',
        padPendingOpacityMin,
      ),
      padDisabledOpacity: pick<double>(
        'pad.disabled.opacity',
        padDisabledOpacity,
      ),
      padSelectedBorder: pick<Color>('pad.selected.border', padSelectedBorder),
      padSelectedBorderWidth: pick<double>(
        'pad.selected.borderWidth',
        padSelectedBorderWidth,
      ),
      padLoopIdleFill: pick<Color>('pad.loop.idleFill', padLoopIdleFill),
      padLoopIdleFillOpacity: pick<double>(
        'pad.loop.idleFillOpacity',
        padLoopIdleFillOpacity,
      ),
      padLoopBorderWidth: pick<double>(
        'pad.loop.borderWidth',
        padLoopBorderWidth,
      ),
      padLoopIcon: pick<Color>('pad.loop.icon', padLoopIcon),
      padLoopIconOpacity: pick<double>(
        'pad.loop.iconOpacity',
        padLoopIconOpacity,
      ),
      padEmptyFill: pick<UpGradient>('pad.empty.fill', padEmptyFill),
      padEmptyBorder: pick<Color>('pad.empty.border', padEmptyBorder),
      padEmptyOpacity: pick<double>('pad.empty.opacity', padEmptyOpacity),
      padTutorialDimOpacity: pick<double>(
        'pad.tutorial.dimOpacity',
        padTutorialDimOpacity,
      ),
      padTutorialHighlight: pick<Color>(
        'pad.tutorial.highlight',
        padTutorialHighlight,
      ),
      padTutorialFill: pick<Color>('pad.tutorial.fill', padTutorialFill),
      padTutorialOutline: pick<Color>(
        'pad.tutorial.outline',
        padTutorialOutline,
      ),
      padTutorialLoopIcon: pick<Color>(
        'pad.tutorial.loopIcon',
        padTutorialLoopIcon,
      ),
      surfaceApp: pick<Color>('surface.app', surfaceApp),
      surfacePads: pick<Color>('surface.pads', surfacePads),
      surfacePage: pick<Color>('surface.page', surfacePage),
      surfaceRaised: pick<Color>('surface.raised', surfaceRaised),
      surfaceRaisedHigh: pick<Color>('surface.raisedHigh', surfaceRaisedHigh),
      surfaceSunken: pick<Color>('surface.sunken', surfaceSunken),
      surfaceToolbar: pick<Color>('surface.toolbar', surfaceToolbar),
      surfaceBankButton: pick<Color>('surface.bankButton', surfaceBankButton),
      surfacePadContainer: pick<Color>(
        'surface.padContainer',
        surfacePadContainer,
      ),
      surfaceScrim: pick<Color>('surface.scrim', surfaceScrim),
      surfaceDim: pick<Color>('surface.dim', surfaceDim),
      surfaceOverlayDownload: pick<Color>(
        'surface.overlayDownload',
        surfaceOverlayDownload,
      ),
      surfaceScrimStrong: pick<Color>(
        'surface.scrimStrong',
        surfaceScrimStrong,
      ),
      surfaceKitEditor: pick<Color>('surface.kitEditor', surfaceKitEditor),
      surfaceSocial: pick<Color>('surface.social', surfaceSocial),
      surfaceTabBar: pick<Color>('surface.tabBar', surfaceTabBar),
      surfaceNavShadow: pick<Color>('surface.navShadow', surfaceNavShadow),
      borderSubtle: pick<Color>('border.subtle', borderSubtle),
      borderDefault: pick<Color>('border.default', borderDefault),
      borderStrong: pick<Color>('border.strong', borderStrong),
      borderDivider: pick<Color>('border.divider', borderDivider),
      borderInverse: pick<Color>('border.inverse', borderInverse),
      borderDark: pick<Color>('border.dark', borderDark),
      textPrimary: pick<Color>('text.primary', textPrimary),
      textSecondary: pick<Color>('text.secondary', textSecondary),
      textMuted: pick<Color>('text.muted', textMuted),
      textFaint: pick<Color>('text.faint', textFaint),
      textDisabled: pick<Color>('text.disabled', textDisabled),
      textInverse: pick<Color>('text.inverse', textInverse),
      textOnAccent: pick<Color>('text.onAccent', textOnAccent),
      textLink: pick<Color>('text.link', textLink),
      textSection: pick<Color>('text.section', textSection),
      textDark: pick<Color>('text.dark', textDark),
      iconPrimary: pick<Color>('icon.primary', iconPrimary),
      iconSecondary: pick<Color>('icon.secondary', iconSecondary),
      iconDisabled: pick<Color>('icon.disabled', iconDisabled),
      iconOnAccent: pick<Color>('icon.onAccent', iconOnAccent),
      accentPrimary: pick<Color>('accent.primary', accentPrimary),
      accentPrimaryPressed: pick<Color>(
        'accent.primaryPressed',
        accentPrimaryPressed,
      ),
      accentPrimaryMuted: pick<Color>(
        'accent.primaryMuted',
        accentPrimaryMuted,
      ),
      accentSelected: pick<Color>('accent.selected', accentSelected),
      accentSecondary: pick<Color>('accent.secondary', accentSecondary),
      accentPreview: pick<Color>('accent.preview', accentPreview),
      accentAlert: pick<Color>('accent.alert', accentAlert),
      accentCreate: pick<Color>('accent.create', accentCreate),
      statusSuccess: pick<Color>('status.success', statusSuccess),
      statusWarning: pick<Color>('status.warning', statusWarning),
      statusDanger: pick<Color>('status.danger', statusDanger),
      statusInfo: pick<Color>('status.info', statusInfo),
      statusRecording: pick<Color>('status.recording', statusRecording),
      brandBackground: pick<UpGradient>('brand.background', brandBackground),
      focusRing: pick<Color>('focus.ring', focusRing),
      focusRingWidth: pick<double>('focus.ringWidth', focusRingWidth),
      feedbackPerfect: pick<Color>('feedback.perfect', feedbackPerfect),
      feedbackWrong: pick<Color>('feedback.wrong', feedbackWrong),
      feedbackBubble: pick<Color>('feedback.bubble', feedbackBubble),
      feedbackBubbleText: pick<Color>(
        'feedback.bubbleText',
        feedbackBubbleText,
      ),
    );
  }

  UpSemantic copyWith({
    Color? transportBackground,
    Color? transportStopBackground,
    Color? transportStopIcon,
    Color? transportWaveformPlayed,
    Color? transportWaveformUnplayed,
    Color? transportProgressTrack,
    Color? transportProgressFill,
    Color? transportThumb,
    Color? transportSpeedBackground,
    Color? transportSpeedText,
    Color? chipBackground,
    Color? chipForeground,
    Color? chipIconBox,
    Color? chipSelectedBackground,
    Color? chipSelectedForeground,
    Color? chipSelectedIconBox,
    Color? chipHintBackground,
    Color? chipHintForeground,
    Color? cardBackground,
    Color? cardBackgroundSelected,
    Color? cardBorder,
    Color? cardTitle,
    Color? cardSubtitle,
    Color? cardOverline,
    Color? cardSelectedIndicator,
    Color? cardPlaceholder,
    Color? cardCounter,
    UpGradient? bannerScrim,
    Color? bannerIndicator,
    Color? bannerIndicatorActive,
    Color? sheetBackground,
    Color? sheetHeader,
    Color? sheetHandle,
    Color? sheetItem,
    Color? sheetItemPressed,
    Color? sheetItemIconBox,
    Color? sheetUnderline,
    Color? listItem,
    Color? listItemPressed,
    Color? listSeparator,
    Color? badgeBackground,
    Color? badgeForeground,
    Color? badgeNew,
    Color? badgeTop,
    Color? badgeTopForeground,
    Color? buttonPrimaryBackground,
    Color? buttonPrimaryForeground,
    Color? buttonPrimaryPressed,
    Color? buttonSecondaryBackground,
    Color? buttonSecondaryForeground,
    Color? buttonOutlineBorder,
    Color? buttonGhostForeground,
    Color? buttonDangerBackground,
    Color? buttonDisabledBackground,
    Color? buttonDisabledForeground,
    Color? buttonAlertBorder,
    Color? buttonWhiteBackground,
    Color? buttonWhiteForeground,
    Color? inputBackground,
    Color? inputForeground,
    Color? inputPlaceholder,
    Color? inputCursor,
    Color? inputBorder,
    Color? inputFocus,
    Color? sliderTrack,
    Color? sliderFill,
    Color? sliderThumb,
    Color? dialogBackground,
    Color? dialogScrim,
    Color? dialogLight,
    Color? dialogLightTitle,
    Color? dialogLightText,
    Color? toastBackground,
    Color? toastForeground,
    Color? meterTrack,
    Color? meterLow,
    Color? meterMid,
    Color? meterHigh,
    Color? meterPeak,
    Color? waveformActive,
    Color? waveformInactive,
    Color? waveformSelection,
    Color? waveformMarker,
    Color? progressRingTrack,
    Color? progressRingFill,
    Color? recordIndicator,
    Color? recordTrackCard,
    Color? genreLabel,
    Color? genreRing,
    Color? genreCheck,
    Color? genreTabSelected,
    Color? swatchRing,
    Color? hubOnline,
    Color? hubPairing,
    Color? hubOffline,
    Color? padPalette0Core,
    Color? padPalette0Mid,
    Color? padPalette0Edge,
    Color? padPalette0Glow,
    Color? padPalette0Pressed,
    Color? padPalette1Core,
    Color? padPalette1Mid,
    Color? padPalette1Edge,
    Color? padPalette1Glow,
    Color? padPalette1Pressed,
    Color? padPalette2Core,
    Color? padPalette2Mid,
    Color? padPalette2Edge,
    Color? padPalette2Glow,
    Color? padPalette2Pressed,
    Color? padPalette3Core,
    Color? padPalette3Mid,
    Color? padPalette3Edge,
    Color? padPalette3Glow,
    Color? padPalette3Pressed,
    Color? padPalette4Core,
    Color? padPalette4Mid,
    Color? padPalette4Edge,
    Color? padPalette4Glow,
    Color? padPalette4Pressed,
    Color? padPalette5Core,
    Color? padPalette5Mid,
    Color? padPalette5Edge,
    Color? padPalette5Glow,
    Color? padPalette5Pressed,
    Color? padPalette6Core,
    Color? padPalette6Mid,
    Color? padPalette6Edge,
    Color? padPalette6Glow,
    Color? padPalette6Pressed,
    Color? padPalette7Core,
    Color? padPalette7Mid,
    Color? padPalette7Edge,
    Color? padPalette7Glow,
    Color? padPalette7Pressed,
    double? padShapeRadiusRatio,
    double? padFillRadial,
    double? padShowNumber,
    Color? padFlash,
    Color? padBorder,
    Color? padLabel,
    double? padIdleFillOpacity,
    double? padIdleBorderWidth,
    double? padIdleGlow,
    double? padIdleBevel,
    double? padPressedFillOpacity,
    double? padPressedFlashOpacity,
    double? padPressedGlow,
    double? padPressedScale,
    double? padPlayingFillOpacity,
    double? padPlayingFlashOpacity,
    double? padPlayingGlow,
    double? padPendingOpacityMin,
    double? padDisabledOpacity,
    Color? padSelectedBorder,
    double? padSelectedBorderWidth,
    Color? padLoopIdleFill,
    double? padLoopIdleFillOpacity,
    double? padLoopBorderWidth,
    Color? padLoopIcon,
    double? padLoopIconOpacity,
    UpGradient? padEmptyFill,
    Color? padEmptyBorder,
    double? padEmptyOpacity,
    double? padTutorialDimOpacity,
    Color? padTutorialHighlight,
    Color? padTutorialFill,
    Color? padTutorialOutline,
    Color? padTutorialLoopIcon,
    Color? surfaceApp,
    Color? surfacePads,
    Color? surfacePage,
    Color? surfaceRaised,
    Color? surfaceRaisedHigh,
    Color? surfaceSunken,
    Color? surfaceToolbar,
    Color? surfaceBankButton,
    Color? surfacePadContainer,
    Color? surfaceScrim,
    Color? surfaceDim,
    Color? surfaceOverlayDownload,
    Color? surfaceScrimStrong,
    Color? surfaceKitEditor,
    Color? surfaceSocial,
    Color? surfaceTabBar,
    Color? surfaceNavShadow,
    Color? borderSubtle,
    Color? borderDefault,
    Color? borderStrong,
    Color? borderDivider,
    Color? borderInverse,
    Color? borderDark,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textFaint,
    Color? textDisabled,
    Color? textInverse,
    Color? textOnAccent,
    Color? textLink,
    Color? textSection,
    Color? textDark,
    Color? iconPrimary,
    Color? iconSecondary,
    Color? iconDisabled,
    Color? iconOnAccent,
    Color? accentPrimary,
    Color? accentPrimaryPressed,
    Color? accentPrimaryMuted,
    Color? accentSelected,
    Color? accentSecondary,
    Color? accentPreview,
    Color? accentAlert,
    Color? accentCreate,
    Color? statusSuccess,
    Color? statusWarning,
    Color? statusDanger,
    Color? statusInfo,
    Color? statusRecording,
    UpGradient? brandBackground,
    Color? focusRing,
    double? focusRingWidth,
    Color? feedbackPerfect,
    Color? feedbackWrong,
    Color? feedbackBubble,
    Color? feedbackBubbleText,
  }) {
    return UpSemantic(
      transportBackground: transportBackground ?? this.transportBackground,
      transportStopBackground:
          transportStopBackground ?? this.transportStopBackground,
      transportStopIcon: transportStopIcon ?? this.transportStopIcon,
      transportWaveformPlayed:
          transportWaveformPlayed ?? this.transportWaveformPlayed,
      transportWaveformUnplayed:
          transportWaveformUnplayed ?? this.transportWaveformUnplayed,
      transportProgressTrack:
          transportProgressTrack ?? this.transportProgressTrack,
      transportProgressFill:
          transportProgressFill ?? this.transportProgressFill,
      transportThumb: transportThumb ?? this.transportThumb,
      transportSpeedBackground:
          transportSpeedBackground ?? this.transportSpeedBackground,
      transportSpeedText: transportSpeedText ?? this.transportSpeedText,
      chipBackground: chipBackground ?? this.chipBackground,
      chipForeground: chipForeground ?? this.chipForeground,
      chipIconBox: chipIconBox ?? this.chipIconBox,
      chipSelectedBackground:
          chipSelectedBackground ?? this.chipSelectedBackground,
      chipSelectedForeground:
          chipSelectedForeground ?? this.chipSelectedForeground,
      chipSelectedIconBox: chipSelectedIconBox ?? this.chipSelectedIconBox,
      chipHintBackground: chipHintBackground ?? this.chipHintBackground,
      chipHintForeground: chipHintForeground ?? this.chipHintForeground,
      cardBackground: cardBackground ?? this.cardBackground,
      cardBackgroundSelected:
          cardBackgroundSelected ?? this.cardBackgroundSelected,
      cardBorder: cardBorder ?? this.cardBorder,
      cardTitle: cardTitle ?? this.cardTitle,
      cardSubtitle: cardSubtitle ?? this.cardSubtitle,
      cardOverline: cardOverline ?? this.cardOverline,
      cardSelectedIndicator:
          cardSelectedIndicator ?? this.cardSelectedIndicator,
      cardPlaceholder: cardPlaceholder ?? this.cardPlaceholder,
      cardCounter: cardCounter ?? this.cardCounter,
      bannerScrim: bannerScrim ?? this.bannerScrim,
      bannerIndicator: bannerIndicator ?? this.bannerIndicator,
      bannerIndicatorActive:
          bannerIndicatorActive ?? this.bannerIndicatorActive,
      sheetBackground: sheetBackground ?? this.sheetBackground,
      sheetHeader: sheetHeader ?? this.sheetHeader,
      sheetHandle: sheetHandle ?? this.sheetHandle,
      sheetItem: sheetItem ?? this.sheetItem,
      sheetItemPressed: sheetItemPressed ?? this.sheetItemPressed,
      sheetItemIconBox: sheetItemIconBox ?? this.sheetItemIconBox,
      sheetUnderline: sheetUnderline ?? this.sheetUnderline,
      listItem: listItem ?? this.listItem,
      listItemPressed: listItemPressed ?? this.listItemPressed,
      listSeparator: listSeparator ?? this.listSeparator,
      badgeBackground: badgeBackground ?? this.badgeBackground,
      badgeForeground: badgeForeground ?? this.badgeForeground,
      badgeNew: badgeNew ?? this.badgeNew,
      badgeTop: badgeTop ?? this.badgeTop,
      badgeTopForeground: badgeTopForeground ?? this.badgeTopForeground,
      buttonPrimaryBackground:
          buttonPrimaryBackground ?? this.buttonPrimaryBackground,
      buttonPrimaryForeground:
          buttonPrimaryForeground ?? this.buttonPrimaryForeground,
      buttonPrimaryPressed: buttonPrimaryPressed ?? this.buttonPrimaryPressed,
      buttonSecondaryBackground:
          buttonSecondaryBackground ?? this.buttonSecondaryBackground,
      buttonSecondaryForeground:
          buttonSecondaryForeground ?? this.buttonSecondaryForeground,
      buttonOutlineBorder: buttonOutlineBorder ?? this.buttonOutlineBorder,
      buttonGhostForeground:
          buttonGhostForeground ?? this.buttonGhostForeground,
      buttonDangerBackground:
          buttonDangerBackground ?? this.buttonDangerBackground,
      buttonDisabledBackground:
          buttonDisabledBackground ?? this.buttonDisabledBackground,
      buttonDisabledForeground:
          buttonDisabledForeground ?? this.buttonDisabledForeground,
      buttonAlertBorder: buttonAlertBorder ?? this.buttonAlertBorder,
      buttonWhiteBackground:
          buttonWhiteBackground ?? this.buttonWhiteBackground,
      buttonWhiteForeground:
          buttonWhiteForeground ?? this.buttonWhiteForeground,
      inputBackground: inputBackground ?? this.inputBackground,
      inputForeground: inputForeground ?? this.inputForeground,
      inputPlaceholder: inputPlaceholder ?? this.inputPlaceholder,
      inputCursor: inputCursor ?? this.inputCursor,
      inputBorder: inputBorder ?? this.inputBorder,
      inputFocus: inputFocus ?? this.inputFocus,
      sliderTrack: sliderTrack ?? this.sliderTrack,
      sliderFill: sliderFill ?? this.sliderFill,
      sliderThumb: sliderThumb ?? this.sliderThumb,
      dialogBackground: dialogBackground ?? this.dialogBackground,
      dialogScrim: dialogScrim ?? this.dialogScrim,
      dialogLight: dialogLight ?? this.dialogLight,
      dialogLightTitle: dialogLightTitle ?? this.dialogLightTitle,
      dialogLightText: dialogLightText ?? this.dialogLightText,
      toastBackground: toastBackground ?? this.toastBackground,
      toastForeground: toastForeground ?? this.toastForeground,
      meterTrack: meterTrack ?? this.meterTrack,
      meterLow: meterLow ?? this.meterLow,
      meterMid: meterMid ?? this.meterMid,
      meterHigh: meterHigh ?? this.meterHigh,
      meterPeak: meterPeak ?? this.meterPeak,
      waveformActive: waveformActive ?? this.waveformActive,
      waveformInactive: waveformInactive ?? this.waveformInactive,
      waveformSelection: waveformSelection ?? this.waveformSelection,
      waveformMarker: waveformMarker ?? this.waveformMarker,
      progressRingTrack: progressRingTrack ?? this.progressRingTrack,
      progressRingFill: progressRingFill ?? this.progressRingFill,
      recordIndicator: recordIndicator ?? this.recordIndicator,
      recordTrackCard: recordTrackCard ?? this.recordTrackCard,
      genreLabel: genreLabel ?? this.genreLabel,
      genreRing: genreRing ?? this.genreRing,
      genreCheck: genreCheck ?? this.genreCheck,
      genreTabSelected: genreTabSelected ?? this.genreTabSelected,
      swatchRing: swatchRing ?? this.swatchRing,
      hubOnline: hubOnline ?? this.hubOnline,
      hubPairing: hubPairing ?? this.hubPairing,
      hubOffline: hubOffline ?? this.hubOffline,
      padPalette0Core: padPalette0Core ?? this.padPalette0Core,
      padPalette0Mid: padPalette0Mid ?? this.padPalette0Mid,
      padPalette0Edge: padPalette0Edge ?? this.padPalette0Edge,
      padPalette0Glow: padPalette0Glow ?? this.padPalette0Glow,
      padPalette0Pressed: padPalette0Pressed ?? this.padPalette0Pressed,
      padPalette1Core: padPalette1Core ?? this.padPalette1Core,
      padPalette1Mid: padPalette1Mid ?? this.padPalette1Mid,
      padPalette1Edge: padPalette1Edge ?? this.padPalette1Edge,
      padPalette1Glow: padPalette1Glow ?? this.padPalette1Glow,
      padPalette1Pressed: padPalette1Pressed ?? this.padPalette1Pressed,
      padPalette2Core: padPalette2Core ?? this.padPalette2Core,
      padPalette2Mid: padPalette2Mid ?? this.padPalette2Mid,
      padPalette2Edge: padPalette2Edge ?? this.padPalette2Edge,
      padPalette2Glow: padPalette2Glow ?? this.padPalette2Glow,
      padPalette2Pressed: padPalette2Pressed ?? this.padPalette2Pressed,
      padPalette3Core: padPalette3Core ?? this.padPalette3Core,
      padPalette3Mid: padPalette3Mid ?? this.padPalette3Mid,
      padPalette3Edge: padPalette3Edge ?? this.padPalette3Edge,
      padPalette3Glow: padPalette3Glow ?? this.padPalette3Glow,
      padPalette3Pressed: padPalette3Pressed ?? this.padPalette3Pressed,
      padPalette4Core: padPalette4Core ?? this.padPalette4Core,
      padPalette4Mid: padPalette4Mid ?? this.padPalette4Mid,
      padPalette4Edge: padPalette4Edge ?? this.padPalette4Edge,
      padPalette4Glow: padPalette4Glow ?? this.padPalette4Glow,
      padPalette4Pressed: padPalette4Pressed ?? this.padPalette4Pressed,
      padPalette5Core: padPalette5Core ?? this.padPalette5Core,
      padPalette5Mid: padPalette5Mid ?? this.padPalette5Mid,
      padPalette5Edge: padPalette5Edge ?? this.padPalette5Edge,
      padPalette5Glow: padPalette5Glow ?? this.padPalette5Glow,
      padPalette5Pressed: padPalette5Pressed ?? this.padPalette5Pressed,
      padPalette6Core: padPalette6Core ?? this.padPalette6Core,
      padPalette6Mid: padPalette6Mid ?? this.padPalette6Mid,
      padPalette6Edge: padPalette6Edge ?? this.padPalette6Edge,
      padPalette6Glow: padPalette6Glow ?? this.padPalette6Glow,
      padPalette6Pressed: padPalette6Pressed ?? this.padPalette6Pressed,
      padPalette7Core: padPalette7Core ?? this.padPalette7Core,
      padPalette7Mid: padPalette7Mid ?? this.padPalette7Mid,
      padPalette7Edge: padPalette7Edge ?? this.padPalette7Edge,
      padPalette7Glow: padPalette7Glow ?? this.padPalette7Glow,
      padPalette7Pressed: padPalette7Pressed ?? this.padPalette7Pressed,
      padShapeRadiusRatio: padShapeRadiusRatio ?? this.padShapeRadiusRatio,
      padFillRadial: padFillRadial ?? this.padFillRadial,
      padShowNumber: padShowNumber ?? this.padShowNumber,
      padFlash: padFlash ?? this.padFlash,
      padBorder: padBorder ?? this.padBorder,
      padLabel: padLabel ?? this.padLabel,
      padIdleFillOpacity: padIdleFillOpacity ?? this.padIdleFillOpacity,
      padIdleBorderWidth: padIdleBorderWidth ?? this.padIdleBorderWidth,
      padIdleGlow: padIdleGlow ?? this.padIdleGlow,
      padIdleBevel: padIdleBevel ?? this.padIdleBevel,
      padPressedFillOpacity:
          padPressedFillOpacity ?? this.padPressedFillOpacity,
      padPressedFlashOpacity:
          padPressedFlashOpacity ?? this.padPressedFlashOpacity,
      padPressedGlow: padPressedGlow ?? this.padPressedGlow,
      padPressedScale: padPressedScale ?? this.padPressedScale,
      padPlayingFillOpacity:
          padPlayingFillOpacity ?? this.padPlayingFillOpacity,
      padPlayingFlashOpacity:
          padPlayingFlashOpacity ?? this.padPlayingFlashOpacity,
      padPlayingGlow: padPlayingGlow ?? this.padPlayingGlow,
      padPendingOpacityMin: padPendingOpacityMin ?? this.padPendingOpacityMin,
      padDisabledOpacity: padDisabledOpacity ?? this.padDisabledOpacity,
      padSelectedBorder: padSelectedBorder ?? this.padSelectedBorder,
      padSelectedBorderWidth:
          padSelectedBorderWidth ?? this.padSelectedBorderWidth,
      padLoopIdleFill: padLoopIdleFill ?? this.padLoopIdleFill,
      padLoopIdleFillOpacity:
          padLoopIdleFillOpacity ?? this.padLoopIdleFillOpacity,
      padLoopBorderWidth: padLoopBorderWidth ?? this.padLoopBorderWidth,
      padLoopIcon: padLoopIcon ?? this.padLoopIcon,
      padLoopIconOpacity: padLoopIconOpacity ?? this.padLoopIconOpacity,
      padEmptyFill: padEmptyFill ?? this.padEmptyFill,
      padEmptyBorder: padEmptyBorder ?? this.padEmptyBorder,
      padEmptyOpacity: padEmptyOpacity ?? this.padEmptyOpacity,
      padTutorialDimOpacity:
          padTutorialDimOpacity ?? this.padTutorialDimOpacity,
      padTutorialHighlight: padTutorialHighlight ?? this.padTutorialHighlight,
      padTutorialFill: padTutorialFill ?? this.padTutorialFill,
      padTutorialOutline: padTutorialOutline ?? this.padTutorialOutline,
      padTutorialLoopIcon: padTutorialLoopIcon ?? this.padTutorialLoopIcon,
      surfaceApp: surfaceApp ?? this.surfaceApp,
      surfacePads: surfacePads ?? this.surfacePads,
      surfacePage: surfacePage ?? this.surfacePage,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceRaisedHigh: surfaceRaisedHigh ?? this.surfaceRaisedHigh,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      surfaceToolbar: surfaceToolbar ?? this.surfaceToolbar,
      surfaceBankButton: surfaceBankButton ?? this.surfaceBankButton,
      surfacePadContainer: surfacePadContainer ?? this.surfacePadContainer,
      surfaceScrim: surfaceScrim ?? this.surfaceScrim,
      surfaceDim: surfaceDim ?? this.surfaceDim,
      surfaceOverlayDownload:
          surfaceOverlayDownload ?? this.surfaceOverlayDownload,
      surfaceScrimStrong: surfaceScrimStrong ?? this.surfaceScrimStrong,
      surfaceKitEditor: surfaceKitEditor ?? this.surfaceKitEditor,
      surfaceSocial: surfaceSocial ?? this.surfaceSocial,
      surfaceTabBar: surfaceTabBar ?? this.surfaceTabBar,
      surfaceNavShadow: surfaceNavShadow ?? this.surfaceNavShadow,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderDefault: borderDefault ?? this.borderDefault,
      borderStrong: borderStrong ?? this.borderStrong,
      borderDivider: borderDivider ?? this.borderDivider,
      borderInverse: borderInverse ?? this.borderInverse,
      borderDark: borderDark ?? this.borderDark,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      textDisabled: textDisabled ?? this.textDisabled,
      textInverse: textInverse ?? this.textInverse,
      textOnAccent: textOnAccent ?? this.textOnAccent,
      textLink: textLink ?? this.textLink,
      textSection: textSection ?? this.textSection,
      textDark: textDark ?? this.textDark,
      iconPrimary: iconPrimary ?? this.iconPrimary,
      iconSecondary: iconSecondary ?? this.iconSecondary,
      iconDisabled: iconDisabled ?? this.iconDisabled,
      iconOnAccent: iconOnAccent ?? this.iconOnAccent,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentPrimaryPressed: accentPrimaryPressed ?? this.accentPrimaryPressed,
      accentPrimaryMuted: accentPrimaryMuted ?? this.accentPrimaryMuted,
      accentSelected: accentSelected ?? this.accentSelected,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      accentPreview: accentPreview ?? this.accentPreview,
      accentAlert: accentAlert ?? this.accentAlert,
      accentCreate: accentCreate ?? this.accentCreate,
      statusSuccess: statusSuccess ?? this.statusSuccess,
      statusWarning: statusWarning ?? this.statusWarning,
      statusDanger: statusDanger ?? this.statusDanger,
      statusInfo: statusInfo ?? this.statusInfo,
      statusRecording: statusRecording ?? this.statusRecording,
      brandBackground: brandBackground ?? this.brandBackground,
      focusRing: focusRing ?? this.focusRing,
      focusRingWidth: focusRingWidth ?? this.focusRingWidth,
      feedbackPerfect: feedbackPerfect ?? this.feedbackPerfect,
      feedbackWrong: feedbackWrong ?? this.feedbackWrong,
      feedbackBubble: feedbackBubble ?? this.feedbackBubble,
      feedbackBubbleText: feedbackBubbleText ?? this.feedbackBubbleText,
    );
  }

  /// Linear interpolation of every token (used by theme switch animations).
  static UpSemantic lerp(UpSemantic a, UpSemantic b, double t) {
    if (identical(a, b)) return a;
    return UpSemantic(
      transportBackground: Color.lerp(
        a.transportBackground,
        b.transportBackground,
        t,
      )!,
      transportStopBackground: Color.lerp(
        a.transportStopBackground,
        b.transportStopBackground,
        t,
      )!,
      transportStopIcon: Color.lerp(
        a.transportStopIcon,
        b.transportStopIcon,
        t,
      )!,
      transportWaveformPlayed: Color.lerp(
        a.transportWaveformPlayed,
        b.transportWaveformPlayed,
        t,
      )!,
      transportWaveformUnplayed: Color.lerp(
        a.transportWaveformUnplayed,
        b.transportWaveformUnplayed,
        t,
      )!,
      transportProgressTrack: Color.lerp(
        a.transportProgressTrack,
        b.transportProgressTrack,
        t,
      )!,
      transportProgressFill: Color.lerp(
        a.transportProgressFill,
        b.transportProgressFill,
        t,
      )!,
      transportThumb: Color.lerp(a.transportThumb, b.transportThumb, t)!,
      transportSpeedBackground: Color.lerp(
        a.transportSpeedBackground,
        b.transportSpeedBackground,
        t,
      )!,
      transportSpeedText: Color.lerp(
        a.transportSpeedText,
        b.transportSpeedText,
        t,
      )!,
      chipBackground: Color.lerp(a.chipBackground, b.chipBackground, t)!,
      chipForeground: Color.lerp(a.chipForeground, b.chipForeground, t)!,
      chipIconBox: Color.lerp(a.chipIconBox, b.chipIconBox, t)!,
      chipSelectedBackground: Color.lerp(
        a.chipSelectedBackground,
        b.chipSelectedBackground,
        t,
      )!,
      chipSelectedForeground: Color.lerp(
        a.chipSelectedForeground,
        b.chipSelectedForeground,
        t,
      )!,
      chipSelectedIconBox: Color.lerp(
        a.chipSelectedIconBox,
        b.chipSelectedIconBox,
        t,
      )!,
      chipHintBackground: Color.lerp(
        a.chipHintBackground,
        b.chipHintBackground,
        t,
      )!,
      chipHintForeground: Color.lerp(
        a.chipHintForeground,
        b.chipHintForeground,
        t,
      )!,
      cardBackground: Color.lerp(a.cardBackground, b.cardBackground, t)!,
      cardBackgroundSelected: Color.lerp(
        a.cardBackgroundSelected,
        b.cardBackgroundSelected,
        t,
      )!,
      cardBorder: Color.lerp(a.cardBorder, b.cardBorder, t)!,
      cardTitle: Color.lerp(a.cardTitle, b.cardTitle, t)!,
      cardSubtitle: Color.lerp(a.cardSubtitle, b.cardSubtitle, t)!,
      cardOverline: Color.lerp(a.cardOverline, b.cardOverline, t)!,
      cardSelectedIndicator: Color.lerp(
        a.cardSelectedIndicator,
        b.cardSelectedIndicator,
        t,
      )!,
      cardPlaceholder: Color.lerp(a.cardPlaceholder, b.cardPlaceholder, t)!,
      cardCounter: Color.lerp(a.cardCounter, b.cardCounter, t)!,
      bannerScrim: UpGradient.lerp(a.bannerScrim, b.bannerScrim, t),
      bannerIndicator: Color.lerp(a.bannerIndicator, b.bannerIndicator, t)!,
      bannerIndicatorActive: Color.lerp(
        a.bannerIndicatorActive,
        b.bannerIndicatorActive,
        t,
      )!,
      sheetBackground: Color.lerp(a.sheetBackground, b.sheetBackground, t)!,
      sheetHeader: Color.lerp(a.sheetHeader, b.sheetHeader, t)!,
      sheetHandle: Color.lerp(a.sheetHandle, b.sheetHandle, t)!,
      sheetItem: Color.lerp(a.sheetItem, b.sheetItem, t)!,
      sheetItemPressed: Color.lerp(a.sheetItemPressed, b.sheetItemPressed, t)!,
      sheetItemIconBox: Color.lerp(a.sheetItemIconBox, b.sheetItemIconBox, t)!,
      sheetUnderline: Color.lerp(a.sheetUnderline, b.sheetUnderline, t)!,
      listItem: Color.lerp(a.listItem, b.listItem, t)!,
      listItemPressed: Color.lerp(a.listItemPressed, b.listItemPressed, t)!,
      listSeparator: Color.lerp(a.listSeparator, b.listSeparator, t)!,
      badgeBackground: Color.lerp(a.badgeBackground, b.badgeBackground, t)!,
      badgeForeground: Color.lerp(a.badgeForeground, b.badgeForeground, t)!,
      badgeNew: Color.lerp(a.badgeNew, b.badgeNew, t)!,
      badgeTop: Color.lerp(a.badgeTop, b.badgeTop, t)!,
      badgeTopForeground: Color.lerp(
        a.badgeTopForeground,
        b.badgeTopForeground,
        t,
      )!,
      buttonPrimaryBackground: Color.lerp(
        a.buttonPrimaryBackground,
        b.buttonPrimaryBackground,
        t,
      )!,
      buttonPrimaryForeground: Color.lerp(
        a.buttonPrimaryForeground,
        b.buttonPrimaryForeground,
        t,
      )!,
      buttonPrimaryPressed: Color.lerp(
        a.buttonPrimaryPressed,
        b.buttonPrimaryPressed,
        t,
      )!,
      buttonSecondaryBackground: Color.lerp(
        a.buttonSecondaryBackground,
        b.buttonSecondaryBackground,
        t,
      )!,
      buttonSecondaryForeground: Color.lerp(
        a.buttonSecondaryForeground,
        b.buttonSecondaryForeground,
        t,
      )!,
      buttonOutlineBorder: Color.lerp(
        a.buttonOutlineBorder,
        b.buttonOutlineBorder,
        t,
      )!,
      buttonGhostForeground: Color.lerp(
        a.buttonGhostForeground,
        b.buttonGhostForeground,
        t,
      )!,
      buttonDangerBackground: Color.lerp(
        a.buttonDangerBackground,
        b.buttonDangerBackground,
        t,
      )!,
      buttonDisabledBackground: Color.lerp(
        a.buttonDisabledBackground,
        b.buttonDisabledBackground,
        t,
      )!,
      buttonDisabledForeground: Color.lerp(
        a.buttonDisabledForeground,
        b.buttonDisabledForeground,
        t,
      )!,
      buttonAlertBorder: Color.lerp(
        a.buttonAlertBorder,
        b.buttonAlertBorder,
        t,
      )!,
      buttonWhiteBackground: Color.lerp(
        a.buttonWhiteBackground,
        b.buttonWhiteBackground,
        t,
      )!,
      buttonWhiteForeground: Color.lerp(
        a.buttonWhiteForeground,
        b.buttonWhiteForeground,
        t,
      )!,
      inputBackground: Color.lerp(a.inputBackground, b.inputBackground, t)!,
      inputForeground: Color.lerp(a.inputForeground, b.inputForeground, t)!,
      inputPlaceholder: Color.lerp(a.inputPlaceholder, b.inputPlaceholder, t)!,
      inputCursor: Color.lerp(a.inputCursor, b.inputCursor, t)!,
      inputBorder: Color.lerp(a.inputBorder, b.inputBorder, t)!,
      inputFocus: Color.lerp(a.inputFocus, b.inputFocus, t)!,
      sliderTrack: Color.lerp(a.sliderTrack, b.sliderTrack, t)!,
      sliderFill: Color.lerp(a.sliderFill, b.sliderFill, t)!,
      sliderThumb: Color.lerp(a.sliderThumb, b.sliderThumb, t)!,
      dialogBackground: Color.lerp(a.dialogBackground, b.dialogBackground, t)!,
      dialogScrim: Color.lerp(a.dialogScrim, b.dialogScrim, t)!,
      dialogLight: Color.lerp(a.dialogLight, b.dialogLight, t)!,
      dialogLightTitle: Color.lerp(a.dialogLightTitle, b.dialogLightTitle, t)!,
      dialogLightText: Color.lerp(a.dialogLightText, b.dialogLightText, t)!,
      toastBackground: Color.lerp(a.toastBackground, b.toastBackground, t)!,
      toastForeground: Color.lerp(a.toastForeground, b.toastForeground, t)!,
      meterTrack: Color.lerp(a.meterTrack, b.meterTrack, t)!,
      meterLow: Color.lerp(a.meterLow, b.meterLow, t)!,
      meterMid: Color.lerp(a.meterMid, b.meterMid, t)!,
      meterHigh: Color.lerp(a.meterHigh, b.meterHigh, t)!,
      meterPeak: Color.lerp(a.meterPeak, b.meterPeak, t)!,
      waveformActive: Color.lerp(a.waveformActive, b.waveformActive, t)!,
      waveformInactive: Color.lerp(a.waveformInactive, b.waveformInactive, t)!,
      waveformSelection: Color.lerp(
        a.waveformSelection,
        b.waveformSelection,
        t,
      )!,
      waveformMarker: Color.lerp(a.waveformMarker, b.waveformMarker, t)!,
      progressRingTrack: Color.lerp(
        a.progressRingTrack,
        b.progressRingTrack,
        t,
      )!,
      progressRingFill: Color.lerp(a.progressRingFill, b.progressRingFill, t)!,
      recordIndicator: Color.lerp(a.recordIndicator, b.recordIndicator, t)!,
      recordTrackCard: Color.lerp(a.recordTrackCard, b.recordTrackCard, t)!,
      genreLabel: Color.lerp(a.genreLabel, b.genreLabel, t)!,
      genreRing: Color.lerp(a.genreRing, b.genreRing, t)!,
      genreCheck: Color.lerp(a.genreCheck, b.genreCheck, t)!,
      genreTabSelected: Color.lerp(a.genreTabSelected, b.genreTabSelected, t)!,
      swatchRing: Color.lerp(a.swatchRing, b.swatchRing, t)!,
      hubOnline: Color.lerp(a.hubOnline, b.hubOnline, t)!,
      hubPairing: Color.lerp(a.hubPairing, b.hubPairing, t)!,
      hubOffline: Color.lerp(a.hubOffline, b.hubOffline, t)!,
      padPalette0Core: Color.lerp(a.padPalette0Core, b.padPalette0Core, t)!,
      padPalette0Mid: Color.lerp(a.padPalette0Mid, b.padPalette0Mid, t)!,
      padPalette0Edge: Color.lerp(a.padPalette0Edge, b.padPalette0Edge, t)!,
      padPalette0Glow: Color.lerp(a.padPalette0Glow, b.padPalette0Glow, t)!,
      padPalette0Pressed: Color.lerp(
        a.padPalette0Pressed,
        b.padPalette0Pressed,
        t,
      )!,
      padPalette1Core: Color.lerp(a.padPalette1Core, b.padPalette1Core, t)!,
      padPalette1Mid: Color.lerp(a.padPalette1Mid, b.padPalette1Mid, t)!,
      padPalette1Edge: Color.lerp(a.padPalette1Edge, b.padPalette1Edge, t)!,
      padPalette1Glow: Color.lerp(a.padPalette1Glow, b.padPalette1Glow, t)!,
      padPalette1Pressed: Color.lerp(
        a.padPalette1Pressed,
        b.padPalette1Pressed,
        t,
      )!,
      padPalette2Core: Color.lerp(a.padPalette2Core, b.padPalette2Core, t)!,
      padPalette2Mid: Color.lerp(a.padPalette2Mid, b.padPalette2Mid, t)!,
      padPalette2Edge: Color.lerp(a.padPalette2Edge, b.padPalette2Edge, t)!,
      padPalette2Glow: Color.lerp(a.padPalette2Glow, b.padPalette2Glow, t)!,
      padPalette2Pressed: Color.lerp(
        a.padPalette2Pressed,
        b.padPalette2Pressed,
        t,
      )!,
      padPalette3Core: Color.lerp(a.padPalette3Core, b.padPalette3Core, t)!,
      padPalette3Mid: Color.lerp(a.padPalette3Mid, b.padPalette3Mid, t)!,
      padPalette3Edge: Color.lerp(a.padPalette3Edge, b.padPalette3Edge, t)!,
      padPalette3Glow: Color.lerp(a.padPalette3Glow, b.padPalette3Glow, t)!,
      padPalette3Pressed: Color.lerp(
        a.padPalette3Pressed,
        b.padPalette3Pressed,
        t,
      )!,
      padPalette4Core: Color.lerp(a.padPalette4Core, b.padPalette4Core, t)!,
      padPalette4Mid: Color.lerp(a.padPalette4Mid, b.padPalette4Mid, t)!,
      padPalette4Edge: Color.lerp(a.padPalette4Edge, b.padPalette4Edge, t)!,
      padPalette4Glow: Color.lerp(a.padPalette4Glow, b.padPalette4Glow, t)!,
      padPalette4Pressed: Color.lerp(
        a.padPalette4Pressed,
        b.padPalette4Pressed,
        t,
      )!,
      padPalette5Core: Color.lerp(a.padPalette5Core, b.padPalette5Core, t)!,
      padPalette5Mid: Color.lerp(a.padPalette5Mid, b.padPalette5Mid, t)!,
      padPalette5Edge: Color.lerp(a.padPalette5Edge, b.padPalette5Edge, t)!,
      padPalette5Glow: Color.lerp(a.padPalette5Glow, b.padPalette5Glow, t)!,
      padPalette5Pressed: Color.lerp(
        a.padPalette5Pressed,
        b.padPalette5Pressed,
        t,
      )!,
      padPalette6Core: Color.lerp(a.padPalette6Core, b.padPalette6Core, t)!,
      padPalette6Mid: Color.lerp(a.padPalette6Mid, b.padPalette6Mid, t)!,
      padPalette6Edge: Color.lerp(a.padPalette6Edge, b.padPalette6Edge, t)!,
      padPalette6Glow: Color.lerp(a.padPalette6Glow, b.padPalette6Glow, t)!,
      padPalette6Pressed: Color.lerp(
        a.padPalette6Pressed,
        b.padPalette6Pressed,
        t,
      )!,
      padPalette7Core: Color.lerp(a.padPalette7Core, b.padPalette7Core, t)!,
      padPalette7Mid: Color.lerp(a.padPalette7Mid, b.padPalette7Mid, t)!,
      padPalette7Edge: Color.lerp(a.padPalette7Edge, b.padPalette7Edge, t)!,
      padPalette7Glow: Color.lerp(a.padPalette7Glow, b.padPalette7Glow, t)!,
      padPalette7Pressed: Color.lerp(
        a.padPalette7Pressed,
        b.padPalette7Pressed,
        t,
      )!,
      padShapeRadiusRatio: lerpDouble(
        a.padShapeRadiusRatio,
        b.padShapeRadiusRatio,
        t,
      )!,
      padFillRadial: lerpDouble(a.padFillRadial, b.padFillRadial, t)!,
      padShowNumber: lerpDouble(a.padShowNumber, b.padShowNumber, t)!,
      padFlash: Color.lerp(a.padFlash, b.padFlash, t)!,
      padBorder: Color.lerp(a.padBorder, b.padBorder, t)!,
      padLabel: Color.lerp(a.padLabel, b.padLabel, t)!,
      padIdleFillOpacity: lerpDouble(
        a.padIdleFillOpacity,
        b.padIdleFillOpacity,
        t,
      )!,
      padIdleBorderWidth: lerpDouble(
        a.padIdleBorderWidth,
        b.padIdleBorderWidth,
        t,
      )!,
      padIdleGlow: lerpDouble(a.padIdleGlow, b.padIdleGlow, t)!,
      padIdleBevel: lerpDouble(a.padIdleBevel, b.padIdleBevel, t)!,
      padPressedFillOpacity: lerpDouble(
        a.padPressedFillOpacity,
        b.padPressedFillOpacity,
        t,
      )!,
      padPressedFlashOpacity: lerpDouble(
        a.padPressedFlashOpacity,
        b.padPressedFlashOpacity,
        t,
      )!,
      padPressedGlow: lerpDouble(a.padPressedGlow, b.padPressedGlow, t)!,
      padPressedScale: lerpDouble(a.padPressedScale, b.padPressedScale, t)!,
      padPlayingFillOpacity: lerpDouble(
        a.padPlayingFillOpacity,
        b.padPlayingFillOpacity,
        t,
      )!,
      padPlayingFlashOpacity: lerpDouble(
        a.padPlayingFlashOpacity,
        b.padPlayingFlashOpacity,
        t,
      )!,
      padPlayingGlow: lerpDouble(a.padPlayingGlow, b.padPlayingGlow, t)!,
      padPendingOpacityMin: lerpDouble(
        a.padPendingOpacityMin,
        b.padPendingOpacityMin,
        t,
      )!,
      padDisabledOpacity: lerpDouble(
        a.padDisabledOpacity,
        b.padDisabledOpacity,
        t,
      )!,
      padSelectedBorder: Color.lerp(
        a.padSelectedBorder,
        b.padSelectedBorder,
        t,
      )!,
      padSelectedBorderWidth: lerpDouble(
        a.padSelectedBorderWidth,
        b.padSelectedBorderWidth,
        t,
      )!,
      padLoopIdleFill: Color.lerp(a.padLoopIdleFill, b.padLoopIdleFill, t)!,
      padLoopIdleFillOpacity: lerpDouble(
        a.padLoopIdleFillOpacity,
        b.padLoopIdleFillOpacity,
        t,
      )!,
      padLoopBorderWidth: lerpDouble(
        a.padLoopBorderWidth,
        b.padLoopBorderWidth,
        t,
      )!,
      padLoopIcon: Color.lerp(a.padLoopIcon, b.padLoopIcon, t)!,
      padLoopIconOpacity: lerpDouble(
        a.padLoopIconOpacity,
        b.padLoopIconOpacity,
        t,
      )!,
      padEmptyFill: UpGradient.lerp(a.padEmptyFill, b.padEmptyFill, t),
      padEmptyBorder: Color.lerp(a.padEmptyBorder, b.padEmptyBorder, t)!,
      padEmptyOpacity: lerpDouble(a.padEmptyOpacity, b.padEmptyOpacity, t)!,
      padTutorialDimOpacity: lerpDouble(
        a.padTutorialDimOpacity,
        b.padTutorialDimOpacity,
        t,
      )!,
      padTutorialHighlight: Color.lerp(
        a.padTutorialHighlight,
        b.padTutorialHighlight,
        t,
      )!,
      padTutorialFill: Color.lerp(a.padTutorialFill, b.padTutorialFill, t)!,
      padTutorialOutline: Color.lerp(
        a.padTutorialOutline,
        b.padTutorialOutline,
        t,
      )!,
      padTutorialLoopIcon: Color.lerp(
        a.padTutorialLoopIcon,
        b.padTutorialLoopIcon,
        t,
      )!,
      surfaceApp: Color.lerp(a.surfaceApp, b.surfaceApp, t)!,
      surfacePads: Color.lerp(a.surfacePads, b.surfacePads, t)!,
      surfacePage: Color.lerp(a.surfacePage, b.surfacePage, t)!,
      surfaceRaised: Color.lerp(a.surfaceRaised, b.surfaceRaised, t)!,
      surfaceRaisedHigh: Color.lerp(
        a.surfaceRaisedHigh,
        b.surfaceRaisedHigh,
        t,
      )!,
      surfaceSunken: Color.lerp(a.surfaceSunken, b.surfaceSunken, t)!,
      surfaceToolbar: Color.lerp(a.surfaceToolbar, b.surfaceToolbar, t)!,
      surfaceBankButton: Color.lerp(
        a.surfaceBankButton,
        b.surfaceBankButton,
        t,
      )!,
      surfacePadContainer: Color.lerp(
        a.surfacePadContainer,
        b.surfacePadContainer,
        t,
      )!,
      surfaceScrim: Color.lerp(a.surfaceScrim, b.surfaceScrim, t)!,
      surfaceDim: Color.lerp(a.surfaceDim, b.surfaceDim, t)!,
      surfaceOverlayDownload: Color.lerp(
        a.surfaceOverlayDownload,
        b.surfaceOverlayDownload,
        t,
      )!,
      surfaceScrimStrong: Color.lerp(
        a.surfaceScrimStrong,
        b.surfaceScrimStrong,
        t,
      )!,
      surfaceKitEditor: Color.lerp(a.surfaceKitEditor, b.surfaceKitEditor, t)!,
      surfaceSocial: Color.lerp(a.surfaceSocial, b.surfaceSocial, t)!,
      surfaceTabBar: Color.lerp(a.surfaceTabBar, b.surfaceTabBar, t)!,
      surfaceNavShadow: Color.lerp(a.surfaceNavShadow, b.surfaceNavShadow, t)!,
      borderSubtle: Color.lerp(a.borderSubtle, b.borderSubtle, t)!,
      borderDefault: Color.lerp(a.borderDefault, b.borderDefault, t)!,
      borderStrong: Color.lerp(a.borderStrong, b.borderStrong, t)!,
      borderDivider: Color.lerp(a.borderDivider, b.borderDivider, t)!,
      borderInverse: Color.lerp(a.borderInverse, b.borderInverse, t)!,
      borderDark: Color.lerp(a.borderDark, b.borderDark, t)!,
      textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t)!,
      textSecondary: Color.lerp(a.textSecondary, b.textSecondary, t)!,
      textMuted: Color.lerp(a.textMuted, b.textMuted, t)!,
      textFaint: Color.lerp(a.textFaint, b.textFaint, t)!,
      textDisabled: Color.lerp(a.textDisabled, b.textDisabled, t)!,
      textInverse: Color.lerp(a.textInverse, b.textInverse, t)!,
      textOnAccent: Color.lerp(a.textOnAccent, b.textOnAccent, t)!,
      textLink: Color.lerp(a.textLink, b.textLink, t)!,
      textSection: Color.lerp(a.textSection, b.textSection, t)!,
      textDark: Color.lerp(a.textDark, b.textDark, t)!,
      iconPrimary: Color.lerp(a.iconPrimary, b.iconPrimary, t)!,
      iconSecondary: Color.lerp(a.iconSecondary, b.iconSecondary, t)!,
      iconDisabled: Color.lerp(a.iconDisabled, b.iconDisabled, t)!,
      iconOnAccent: Color.lerp(a.iconOnAccent, b.iconOnAccent, t)!,
      accentPrimary: Color.lerp(a.accentPrimary, b.accentPrimary, t)!,
      accentPrimaryPressed: Color.lerp(
        a.accentPrimaryPressed,
        b.accentPrimaryPressed,
        t,
      )!,
      accentPrimaryMuted: Color.lerp(
        a.accentPrimaryMuted,
        b.accentPrimaryMuted,
        t,
      )!,
      accentSelected: Color.lerp(a.accentSelected, b.accentSelected, t)!,
      accentSecondary: Color.lerp(a.accentSecondary, b.accentSecondary, t)!,
      accentPreview: Color.lerp(a.accentPreview, b.accentPreview, t)!,
      accentAlert: Color.lerp(a.accentAlert, b.accentAlert, t)!,
      accentCreate: Color.lerp(a.accentCreate, b.accentCreate, t)!,
      statusSuccess: Color.lerp(a.statusSuccess, b.statusSuccess, t)!,
      statusWarning: Color.lerp(a.statusWarning, b.statusWarning, t)!,
      statusDanger: Color.lerp(a.statusDanger, b.statusDanger, t)!,
      statusInfo: Color.lerp(a.statusInfo, b.statusInfo, t)!,
      statusRecording: Color.lerp(a.statusRecording, b.statusRecording, t)!,
      brandBackground: UpGradient.lerp(a.brandBackground, b.brandBackground, t),
      focusRing: Color.lerp(a.focusRing, b.focusRing, t)!,
      focusRingWidth: lerpDouble(a.focusRingWidth, b.focusRingWidth, t)!,
      feedbackPerfect: Color.lerp(a.feedbackPerfect, b.feedbackPerfect, t)!,
      feedbackWrong: Color.lerp(a.feedbackWrong, b.feedbackWrong, t)!,
      feedbackBubble: Color.lerp(a.feedbackBubble, b.feedbackBubble, t)!,
      feedbackBubbleText: Color.lerp(
        a.feedbackBubbleText,
        b.feedbackBubbleText,
        t,
      )!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpSemantic &&
        other.transportBackground == transportBackground &&
        other.transportStopBackground == transportStopBackground &&
        other.transportStopIcon == transportStopIcon &&
        other.transportWaveformPlayed == transportWaveformPlayed &&
        other.transportWaveformUnplayed == transportWaveformUnplayed &&
        other.transportProgressTrack == transportProgressTrack &&
        other.transportProgressFill == transportProgressFill &&
        other.transportThumb == transportThumb &&
        other.transportSpeedBackground == transportSpeedBackground &&
        other.transportSpeedText == transportSpeedText &&
        other.chipBackground == chipBackground &&
        other.chipForeground == chipForeground &&
        other.chipIconBox == chipIconBox &&
        other.chipSelectedBackground == chipSelectedBackground &&
        other.chipSelectedForeground == chipSelectedForeground &&
        other.chipSelectedIconBox == chipSelectedIconBox &&
        other.chipHintBackground == chipHintBackground &&
        other.chipHintForeground == chipHintForeground &&
        other.cardBackground == cardBackground &&
        other.cardBackgroundSelected == cardBackgroundSelected &&
        other.cardBorder == cardBorder &&
        other.cardTitle == cardTitle &&
        other.cardSubtitle == cardSubtitle &&
        other.cardOverline == cardOverline &&
        other.cardSelectedIndicator == cardSelectedIndicator &&
        other.cardPlaceholder == cardPlaceholder &&
        other.cardCounter == cardCounter &&
        other.bannerScrim == bannerScrim &&
        other.bannerIndicator == bannerIndicator &&
        other.bannerIndicatorActive == bannerIndicatorActive &&
        other.sheetBackground == sheetBackground &&
        other.sheetHeader == sheetHeader &&
        other.sheetHandle == sheetHandle &&
        other.sheetItem == sheetItem &&
        other.sheetItemPressed == sheetItemPressed &&
        other.sheetItemIconBox == sheetItemIconBox &&
        other.sheetUnderline == sheetUnderline &&
        other.listItem == listItem &&
        other.listItemPressed == listItemPressed &&
        other.listSeparator == listSeparator &&
        other.badgeBackground == badgeBackground &&
        other.badgeForeground == badgeForeground &&
        other.badgeNew == badgeNew &&
        other.badgeTop == badgeTop &&
        other.badgeTopForeground == badgeTopForeground &&
        other.buttonPrimaryBackground == buttonPrimaryBackground &&
        other.buttonPrimaryForeground == buttonPrimaryForeground &&
        other.buttonPrimaryPressed == buttonPrimaryPressed &&
        other.buttonSecondaryBackground == buttonSecondaryBackground &&
        other.buttonSecondaryForeground == buttonSecondaryForeground &&
        other.buttonOutlineBorder == buttonOutlineBorder &&
        other.buttonGhostForeground == buttonGhostForeground &&
        other.buttonDangerBackground == buttonDangerBackground &&
        other.buttonDisabledBackground == buttonDisabledBackground &&
        other.buttonDisabledForeground == buttonDisabledForeground &&
        other.buttonAlertBorder == buttonAlertBorder &&
        other.buttonWhiteBackground == buttonWhiteBackground &&
        other.buttonWhiteForeground == buttonWhiteForeground &&
        other.inputBackground == inputBackground &&
        other.inputForeground == inputForeground &&
        other.inputPlaceholder == inputPlaceholder &&
        other.inputCursor == inputCursor &&
        other.inputBorder == inputBorder &&
        other.inputFocus == inputFocus &&
        other.sliderTrack == sliderTrack &&
        other.sliderFill == sliderFill &&
        other.sliderThumb == sliderThumb &&
        other.dialogBackground == dialogBackground &&
        other.dialogScrim == dialogScrim &&
        other.dialogLight == dialogLight &&
        other.dialogLightTitle == dialogLightTitle &&
        other.dialogLightText == dialogLightText &&
        other.toastBackground == toastBackground &&
        other.toastForeground == toastForeground &&
        other.meterTrack == meterTrack &&
        other.meterLow == meterLow &&
        other.meterMid == meterMid &&
        other.meterHigh == meterHigh &&
        other.meterPeak == meterPeak &&
        other.waveformActive == waveformActive &&
        other.waveformInactive == waveformInactive &&
        other.waveformSelection == waveformSelection &&
        other.waveformMarker == waveformMarker &&
        other.progressRingTrack == progressRingTrack &&
        other.progressRingFill == progressRingFill &&
        other.recordIndicator == recordIndicator &&
        other.recordTrackCard == recordTrackCard &&
        other.genreLabel == genreLabel &&
        other.genreRing == genreRing &&
        other.genreCheck == genreCheck &&
        other.genreTabSelected == genreTabSelected &&
        other.swatchRing == swatchRing &&
        other.hubOnline == hubOnline &&
        other.hubPairing == hubPairing &&
        other.hubOffline == hubOffline &&
        other.padPalette0Core == padPalette0Core &&
        other.padPalette0Mid == padPalette0Mid &&
        other.padPalette0Edge == padPalette0Edge &&
        other.padPalette0Glow == padPalette0Glow &&
        other.padPalette0Pressed == padPalette0Pressed &&
        other.padPalette1Core == padPalette1Core &&
        other.padPalette1Mid == padPalette1Mid &&
        other.padPalette1Edge == padPalette1Edge &&
        other.padPalette1Glow == padPalette1Glow &&
        other.padPalette1Pressed == padPalette1Pressed &&
        other.padPalette2Core == padPalette2Core &&
        other.padPalette2Mid == padPalette2Mid &&
        other.padPalette2Edge == padPalette2Edge &&
        other.padPalette2Glow == padPalette2Glow &&
        other.padPalette2Pressed == padPalette2Pressed &&
        other.padPalette3Core == padPalette3Core &&
        other.padPalette3Mid == padPalette3Mid &&
        other.padPalette3Edge == padPalette3Edge &&
        other.padPalette3Glow == padPalette3Glow &&
        other.padPalette3Pressed == padPalette3Pressed &&
        other.padPalette4Core == padPalette4Core &&
        other.padPalette4Mid == padPalette4Mid &&
        other.padPalette4Edge == padPalette4Edge &&
        other.padPalette4Glow == padPalette4Glow &&
        other.padPalette4Pressed == padPalette4Pressed &&
        other.padPalette5Core == padPalette5Core &&
        other.padPalette5Mid == padPalette5Mid &&
        other.padPalette5Edge == padPalette5Edge &&
        other.padPalette5Glow == padPalette5Glow &&
        other.padPalette5Pressed == padPalette5Pressed &&
        other.padPalette6Core == padPalette6Core &&
        other.padPalette6Mid == padPalette6Mid &&
        other.padPalette6Edge == padPalette6Edge &&
        other.padPalette6Glow == padPalette6Glow &&
        other.padPalette6Pressed == padPalette6Pressed &&
        other.padPalette7Core == padPalette7Core &&
        other.padPalette7Mid == padPalette7Mid &&
        other.padPalette7Edge == padPalette7Edge &&
        other.padPalette7Glow == padPalette7Glow &&
        other.padPalette7Pressed == padPalette7Pressed &&
        other.padShapeRadiusRatio == padShapeRadiusRatio &&
        other.padFillRadial == padFillRadial &&
        other.padShowNumber == padShowNumber &&
        other.padFlash == padFlash &&
        other.padBorder == padBorder &&
        other.padLabel == padLabel &&
        other.padIdleFillOpacity == padIdleFillOpacity &&
        other.padIdleBorderWidth == padIdleBorderWidth &&
        other.padIdleGlow == padIdleGlow &&
        other.padIdleBevel == padIdleBevel &&
        other.padPressedFillOpacity == padPressedFillOpacity &&
        other.padPressedFlashOpacity == padPressedFlashOpacity &&
        other.padPressedGlow == padPressedGlow &&
        other.padPressedScale == padPressedScale &&
        other.padPlayingFillOpacity == padPlayingFillOpacity &&
        other.padPlayingFlashOpacity == padPlayingFlashOpacity &&
        other.padPlayingGlow == padPlayingGlow &&
        other.padPendingOpacityMin == padPendingOpacityMin &&
        other.padDisabledOpacity == padDisabledOpacity &&
        other.padSelectedBorder == padSelectedBorder &&
        other.padSelectedBorderWidth == padSelectedBorderWidth &&
        other.padLoopIdleFill == padLoopIdleFill &&
        other.padLoopIdleFillOpacity == padLoopIdleFillOpacity &&
        other.padLoopBorderWidth == padLoopBorderWidth &&
        other.padLoopIcon == padLoopIcon &&
        other.padLoopIconOpacity == padLoopIconOpacity &&
        other.padEmptyFill == padEmptyFill &&
        other.padEmptyBorder == padEmptyBorder &&
        other.padEmptyOpacity == padEmptyOpacity &&
        other.padTutorialDimOpacity == padTutorialDimOpacity &&
        other.padTutorialHighlight == padTutorialHighlight &&
        other.padTutorialFill == padTutorialFill &&
        other.padTutorialOutline == padTutorialOutline &&
        other.padTutorialLoopIcon == padTutorialLoopIcon &&
        other.surfaceApp == surfaceApp &&
        other.surfacePads == surfacePads &&
        other.surfacePage == surfacePage &&
        other.surfaceRaised == surfaceRaised &&
        other.surfaceRaisedHigh == surfaceRaisedHigh &&
        other.surfaceSunken == surfaceSunken &&
        other.surfaceToolbar == surfaceToolbar &&
        other.surfaceBankButton == surfaceBankButton &&
        other.surfacePadContainer == surfacePadContainer &&
        other.surfaceScrim == surfaceScrim &&
        other.surfaceDim == surfaceDim &&
        other.surfaceOverlayDownload == surfaceOverlayDownload &&
        other.surfaceScrimStrong == surfaceScrimStrong &&
        other.surfaceKitEditor == surfaceKitEditor &&
        other.surfaceSocial == surfaceSocial &&
        other.surfaceTabBar == surfaceTabBar &&
        other.surfaceNavShadow == surfaceNavShadow &&
        other.borderSubtle == borderSubtle &&
        other.borderDefault == borderDefault &&
        other.borderStrong == borderStrong &&
        other.borderDivider == borderDivider &&
        other.borderInverse == borderInverse &&
        other.borderDark == borderDark &&
        other.textPrimary == textPrimary &&
        other.textSecondary == textSecondary &&
        other.textMuted == textMuted &&
        other.textFaint == textFaint &&
        other.textDisabled == textDisabled &&
        other.textInverse == textInverse &&
        other.textOnAccent == textOnAccent &&
        other.textLink == textLink &&
        other.textSection == textSection &&
        other.textDark == textDark &&
        other.iconPrimary == iconPrimary &&
        other.iconSecondary == iconSecondary &&
        other.iconDisabled == iconDisabled &&
        other.iconOnAccent == iconOnAccent &&
        other.accentPrimary == accentPrimary &&
        other.accentPrimaryPressed == accentPrimaryPressed &&
        other.accentPrimaryMuted == accentPrimaryMuted &&
        other.accentSelected == accentSelected &&
        other.accentSecondary == accentSecondary &&
        other.accentPreview == accentPreview &&
        other.accentAlert == accentAlert &&
        other.accentCreate == accentCreate &&
        other.statusSuccess == statusSuccess &&
        other.statusWarning == statusWarning &&
        other.statusDanger == statusDanger &&
        other.statusInfo == statusInfo &&
        other.statusRecording == statusRecording &&
        other.brandBackground == brandBackground &&
        other.focusRing == focusRing &&
        other.focusRingWidth == focusRingWidth &&
        other.feedbackPerfect == feedbackPerfect &&
        other.feedbackWrong == feedbackWrong &&
        other.feedbackBubble == feedbackBubble &&
        other.feedbackBubbleText == feedbackBubbleText;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    transportBackground,
    transportStopBackground,
    transportStopIcon,
    transportWaveformPlayed,
    transportWaveformUnplayed,
    transportProgressTrack,
    transportProgressFill,
    transportThumb,
    transportSpeedBackground,
    transportSpeedText,
    chipBackground,
    chipForeground,
    chipIconBox,
    chipSelectedBackground,
    chipSelectedForeground,
    chipSelectedIconBox,
    chipHintBackground,
    chipHintForeground,
    cardBackground,
    cardBackgroundSelected,
    cardBorder,
    cardTitle,
    cardSubtitle,
    cardOverline,
    cardSelectedIndicator,
    cardPlaceholder,
    cardCounter,
    bannerScrim,
    bannerIndicator,
    bannerIndicatorActive,
    sheetBackground,
    sheetHeader,
    sheetHandle,
    sheetItem,
    sheetItemPressed,
    sheetItemIconBox,
    sheetUnderline,
    listItem,
    listItemPressed,
    listSeparator,
    badgeBackground,
    badgeForeground,
    badgeNew,
    badgeTop,
    badgeTopForeground,
    buttonPrimaryBackground,
    buttonPrimaryForeground,
    buttonPrimaryPressed,
    buttonSecondaryBackground,
    buttonSecondaryForeground,
    buttonOutlineBorder,
    buttonGhostForeground,
    buttonDangerBackground,
    buttonDisabledBackground,
    buttonDisabledForeground,
    buttonAlertBorder,
    buttonWhiteBackground,
    buttonWhiteForeground,
    inputBackground,
    inputForeground,
    inputPlaceholder,
    inputCursor,
    inputBorder,
    inputFocus,
    sliderTrack,
    sliderFill,
    sliderThumb,
    dialogBackground,
    dialogScrim,
    dialogLight,
    dialogLightTitle,
    dialogLightText,
    toastBackground,
    toastForeground,
    meterTrack,
    meterLow,
    meterMid,
    meterHigh,
    meterPeak,
    waveformActive,
    waveformInactive,
    waveformSelection,
    waveformMarker,
    progressRingTrack,
    progressRingFill,
    recordIndicator,
    recordTrackCard,
    genreLabel,
    genreRing,
    genreCheck,
    genreTabSelected,
    swatchRing,
    hubOnline,
    hubPairing,
    hubOffline,
    padPalette0Core,
    padPalette0Mid,
    padPalette0Edge,
    padPalette0Glow,
    padPalette0Pressed,
    padPalette1Core,
    padPalette1Mid,
    padPalette1Edge,
    padPalette1Glow,
    padPalette1Pressed,
    padPalette2Core,
    padPalette2Mid,
    padPalette2Edge,
    padPalette2Glow,
    padPalette2Pressed,
    padPalette3Core,
    padPalette3Mid,
    padPalette3Edge,
    padPalette3Glow,
    padPalette3Pressed,
    padPalette4Core,
    padPalette4Mid,
    padPalette4Edge,
    padPalette4Glow,
    padPalette4Pressed,
    padPalette5Core,
    padPalette5Mid,
    padPalette5Edge,
    padPalette5Glow,
    padPalette5Pressed,
    padPalette6Core,
    padPalette6Mid,
    padPalette6Edge,
    padPalette6Glow,
    padPalette6Pressed,
    padPalette7Core,
    padPalette7Mid,
    padPalette7Edge,
    padPalette7Glow,
    padPalette7Pressed,
    padShapeRadiusRatio,
    padFillRadial,
    padShowNumber,
    padFlash,
    padBorder,
    padLabel,
    padIdleFillOpacity,
    padIdleBorderWidth,
    padIdleGlow,
    padIdleBevel,
    padPressedFillOpacity,
    padPressedFlashOpacity,
    padPressedGlow,
    padPressedScale,
    padPlayingFillOpacity,
    padPlayingFlashOpacity,
    padPlayingGlow,
    padPendingOpacityMin,
    padDisabledOpacity,
    padSelectedBorder,
    padSelectedBorderWidth,
    padLoopIdleFill,
    padLoopIdleFillOpacity,
    padLoopBorderWidth,
    padLoopIcon,
    padLoopIconOpacity,
    padEmptyFill,
    padEmptyBorder,
    padEmptyOpacity,
    padTutorialDimOpacity,
    padTutorialHighlight,
    padTutorialFill,
    padTutorialOutline,
    padTutorialLoopIcon,
    surfaceApp,
    surfacePads,
    surfacePage,
    surfaceRaised,
    surfaceRaisedHigh,
    surfaceSunken,
    surfaceToolbar,
    surfaceBankButton,
    surfacePadContainer,
    surfaceScrim,
    surfaceDim,
    surfaceOverlayDownload,
    surfaceScrimStrong,
    surfaceKitEditor,
    surfaceSocial,
    surfaceTabBar,
    surfaceNavShadow,
    borderSubtle,
    borderDefault,
    borderStrong,
    borderDivider,
    borderInverse,
    borderDark,
    textPrimary,
    textSecondary,
    textMuted,
    textFaint,
    textDisabled,
    textInverse,
    textOnAccent,
    textLink,
    textSection,
    textDark,
    iconPrimary,
    iconSecondary,
    iconDisabled,
    iconOnAccent,
    accentPrimary,
    accentPrimaryPressed,
    accentPrimaryMuted,
    accentSelected,
    accentSecondary,
    accentPreview,
    accentAlert,
    accentCreate,
    statusSuccess,
    statusWarning,
    statusDanger,
    statusInfo,
    statusRecording,
    brandBackground,
    focusRing,
    focusRingWidth,
    feedbackPerfect,
    feedbackWrong,
    feedbackBubble,
    feedbackBubbleText,
  ]);
}
