// 私有素材注入：把 private-assets/ 中 UI 需要的素材复制进
// app/ultrapads/assets/private_manifest/（扁平命名，被该目录内的 .gitignore 忽略），
// 并生成清单 injected.json。没有私有素材时应用回退到开源占位资源，构建照常通过。
//
// 支持两个来源，按优先级：
//   1. ios —— private-assets/compat-ios/（App Store 4.7.0，第一复刻基准）
//   2. apk —— private-assets/compat/（APK 3.7.6，补充：Lottie、Uni Sans 等）
// 运行时 PrivateAssets 按 manifest 的 `priority` 顺序解析同一逻辑素材。
//
// 用法（仓库根目录）：
//   dart run tools/assets/inject_private_assets.dart                # 注入全部可用来源
//   dart run tools/assets/inject_private_assets.dart --only ios     # 只注入某个来源
//   dart run tools/assets/inject_private_assets.dart --clean        # 删除已注入文件
//   dart run tools/assets/inject_private_assets.dart --check        # 报告状态
//   dart run tools/assets/inject_private_assets.dart --root <dir>   # 自定义 private-assets 根
//
// 内置 Kit：ios 来源的 `kit`（audio/kits/**）与 `data`（data/initial/*.json）类别就是
// 4.7.0 的 6 个内置 Kit 及其目录/教程。清单的 `privateKits` 记录它们在原目录结构中的
// 相对路径 → 打包资源路径；应用首次启动时把这些文件还原到临时目录，再交给曲库的
// 原 App 素材导入器（`library_import`，compat-ios 来源）导入，见
// app/ultrapads/lib/src/library/first_run.dart。
//
// 为什么是扁平目录：pubspec 声明的资源目录必须存在，且目录声明不递归。
// assets/private_manifest/ 是入库目录（只含占位清单 manifest.json 与 .gitignore），
// 永远存在；注入文件以 `<来源>_<类别>__<相对路径用 __ 连接>` 平铺其中，一条声明即可全部打包。
import 'dart:convert';
import 'dart:io';

const _target = 'app/ultrapads/assets/private_manifest';
const _bundlePrefix = 'assets/private_manifest';
const _manifestName = 'injected.json';
const _trackedFiles = {'manifest.json', '.gitignore'};

/// 不注入的 UI 包（付费墙、广告/隐私弹窗等，ADR-0001 #4）。
const _excludedPackages = {
  'GetPremium',
  'GdprPortrait',
  'GdprScreen',
  'IdfaLandscape',
  'IdfaPortrait',
  'LDFA',
  'VendorSplash',
};

class _Category {
  const _Category(this.name, this.dir, this.filter, {this.recursive = false});
  final String name;
  final String dir;
  final bool Function(String relPath) filter;
  final bool recursive;
}

class _Source {
  const _Source(this.id, this.dir, this.categories);
  final String id;
  final String dir;
  final List<_Category> categories;
}

bool _png(String p) => p.endsWith('.png') && !p.endsWith('.9.png');
bool _allowedPackage(String p) {
  final file = p.split('/').last;
  final pkg = file.contains('__') ? file.split('__').first : '';
  return !_excludedPackages.contains(pkg);
}

final _sources = <_Source>[
  _Source('ios', 'compat-ios', [
    _Category('icon', 'images/icons', (p) => _png(p) && _allowedPackage(p)),
    _Category('ui', 'images/ui', (p) => _png(p) && _allowedPackage(p)),
    _Category('bg', 'images/backgrounds', (p) => _png(p) && _allowedPackage(p)),
    _Category('skin', 'images/skins', _png, recursive: true),
    _Category('appicon', 'images/appicon', _png),
    _Category('font', 'fonts', (p) => p.toLowerCase().endsWith('.ttf')),
    _Category(
      'kit',
      'audio/kits',
      (p) => RegExp(r'\.(ogg|mp3|wav|txt)$').hasMatch(p),
      recursive: true,
    ),
    _Category(
      'sfx',
      'audio/sfx',
      (p) => RegExp(r'\.(wav|mp3|ogg)$').hasMatch(p) && !p.contains('splash'),
    ),
    _Category('data', 'data/initial', (p) => p.endsWith('.json')),
    _Category(
      'particle',
      'animations/particles',
      (p) => p.endsWith('.png') || p.endsWith('.plist'),
    ),
  ]),
  _Source('apk', 'compat', [
    _Category('lottie', 'animations/lottie', (p) => p.endsWith('.json')),
    _Category('icon', 'images/icons', _png),
    _Category('skin', 'images/skins', _png),
    _Category('pad', 'images/pads', _png),
    _Category('bg', 'images/backgrounds', _png),
    _Category('font', 'fonts', (p) => p.toLowerCase().endsWith('.ttf')),
    _Category(
      'kit',
      'audio/kits',
      (p) => p.endsWith('.wav') || p.endsWith('.txt'),
      recursive: true,
    ),
  ]),
];

String _flat(String source, String category, String rel) =>
    '${source}_${category}__${rel.replaceAll('/', '__').replaceAll(' ', '_')}';

void main(List<String> args) {
  final root = _repoRoot();
  var assetsRoot = '${root.path}/private-assets';
  final ri = args.indexOf('--root');
  if (ri >= 0 && ri + 1 < args.length) assetsRoot = args[ri + 1];
  final oi = args.indexOf('--only');
  final only = oi >= 0 && oi + 1 < args.length ? args[oi + 1] : null;

  final target = Directory('${root.path}/$_target');
  if (!target.existsSync()) target.createSync(recursive: true);

  if (args.contains('--clean')) {
    stdout.writeln('removed ${_clean(target)} injected file(s) from $_target');
    return;
  }
  if (args.contains('--check')) {
    final m = File('${target.path}/$_manifestName');
    if (!m.existsSync()) {
      stdout.writeln(
        'private assets: NOT injected (open-source placeholders in use)',
      );
      return;
    }
    final json = jsonDecode(m.readAsStringSync()) as Map<String, dynamic>;
    stdout.writeln('private assets: ${json['priority']} ${json['counts']}');
    return;
  }

  _clean(target);
  final entries = <String, String>{};
  // 内置 Kit：原目录结构中的相对路径（相对 compat-ios 根）→ 打包资源路径。
  final privateKits = <String, String>{};
  final counts = <String, Map<String, int>>{};
  final priority = <String>[];
  for (final src in _sources) {
    if (only != null && src.id != only) continue;
    final base = Directory('$assetsRoot/${src.dir}');
    if (!base.existsSync()) {
      stdout.writeln('skip ${src.id}: ${base.path} not found');
      continue;
    }
    priority.add(src.id);
    final c = counts[src.id] = {};
    for (final cat in src.categories) {
      final dir = Directory('${base.path}/${cat.dir}');
      if (!dir.existsSync()) continue;
      final files =
          dir
              .listSync(recursive: cat.recursive)
              .whereType<File>()
              .map((f) => (f, f.path.substring(dir.path.length + 1)))
              .where((e) => cat.filter(e.$2))
              .toList()
            ..sort((a, b) => a.$2.compareTo(b.$2));
      for (final (f, rel) in files) {
        final flat = _flat(src.id, cat.name, rel);
        f.copySync('${target.path}/$flat');
        entries['${src.id}/${cat.name}/$rel'] = '$_bundlePrefix/$flat';
        if (src.id == 'ios' && (cat.name == 'kit' || cat.name == 'data')) {
          privateKits['${cat.dir}/$rel'] = '$_bundlePrefix/$flat';
        }
      }
      c[cat.name] = files.length;
    }
  }

  if (priority.isEmpty) {
    stderr.writeln(
      'no private asset source found under $assetsRoot; '
      'nothing injected, the app will use open-source placeholders.',
    );
    return;
  }

  final manifest = {
    'schema': 2,
    'available': true,
    'priority': priority,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'counts': counts,
    'entries': entries,
    if (privateKits.isNotEmpty)
      'privateKits': {'source': 'compat-ios', 'files': privateKits},
  };
  File(
    '${target.path}/$_manifestName',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
  stdout.writeln('injected ${entries.length} file(s) into $_target: $counts');
}

int _clean(Directory target) {
  var n = 0;
  for (final f in target.listSync().whereType<File>()) {
    if (_trackedFiles.contains(f.uri.pathSegments.last)) continue;
    f.deleteSync();
    n++;
  }
  return n;
}

Directory _repoRoot() {
  var d = Directory.current.absolute;
  while (true) {
    if (File('${d.path}/justfile').existsSync() &&
        Directory('${d.path}/app/ultrapads').existsSync()) {
      return d;
    }
    final parent = d.parent;
    if (parent.path == d.path) {
      stderr.writeln('run from inside the UltraPads repository');
      exit(2);
    }
    d = parent;
  }
}
