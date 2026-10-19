import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../features/catalog/catalog_client.dart';
import '../features/catalog/catalog_models.dart';
import 'ugc_models.dart';

/// 上传的取消开关（调用 [cancel] 后，进行中的 [UgcClient.uploadFile] 抛 [CatalogCancelled]）。
class UploadCancel {
  bool _cancelled = false;
  bool get cancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// 用户上传与举报接口（docs/API.md §7.5），复用 [CatalogClient] 的站点地址、令牌与错误模型。
class UgcClient {
  UgcClient(this._api);

  final CatalogClient _api;

  Future<Map<String, String>> _jsonHeaders() async => {
    ...await _api.authHeaders(),
    'Content-Type': 'application/json',
  };

  Map<String, Object?> _object(Object? body) {
    if (body is Map) return body.cast<String, Object?>();
    throw const CatalogException('bad_response');
  }

  String _path(String id, [String suffix = '']) =>
      '/api/me/uploads/${Uri.encodeComponent(id)}$suffix';

  Future<List<UploadItem>> list() async {
    final body = _object(
      await _api.request(
        () async => _api.httpClient.get(
          _api.resolve('/api/me/uploads'),
          headers: await _api.authHeaders(),
        ),
      ),
    );
    final items = body['items'];
    return [
      if (items is List)
        for (final e in items)
          if (e is Map) UploadItem.fromJson(e.cast<String, Object?>()),
    ];
  }

  /// 建条目（恒为私有、还没有文件）。
  Future<UploadItem> create(UploadDraft draft) async => UploadItem.fromJson(
    _object(
      await _api.request(
        () async => _api.httpClient.post(
          _api.resolve('/api/me/uploads'),
          headers: await _jsonHeaders(),
          body: jsonEncode(draft.toJson()),
        ),
      ),
    ),
  );

  /// 改元数据或可见性（`visibility: private|public`）。
  Future<UploadItem> patch(String id, Map<String, Object?> fields) async =>
      UploadItem.fromJson(
        _object(
          await _api.request(
            () async => _api.httpClient.patch(
              _api.resolve(_path(id)),
              headers: await _jsonHeaders(),
              body: jsonEncode(fields),
            ),
          ),
        ),
      );

  Future<void> delete(String id) async {
    await _api.request(
      () async => _api.httpClient.delete(
        _api.resolve(_path(id)),
        headers: await _api.authHeaders(),
      ),
    );
  }

  /// 流式上传 `.upkit`（Worker 纯透传）：带 `Content-Length` 与 `X-Sha256`；
  /// [onProgress] 报告已交给网络层的字节数。超过 [maxUploadBytes] 直接抛 `too_large`（不发请求）。
  Future<UploadItem> uploadFile(
    String id,
    File file, {
    String? sha256Hex,
    void Function(int sent, int total)? onProgress,
    UploadCancel? cancel,
  }) async {
    final total = await file.length();
    if (total > maxUploadBytes) {
      throw const CatalogException('too_large', status: 413);
    }
    final req = http.StreamedRequest('PUT', _api.resolve(_path(id, '/file')))
      ..contentLength = total
      ..headers.addAll(await _api.authHeaders())
      ..headers['Content-Type'] = 'application/zip';
    if (sha256Hex != null) req.headers['X-Sha256'] = sha256Hex;

    var sent = 0;
    Stream<List<int>> body() async* {
      await for (final chunk in file.openRead()) {
        if (cancel?.cancelled ?? false) throw const CatalogCancelled();
        sent += chunk.length;
        onProgress?.call(sent, total);
        yield chunk;
      }
    }

    final response = _api.httpClient.send(req);
    Object? pumpError;
    final pump = req.sink
        .addStream(body())
        .then((_) => req.sink.close())
        .catchError((Object e) {
          pumpError = e;
          return req.sink.close();
        });
    final http.Response res;
    try {
      res = await http.Response.fromStream(await response);
    } on SocketException {
      await pump;
      throw const CatalogException('network');
    } on http.ClientException {
      await pump;
      if (pumpError is CatalogCancelled) throw const CatalogCancelled();
      throw const CatalogException('network');
    } catch (e) {
      await pump;
      if (e is CatalogCancelled || pumpError is CatalogCancelled) {
        throw const CatalogCancelled();
      }
      rethrow;
    }
    await pump;
    if (pumpError is CatalogCancelled) throw const CatalogCancelled();
    return UploadItem.fromJson(_object(await _api.request(() async => res)));
  }

  /// 本人取回自己的文件（含私有，换设备用）。
  Future<void> downloadOwn(
    UploadItem item,
    File dest, {
    void Function(int received, int? total)? onProgress,
    DownloadCancel? cancel,
  }) => _api.download(
    item.item,
    dest,
    onProgress: onProgress,
    cancel: cancel,
    path: _path(item.id, '/download'),
  );

  /// 举报一条公开的用户上传（同一用户对同一条目只计一次）。
  Future<void> report(
    String catalogId,
    ReportReason reason, {
    String? note,
  }) async {
    await _api.request(
      () async => _api.httpClient.post(
        _api.resolve('/api/catalog/${Uri.encodeComponent(catalogId)}/report'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'reason': reason.name,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        }),
      ),
    );
  }
}

/// 文件的 SHA-256（十六进制小写），流式计算，不把整个文件读进内存。
Future<String> sha256OfFile(File f) async =>
    (await sha256.bind(f.openRead()).first).toString();
