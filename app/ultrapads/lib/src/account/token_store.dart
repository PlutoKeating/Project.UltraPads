import 'dart:convert';
import 'dart:io';

import 'auth_models.dart';

/// 令牌的持久化。
abstract interface class TokenStore {
  Future<AuthTokens?> read();
  Future<void> write(AuthTokens tokens);
  Future<void> clear();
}

/// 内存实现（测试；或持久化不可用时的降级）。
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._tokens]);
  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;
  @override
  Future<void> write(AuthTokens tokens) async => _tokens = tokens;
  @override
  Future<void> clear() async => _tokens = null;
}

/// 应用私有目录里的 JSON 文件，权限 0600（仅所有者可读写），写入走「临时文件 → rename」。
///
/// 不用 flutter_secure_storage：它的 Linux 实现依赖 libsecret 与桌面 keyring，
/// 会给 Linux 发布包新增系统库依赖，且无 keyring 的环境（精简桌面、SSH）读写会失败。
/// 令牌文件落在 Android 应用沙盒（其他应用不可读）与 Linux 的 `~/.local/share/<app>` 下。
class FileTokenStore implements TokenStore {
  FileTokenStore(this._directory);

  /// 解析存放目录（通常是 `getApplicationSupportDirectory`）。
  final Future<Directory> Function() _directory;

  static const fileName = 'account.json';

  Future<File> _file() async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<AuthTokens?> read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      return AuthTokens.fromJson(jsonDecode(await f.readAsString()));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(tokens.toJson()), flush: true);
    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['600', tmp.path]);
      } catch (_) {
        // 没有 chmod（极简环境）：沿用目录本身的私有权限
      }
    }
    await tmp.rename(f.path);
  }

  @override
  Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
