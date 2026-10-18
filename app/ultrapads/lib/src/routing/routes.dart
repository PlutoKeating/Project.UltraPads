/// 路由路径（集中定义，避免散落字面量）。
abstract final class Routes {
  static const perform = '/';
  static const onboarding = '/onboarding';
  static const kits = '/kits';
  static String kit(String id) => '/kits/${Uri.encodeComponent(id)}';
  static const editor = '/edit';
  static const micSampler = '/edit/mic';
  static const tracks = '/tracks';
  static const skinEditor = '/skins/editor';
  static const settings = '/settings';
  static const hub = '/hub';
  static const gallery = '/dev/gallery';
}
