import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ultrapads/src/engine/engine_bootstrap.dart';
import 'package:ultrapads/src/routing/router.dart';
import 'package:ultrapads/src/routing/routes.dart';
import 'package:ultrapads/src/state/engine_state.dart';
import 'package:ultrapads/src/state/settings_state.dart';
import 'package:ultrapads/src/update/apk_installer.dart';
import 'package:ultrapads/src/update/update_controller.dart';
import 'package:up_engine/up_engine.dart';

import 'harness.dart';

UpdateInfo _info(UpdateInstallMode mode, {bool available = true}) => UpdateInfo(
  current: '0.1.0',
  latest: '0.2.0',
  available: available,
  notesUrl: 'https://example.invalid/notes',
  installMode: mode,
  assetName: 'ultrapads-0.2.0-test',
  assetSize: 1000,
);

class _FakeInstaller implements ApkInstaller {
  bool allowed = true;
  int settingsOpened = 0;
  final List<String> installed = [];

  @override
  Future<bool> canInstall() async => allowed;

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<void> install(String path) async => installed.add(path);
}

Future<(ProviderContainer, MockEngineClient, _FakeInstaller, List<int>)>
_container(UpdateInfo? update) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final engine = MockEngineClient(realtime: false, availableUpdate: update);
  final installer = _FakeInstaller();
  final exits = <int>[];
  final c = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      engineBootProvider.overrideWithValue(EngineBoot(engine)),
      apkInstallerProvider.overrideWithValue(installer),
      appExitProvider.overrideWithValue(() => exits.add(0)),
    ],
  );
  addTearDown(c.dispose);
  return (c, engine, installer, exits);
}

/// 列表标题与按钮会转成大写：按不区分大小写匹配。
Finder _text(String text) => find.byWidgetPredicate(
  (w) => w is Text && w.data?.toLowerCase() == text.toLowerCase(),
);

Future<void> _drain() => Future<void>.delayed(Duration.zero);

void main() {
  test('up to date when nothing newer', () async {
    final (c, _, _, _) = await _container(null);
    await c.read(updateProvider.notifier).check();
    expect(c.read(updateProvider).phase, UpdatePhase.upToDate);
  });

  test('auto check is skipped for the mock engine', () async {
    final (c, _, _, _) = await _container(_info(UpdateInstallMode.selfUpdate));
    await c.read(updateProvider.notifier).autoCheck();
    expect(c.read(updateProvider).phase, UpdatePhase.idle);
  });

  test('Linux: download → apply → restart relaunches and exits', () async {
    final (c, engine, _, exits) = await _container(
      _info(UpdateInstallMode.selfUpdate),
    );
    final ctrl = c.read(updateProvider.notifier);
    await ctrl.check();
    expect(c.read(updateProvider).phase, UpdatePhase.available);
    ctrl.start();
    for (var i = 0; i < 10; i++) {
      await _drain();
    }
    expect(c.read(updateProvider).phase, UpdatePhase.ready);
    expect(engine.appliedUpdates, ['/tmp/ultrapads-0.2.0-test']);
    expect(await ctrl.finish(), isTrue);
    expect(engine.relaunches, 1);
    expect(exits, [0]);
  });

  test('Android: asks for the install permission, then installs', () async {
    final (c, engine, installer, exits) = await _container(
      _info(UpdateInstallMode.apkInstaller),
    );
    installer.allowed = false;
    final ctrl = c.read(updateProvider.notifier);
    await ctrl.check();
    ctrl.start();
    for (var i = 0; i < 10; i++) {
      await _drain();
    }
    expect(c.read(updateProvider).phase, UpdatePhase.ready);
    expect(installer.settingsOpened, 1);
    expect(installer.installed, isEmpty);

    installer.allowed = true;
    expect(await ctrl.finish(), isTrue);
    expect(installer.installed, ['/tmp/ultrapads-0.2.0-test']);
    expect(engine.appliedUpdates, isEmpty);
    expect(exits, isEmpty);
  });

  test('manual installs never download', () async {
    final (c, _, _, _) = await _container(_info(UpdateInstallMode.manual));
    final ctrl = c.read(updateProvider.notifier);
    await ctrl.check();
    ctrl.start();
    await _drain();
    expect(c.read(updateProvider).phase, UpdatePhase.available);
  });

  testWidgets('settings shows the version and offers the update', (t) async {
    // 足够高，设置页整页（含「关于」）都在视口内，不需要滚动
    final h = await pumpApp(
      t,
      size: const Size(414, 2400),
      engine: MockEngineClient(
        realtime: false,
        appVersion: '0.1.0',
        availableUpdate: _info(UpdateInstallMode.selfUpdate),
      ),
    );
    h.container.read(routerProvider).push(Routes.settings);
    await settle(t);
    expect(_text('Version 0.1.0'), findsOneWidget);

    await t.tap(_text('Check for updates'));
    await settle(t);
    expect(_text('Version 0.2.0 is available'), findsOneWidget);
    expect(_text("What's new"), findsOneWidget);

    await t.tap(_text('Update'));
    await settle(t);
    expect(_text('Restart to finish'), findsOneWidget);
  });
}
