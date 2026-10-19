import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ultrapads/src/account/auth_flow.dart';
import 'package:ultrapads/src/account/auth_models.dart';
import 'package:ultrapads/src/features/catalog/catalog_models.dart';

/// 测试用的目录条目（`sha256` 与 [fixtureFile] 的字节一致）。
CatalogItem fixtureItem(
  String id, {
  String title = 'Dusk Run',
  String artist = 'UltraPads',
  String license = 'CC0-1.0',
  double bpm = 112,
  List<String> genres = const ['house'],
  String attribution = '',
  String origin = 'synth',
}) {
  final bytes = fixtureFile(id);
  return CatalogItem(
    id: id,
    title: title,
    artist: artist,
    description: 'A short loop pack.',
    origin: origin,
    license: LicenseInfo.of(license),
    licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
    attribution: attribution.isEmpty
        ? '“$title” by $artist, ${LicenseInfo.of(license).badge}'
        : attribution,
    sourceUrl: 'https://example.invalid/$id',
    bpm: bpm,
    genres: genres,
    groupCount: 4,
    padCount: 44,
    durationSecs: 17.1,
    size: bytes.length,
    sha256: sha256.convert(bytes).toString(),
    updatedAtMs: 1760000000000,
  );
}

Uint8List fixtureFile(String id) =>
    Uint8List.fromList(utf8.encode('upkit:$id:${'x' * 4096}'));

/// 记录下来的一次请求。
class RecordedRequest {
  RecordedRequest(
    this.method,
    this.uri,
    this.authorization,
    this.body, {
    this.headers = const {},
    this.contentLength,
  });
  final String method;
  final Uri uri;
  final String? authorization;
  final String body;
  final Map<String, String> headers;
  final int? contentLength;
  String get path => uri.path;
}

/// 按 docs/API.md §7 行为实现的假服务：目录（搜索 / 许可证 / 曲风 / BPM / 排序 / 分页）、
/// 详情、下载、账号数据。
class FakeSite {
  FakeSite(this.items, {this.pageSize = 2});

  final List<CatalogItem> items;
  final int pageSize;
  final requests = <RecordedRequest>[];
  final favorites = <String>{};
  final recent = <String>[];

  /// 用户上传（docs/API.md §7.5）：本人的条目、文件、举报。
  final uploads = <String, Map<String, Object?>>{};
  final uploadFiles = <String, String>{};
  final reports = <Map<String, Object?>>[];
  var _uploadSeq = 0;

  /// 达到后 `POST /api/me/uploads` 返回 429。
  int uploadQuota = 50;

  /// 设为非 null 时，`PUT .../file` 以该状态码失败。
  int? failUploadFileWith;

  /// 设为非 null 时，所有请求都以该状态码失败。
  int? failWith;

  /// 下载时是否篡改内容（校验失败）。
  bool corruptDownloads = false;

  /// 覆盖下载内容（默认 [fixtureFile]）。
  final overrides = <String, Uint8List>{};

  http.Client client() => MockClient.streaming((req, body) async {
    final text = utf8.decode(await body.expand((e) => e).toList());
    requests.add(
      RecordedRequest(
        req.method,
        req.url,
        req.headers['Authorization'],
        text,
        headers: req.headers,
        contentLength: req.contentLength,
      ),
    );
    if (failWith != null) return _json({'error': 'down'}, failWith!);
    return _handle(req, text);
  });

  http.StreamedResponse _json(Object? body, [int status = 200]) {
    final bytes = body == null ? <int>[] : utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
      contentLength: bytes.length,
      headers: {'content-type': 'application/json'},
    );
  }

  http.StreamedResponse _handle(http.BaseRequest req, String body) {
    final p = req.url.path;
    final auth = req.headers['Authorization'];
    if (p == '/api/catalog' && req.method == 'GET') return _list(req.url);
    if (p == '/api/catalog/facets') {
      Map<String, int> count(Iterable<String> v) {
        final m = <String, int>{};
        for (final e in v) {
          m[e] = (m[e] ?? 0) + 1;
        }
        return m;
      }

      List<Map<String, Object>> facets(Map<String, int> m) => [
        for (final e in m.entries) {'id': e.key, 'count': e.value},
      ];
      return _json({
        'licenses': facets(count(items.map((i) => i.license.id))),
        'genres': facets(count(items.expand((i) => i.genres))),
        'origins': facets(count(items.map((i) => i.origin))),
      });
    }
    final rep = RegExp(r'^/api/catalog/([^/]+)/report$').firstMatch(p);
    if (rep != null && req.method == 'POST') {
      if (auth == null) return _json({'error': 'missing_token'}, 401);
      final id = Uri.decodeComponent(rep.group(1)!);
      if (!items.any((i) => i.id == id && i.origin == 'ugc')) {
        return _json({'error': 'not_found'}, 404);
      }
      if (uploads.containsKey(id)) return _json({'error': 'own_item'}, 400);
      reports.add({
        'id': id,
        ...(jsonDecode(body) as Map).cast<String, Object?>(),
      });
      return _json({'ok': true}, 202);
    }
    final m = RegExp(r'^/api/catalog/([^/]+)(/download)?$').firstMatch(p);
    if (m != null) {
      final item = items.where((i) => i.id == m.group(1)).firstOrNull;
      if (item == null) return _json({'error': 'not_found'}, 404);
      if (m.group(2) == null) return _json(item.toJson());
      var bytes = overrides[item.id] ?? fixtureFile(item.id);
      if (corruptDownloads) {
        bytes = Uint8List.fromList(bytes.reversed.toList());
      }
      return http.StreamedResponse(
        Stream.fromIterable([
          bytes.sublist(0, bytes.length ~/ 2),
          bytes.sublist(bytes.length ~/ 2),
        ]),
        200,
        contentLength: bytes.length,
        headers: {'x-digest': 'sha256:${item.sha256}'},
      );
    }
    if (p.startsWith('/api/me')) {
      if (auth == null) return _json({'error': 'missing_token'}, 401);
      if (p.startsWith('/api/me/uploads')) return _uploads(req, body);
      if (p == '/api/me/state') {
        return _json({
          'favorites': favorites.toList(),
          'recent': [
            for (final (i, id) in recent.reversed.indexed)
              {'id': id, 'at_ms': 1760000000000 - i},
          ],
          'downloads': <Object>[],
        });
      }
      final f = RegExp(r'^/api/me/favorites/([^/]+)$').firstMatch(p);
      if (f != null) {
        final id = Uri.decodeComponent(f.group(1)!);
        if (!items.any((i) => i.id == id)) {
          return _json({'error': 'not_found'}, 404);
        }
        if (req.method == 'PUT') favorites.add(id);
        if (req.method == 'DELETE') favorites.remove(id);
        return _json(null, 204);
      }
      if (p == '/api/me/recent' && req.method == 'POST') {
        recent.add((jsonDecode(body) as Map)['id'] as String);
        return _json(null, 204);
      }
    }
    return _json({'error': 'not_found'}, 404);
  }

  http.StreamedResponse _uploads(http.BaseRequest req, String body) {
    final p = req.url.path;
    if (p == '/api/me/uploads') {
      if (req.method == 'GET') {
        return _json({'items': uploads.values.toList()});
      }
      if (req.method == 'POST') {
        final j = (jsonDecode(body) as Map).cast<String, Object?>();
        for (final k in ['title', 'credit', 'license', 'source_declaration']) {
          if ('${j[k] ?? ''}'.trim().isEmpty) {
            return _json({'error': 'invalid_$k'}, 400);
          }
        }
        if (uploads.length >= uploadQuota) {
          return _json({'error': 'quota_exceeded'}, 429);
        }
        final id = 'ugc-${(++_uploadSeq).toRadixString(16).padLeft(16, '0')}';
        uploads[id] = {
          'id': id,
          'title': j['title'],
          'artist': j['credit'],
          'credit': j['credit'],
          'attribution': j['credit'],
          'origin': 'ugc',
          'license': j['license'],
          'source_declaration': j['source_declaration'],
          'visibility': 'private',
          'moderation': 'active',
          'status': 'draft',
          'size': null,
          'sha256': null,
        };
        return _json(uploads[id], 201);
      }
    }
    final m = RegExp(
      r'^/api/me/uploads/([^/]+)(/file|/download)?$',
    ).firstMatch(p);
    final id = m == null ? null : Uri.decodeComponent(m.group(1)!);
    final up = id == null ? null : uploads[id];
    if (up == null) return _json({'error': 'not_found'}, 404);
    switch ((req.method, m!.group(2))) {
      case ('GET', null):
        return _json(up);
      case ('PATCH', null):
        final j = (jsonDecode(body) as Map).cast<String, Object?>();
        if (up['moderation'] == 'taken_down') {
          return _json({'error': 'taken_down'}, 403);
        }
        if (j['visibility'] == 'public' && up['status'] != 'published') {
          return _json({'error': 'no_file'}, 409);
        }
        up.addAll(j);
        return _json(up);
      case ('DELETE', null):
        uploads.remove(id);
        uploadFiles.remove(id);
        return _json(null, 204);
      case ('PUT', '/file'):
        if (failUploadFileWith != null) {
          return _json({'error': 'upload_failed'}, failUploadFileWith!);
        }
        if (req.contentLength == null) {
          return _json({'error': 'length_required'}, 411);
        }
        uploadFiles[id!] = body;
        up
          ..['status'] = 'published'
          ..['size'] = req.contentLength
          ..['sha256'] = req.headers['X-Sha256'] ?? '';
        return _json(up);
      case ('GET', '/download'):
        final bytes = utf8.encode(uploadFiles[id] ?? '');
        return http.StreamedResponse(
          Stream.value(bytes),
          200,
          contentLength: bytes.length,
        );
    }
    return _json({'error': 'not_found'}, 404);
  }

  http.StreamedResponse _list(Uri u) {
    final q = u.queryParameters;
    var list = items.toList();
    final text = (q['q'] ?? '').toLowerCase();
    if (text.isNotEmpty) {
      list = list
          .where((i) => '${i.title} ${i.artist}'.toLowerCase().contains(text))
          .toList();
    }
    final lic = (q['license'] ?? '').split(',').where((s) => s.isNotEmpty);
    if (lic.isNotEmpty) {
      list = list.where((i) => lic.contains(i.license.id)).toList();
    }
    if (q['origin'] != null) {
      list = list.where((i) => i.origin == q['origin']).toList();
    }
    if (q['genre'] != null) {
      list = list.where((i) => i.genres.contains(q['genre'])).toList();
    }
    final min = int.tryParse(q['bpm_min'] ?? '');
    final max = int.tryParse(q['bpm_max'] ?? '');
    if (min != null) list = list.where((i) => i.bpm >= min).toList();
    if (max != null) list = list.where((i) => i.bpm <= max).toList();
    switch (q['sort']) {
      case 'bpm':
        list.sort((a, b) => a.bpm.compareTo(b.bpm));
      case 'title':
        list.sort((a, b) => a.title.compareTo(b.title));
    }
    final start = int.tryParse(q['cursor'] ?? '') ?? 0;
    final page = list.skip(start).take(pageSize).toList();
    final next = start + pageSize < list.length ? '${start + pageSize}' : null;
    return _json({
      'items': [for (final i in page) i.toJson()],
      'next_cursor': next,
      'total': list.length,
    });
  }
}

/// 临时目录（下载文件落在这里）。
Directory tempDir() {
  final d = Directory.systemTemp.createTempSync('up-catalog-test');
  addTearDownDir(d);
  return d;
}

final _dirs = <Directory>[];
void addTearDownDir(Directory d) => _dirs.add(d);
void cleanTempDirs() {
  for (final d in _dirs) {
    if (d.existsSync()) d.deleteSync(recursive: true);
  }
  _dirs.clear();
}

String fakeJwt(Map<String, Object?> claims) {
  String enc(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${enc({'alg': 'none'})}.${enc(claims)}.sig';
}

/// 立即成功（或按 [result] 失败）的登录方式，不打开浏览器。
class FakeAuthFlow implements AuthFlow {
  FakeAuthFlow([Object? result])
    : result =
          result ??
          AuthTokens(
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            idToken: fakeJwt({'sub': 'user-1', 'email': 'pluto@example.test'}),
            expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          );
  Object result;
  int calls = 0;
  LoopbackPage? page;

  @override
  Future<AuthTokens> signIn(AuthConfig config, {LoopbackPage? page}) async {
    calls++;
    this.page = page;
    final r = result;
    if (r is AuthTokens) return r;
    throw r;
  }

  @override
  void cancel() {}
}

/// 三个覆盖不同许可证 / 曲风 / BPM 的条目。
List<CatalogItem> sampleItems() => [
  fixtureItem('synth-dusk-run'),
  fixtureItem(
    'album-river',
    title: 'River',
    artist: 'Tom McKenzie',
    license: 'CC-BY-SA-4.0',
    bpm: 96,
    genres: ['rock'],
  ),
  fixtureItem(
    'online-neon',
    title: 'Neon Tide',
    artist: 'ccMixter',
    license: 'CC-BY-NC-4.0',
    bpm: 140,
    genres: ['edm'],
  ),
];
