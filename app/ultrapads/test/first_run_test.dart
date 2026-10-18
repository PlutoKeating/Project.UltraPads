import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ultrapads/src/assets/private_assets.dart';
import 'package:ultrapads/src/library/first_run.dart';
import 'package:up_engine/up_engine.dart';

KitSummary _k(String id, String name) => KitSummary(id: id, name: name);

/// 记录导入调用、曲库初始为空的 Mock。
class _EmptyLibraryEngine extends MockEngineClient {
  _EmptyLibraryEngine() : super(realtime: false);

  final imported = <String>[];
  bool empty = true;

  @override
  Future<List<KitSummary>> libraryListKits() async =>
      empty ? const [] : super.libraryListKits();

  @override
  Future<ImportReport> libraryImportBytes(String name, List<int> bytes) {
    imported.add(name);
    empty = false;
    return super.libraryImportBytes(name, bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default kit: original Sunset first, then CC0 starter, then first', () {
    expect(pickDefaultKit(const []), isNull);
    expect(
      pickDefaultKit([_k('a', 'Alpha'), _k(starterKitId, 'S')])!.id,
      starterKitId,
    );
    expect(
      pickDefaultKit([
        _k(starterKitId, 'UltraPads Starter'),
        _k('x', 'Sunset'),
      ])!.id,
      'x',
    );
    expect(pickDefaultKit([_k('a', 'Alpha'), _k('b', 'Beta')])!.id, 'a');
  });

  test('bundled CC0 kits are identical to content/kits', () {
    final repo = Directory('../../content/kits');
    final bundled = Directory(bundledKitsDir);
    final names = repo
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.upkit'))
        .map((f) => f.uri.pathSegments.last)
        .toList();
    expect(names, isNotEmpty);
    for (final n in names) {
      expect(
        File('${bundled.path}$n').readAsBytesSync(),
        File('${repo.path}/$n').readAsBytesSync(),
        reason: '$n: 运行 cp content/kits/*.upkit app/ultrapads/assets/kits/',
      );
    }
  });

  test(
    'first run imports bundled kits into an empty library and loads one',
    () async {
      SharedPreferences.setMockInitialValues({});
      final engine = _EmptyLibraryEngine();
      await FirstRunImporter(
        engine: engine,
        prefs: await SharedPreferences.getInstance(),
        assets: PrivateAssets.none,
        tempDir: () async => Directory.systemTemp.createTemp('up-first-run'),
      ).run();
      expect(engine.imported, contains('ultrapads-starter.upkit'));
      expect(engine.snapshot().kit, isNotNull);
    },
  );
}
