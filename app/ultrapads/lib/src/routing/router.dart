import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_fx/up_fx.dart';
import 'package:up_tokens/up_tokens.dart';

import '../features/design_gallery/design_gallery_page.dart';
import '../features/editor/editor_page.dart';
import '../features/hub/hub_page.dart';
import '../features/library/kit_detail_page.dart';
import '../features/library/library_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/perform/perform_page.dart';
import '../features/recorder/mic_sampler_page.dart';
import '../features/settings/settings_page.dart';
import '../features/skins/skin_editor_page.dart';
import '../features/tracks/tracks_page.dart';
import '../state/settings_state.dart';
import 'routes.dart';
import 'wide_body.dart';

/// 子页从右侧推入（APK motion.pushRight，300ms → token page.push）。
CustomTransitionPage<T> pushPage<T>(GoRouterState s, Widget child) =>
    CustomTransitionPage<T>(
      key: s.pageKey,
      child: child,
      transitionDuration: UpPageTokens.push,
      reverseTransitionDuration: UpPageTokens.push,
      transitionsBuilder: (context, a, b, child) {
        if (FxMotion.reduce(context)) return child;
        final curve = CurvedAnimation(parent: a, curve: UpPageTokens.pushCurve);
        return SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        );
      },
    );

/// 曲库、编辑器等全屏面板从底部滑入（APK motion.sheetUp → token sheet.enter）。
CustomTransitionPage<T> sheetPage<T>(GoRouterState s, Widget child) =>
    CustomTransitionPage<T>(
      key: s.pageKey,
      child: child,
      transitionDuration: UpSheetTokens.enter,
      reverseTransitionDuration: UpSheetTokens.exit,
      transitionsBuilder: (context, a, b, child) {
        if (FxMotion.reduce(context)) return child;
        final curve = CurvedAnimation(parent: a, curve: UpSheetTokens.curve);
        return SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        );
      },
    );

/// `--dart-define=UP_GALLERY=true`：启动直接进入设计画廊。
const bool galleryFlag = bool.fromEnvironment('UP_GALLERY');

/// 开发 / 截图用：启动直接打开某个路由（仍遵守引导重定向）。
/// `--dart-define=UP_ROUTE=/kits`，或桌面运行时的环境变量 `ULTRAPADS_ROUTE`。
String get routeFlag {
  const defined = String.fromEnvironment('UP_ROUTE');
  if (defined.isNotEmpty || kIsWeb) return defined;
  return Platform.environment['ULTRAPADS_ROUTE'] ?? '';
}

final routerProvider = Provider<GoRouter>((ref) {
  final onboarded = ValueNotifier(ref.read(settingsProvider).onboarded);
  ref.listen(
    settingsProvider.select((s) => s.onboarded),
    (_, v) => onboarded.value = v,
  );
  ref.onDispose(onboarded.dispose);
  final route = routeFlag;
  return GoRouter(
    initialLocation: galleryFlag
        ? Routes.gallery
        : (route.isNotEmpty ? route : Routes.perform),
    refreshListenable: onboarded,
    redirect: (context, state) {
      if (state.matchedLocation == Routes.gallery) return null;
      final atOnboarding = state.matchedLocation == Routes.onboarding;
      if (!onboarded.value && !atOnboarding) return Routes.onboarding;
      if (onboarded.value && atOnboarding) return Routes.perform;
      return null;
    },
    routes: [
      GoRoute(path: Routes.perform, builder: (c, s) => const PerformPage()),
      GoRoute(
        path: Routes.onboarding,
        pageBuilder: (c, s) => NoTransitionPage(child: const OnboardingPage()),
      ),
      GoRoute(
        path: Routes.kits,
        pageBuilder: (c, s) =>
            sheetPage(s, const WideBody(child: LibraryPage())),
        routes: [
          GoRoute(
            path: ':id',
            pageBuilder: (c, s) => pushPage(
              s,
              WideBody(
                gutter: UpTheme.of(c).colors.surfacePads,
                child: KitDetailPage(kitId: s.pathParameters['id']!),
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.editor,
        pageBuilder: (c, s) => sheetPage(
          s,
          const WideBody(
            gutter: UpPrimitiveColors.swatchMediumPink,
            child: EditorPage(),
          ),
        ),
        routes: [
          GoRoute(
            path: 'mic',
            pageBuilder: (c, s) =>
                pushPage(s, const WideBody(child: MicSamplerPage())),
          ),
        ],
      ),
      GoRoute(
        path: Routes.tracks,
        pageBuilder: (c, s) => pushPage(s, const WideBody(child: TracksPage())),
      ),
      GoRoute(
        path: Routes.skinEditor,
        pageBuilder: (c, s) => pushPage(
          s,
          WideBody(child: SkinEditorPage(skinId: s.uri.queryParameters['id'])),
        ),
      ),
      GoRoute(
        path: Routes.settings,
        pageBuilder: (c, s) =>
            pushPage(s, const WideBody(child: SettingsPage())),
      ),
      GoRoute(
        path: Routes.hub,
        pageBuilder: (c, s) => pushPage(s, const WideBody(child: HubPage())),
      ),
      GoRoute(
        path: Routes.gallery,
        pageBuilder: (c, s) => pushPage(
          s,
          DesignGalleryPage(
            initialTab: int.tryParse(s.uri.queryParameters['tab'] ?? '') ?? 0,
            initialSkin: s.uri.queryParameters['skin'],
          ),
        ),
      ),
    ],
  );
});
