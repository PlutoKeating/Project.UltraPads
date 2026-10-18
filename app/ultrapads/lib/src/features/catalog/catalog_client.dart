import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'catalog_models.dart';

/// 目录接口请求超时。
const defaultCatalogTimeout = Duration(seconds: _timeoutSeconds);
const _timeoutSeconds = 20;

/// 取访问令牌；未登录返回 null。
typedef TokenProvider = Future<String?> Function();

/// 下载的取消开关（调用 [cancel] 后，进行中的 [CatalogClient.download] 抛 [CatalogCancelled]）。
class DownloadCancel {
  bool _cancelled = false;
  final _listeners = <void Function()>[];

  bool get cancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final l in _listeners) {
      l();
    }
  }

  void _onCancel(void Function() l) => _listeners.add(l);
}

class _DigestSink implements Sink<Digest> {
  late Digest digest;
  @override
  void add(Digest data) => digest = data;
  @override
  void close() {}
}

/// 官方站点的目录与账号数据接口（docs/API.md §7）。
class CatalogClient {
  CatalogClient({
    required this.base,
    required http.Client client,
    this.token,
    this.timeout = defaultCatalogTimeout,
  }) : _client = client;

  final Uri base;
  final http.Client _client;
  final TokenProvider? token;
  final Duration timeout;

  Uri _uri(String path, [Map<String, String>? query]) => base.replace(
    path:
        '${base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path}$path',
    queryParameters: query == null || query.isEmpty ? null : query,
  );

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final t = auth ? await token?.call() : null;
    return {
      'Accept': 'application/json',
      'User-Agent': 'ultrapads-app',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  /// 登录后带上令牌（匿名接口也带：下载会因此记入历史）。
  Future<Map<String, String>> _optionalAuth() => _headers(auth: true);

  Future<Object?> _json(Future<http.Response> Function() send) async {
    final http.Response res;
    try {
      res = await send().timeout(timeout);
    } on TimeoutException {
      throw const CatalogException('network');
    } on SocketException {
      throw const CatalogException('network');
    } on http.ClientException {
      throw const CatalogException('network');
    }
    if (res.statusCode == 204 || res.bodyBytes.isEmpty) {
      _check(res, null);
      return null;
    }
    Object? body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      if (res.statusCode >= 400) {
        throw CatalogException(
          'http_${res.statusCode}',
          status: res.statusCode,
        );
      }
      throw const CatalogException('bad_response');
    }
    _check(res, body);
    return body;
  }

  void _check(http.Response res, Object? body) {
    if (res.statusCode < 400) return;
    final err = body is Map ? body['error'] : null;
    throw CatalogException(
      err is String ? err : 'http_${res.statusCode}',
      status: res.statusCode,
      message: body is Map ? body['message'] as String? : null,
    );
  }

  Map<String, Object?> _object(Object? body) {
    if (body is Map) return body.cast<String, Object?>();
    throw const CatalogException('bad_response');
  }

  // ------------------------------------------------------------ 目录

  Future<CatalogPage> list(
    CatalogQuery query, {
    String? cursor,
    int limit = 30,
  }) async {
    final body = _object(
      await _json(
        () async => _client.get(
          _uri('/api/catalog', query.toParams(cursor: cursor, limit: limit)),
          headers: await _headers(),
        ),
      ),
    );
    final items = body['items'];
    return CatalogPage(
      items: [
        if (items is List)
          for (final e in items)
            if (e is Map) CatalogItem.fromJson(e.cast<String, Object?>()),
      ],
      nextCursor: body['next_cursor'] as String?,
      total: (body['total'] as num?)?.toInt() ?? 0,
    );
  }

  Future<CatalogFacets> facets() async => CatalogFacets.fromJson(
    _object(
      await _json(
        () async =>
            _client.get(_uri('/api/catalog/facets'), headers: await _headers()),
      ),
    ),
  );

  Future<CatalogItem> item(String id) async => CatalogItem.fromJson(
    _object(
      await _json(
        () async => _client.get(
          _uri('/api/catalog/${Uri.encodeComponent(id)}'),
          headers: await _headers(),
        ),
      ),
    ),
  );

  /// 下载 `.upkit` 到 [dest]，边收边算 SHA-256；与 [item] 的 `sha256` 不符则删除文件并抛
  /// `hash_mismatch`。[onProgress] 的第二个参数在服务端没给长度时为 null。
  Future<void> download(
    CatalogItem item,
    File dest, {
    void Function(int received, int? total)? onProgress,
    DownloadCancel? cancel,
  }) async {
    final req = http.Request(
      'GET',
      _uri('/api/catalog/${Uri.encodeComponent(item.id)}/download'),
    )..headers.addAll(await _optionalAuth());
    final http.StreamedResponse res;
    try {
      res = await _client.send(req).timeout(timeout);
    } on TimeoutException {
      throw const CatalogException('network');
    } on SocketException {
      throw const CatalogException('network');
    } on http.ClientException {
      throw const CatalogException('network');
    }
    if (res.statusCode != 200) {
      final bytes = await res.stream.toBytes();
      Object? body;
      try {
        body = jsonDecode(utf8.decode(bytes));
      } catch (_) {}
      throw CatalogException(
        body is Map && body['error'] is String
            ? body['error']! as String
            : 'http_${res.statusCode}',
        status: res.statusCode,
      );
    }

    if (cancel?.cancelled ?? false) throw const CatalogCancelled();
    await dest.parent.create(recursive: true);
    final sink = dest.openWrite();
    final digestOut = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestOut);
    final total = res.contentLength ?? (item.size > 0 ? item.size : null);
    var received = 0;
    final done = Completer<void>();
    late final StreamSubscription<List<int>> sub;
    sub = res.stream.listen(
      (chunk) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      },
      onError: (Object e) {
        if (!done.isCompleted) {
          done.completeError(const CatalogException('network'));
        }
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    cancel?._onCancel(() {
      sub.cancel();
      if (!done.isCompleted) done.completeError(const CatalogCancelled());
    });
    try {
      await done.future;
      await sink.flush();
    } catch (_) {
      await sub.cancel();
      await sink.close();
      if (await dest.exists()) await dest.delete();
      rethrow;
    }
    await sink.close();
    hasher.close();
    final got = digestOut.digest.toString();
    if (item.sha256.isNotEmpty && got != item.sha256) {
      await dest.delete();
      throw const CatalogException('hash_mismatch');
    }
  }

  // ------------------------------------------------------------ 账号数据（需要登录）

  Future<MeState> meState() async => MeState.fromJson(
    _object(
      await _json(
        () async => _client.get(
          _uri('/api/me/state'),
          headers: await _headers(auth: true),
        ),
      ),
    ),
  );

  Future<void> putFavorite(String id) =>
      _send('PUT', '/api/me/favorites/${Uri.encodeComponent(id)}');

  Future<void> deleteFavorite(String id) =>
      _send('DELETE', '/api/me/favorites/${Uri.encodeComponent(id)}');

  Future<void> postRecent(String id) =>
      _send('POST', '/api/me/recent', body: {'id': id});

  Future<void> deleteAccountData() => _send('DELETE', '/api/me');

  Future<void> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    await _json(() async {
      final req = http.Request(method, _uri(path))
        ..headers.addAll(await _headers(auth: true));
      if (body != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      return http.Response.fromStream(await _client.send(req));
    });
  }
}
