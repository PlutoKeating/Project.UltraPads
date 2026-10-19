import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// 本地分轨用的 ONNX 模型（htdemucs，4 轨：鼓 / 贝斯 / 其他 / 人声）。
///
/// 模型不随应用分发：用户同意后从 Hugging Face 下载（MIT 许可，Meta Demucs 权重，ONNX 导出：adowu），
/// 按 sha256 校验后放在应用数据目录。docs/adr/0005-catalog-and-accounts.md 第 9 项。
class SeparationModel {
  const SeparationModel({
    required this.url,
    required this.sha256,
    required this.bytes,
    required this.fileName,
  });

  final String url;
  final String sha256;
  final int bytes;
  final String fileName;
}

const demucsModel = SeparationModel(
  url:
      'https://huggingface.co/adowu/htdemucs-onnx/resolve/main/htdemucs_fp16weights.onnx',
  sha256: 'd05c269d0178d2a72ad484b10b11dd370193fc923201c3b27a99f848745db70a',
  bytes: 165612636,
  fileName: 'htdemucs_fp16weights.onnx',
);

/// 建立连接的超时。
const modelConnectTimeout = Duration(seconds: _connectTimeoutSeconds);
const _connectTimeoutSeconds = 30;

class ModelDownloadCancelled implements Exception {
  const ModelDownloadCancelled();
}

class ModelDownloadFailed implements Exception {
  const ModelDownloadFailed(this.reason);

  /// `network` | `http_<状态码>` | `checksum`
  final String reason;

  @override
  String toString() => 'ModelDownloadFailed($reason)';
}

/// 下载取消开关。
class ModelCancel {
  bool _cancelled = false;
  bool get cancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class _DigestSink implements Sink<Digest> {
  late Digest digest;
  @override
  void add(Digest data) => digest = data;
  @override
  void close() {}
}

/// 模型的下载、校验与存放。
class ModelStore {
  ModelStore({required this.dir, http.Client? client, this.model = demucsModel})
    : _client = client ?? http.Client();

  /// 存放目录（通常是应用数据目录下的 `models`）。
  final Future<Directory> Function() dir;
  final SeparationModel model;
  final http.Client _client;

  Future<File> _file() async {
    final d = await dir();
    return File('${d.path}${Platform.pathSeparator}${model.fileName}');
  }

  /// 已安装的模型文件（大小对得上才算数；下载时已校验过 sha256），否则 null。
  Future<File?> installed() async {
    final f = await _file();
    return await f.exists() && await f.length() == model.bytes ? f : null;
  }

  Future<void> remove() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }

  /// 下载并校验；成功返回最终文件。取消抛 [ModelDownloadCancelled]，失败抛 [ModelDownloadFailed]。
  Future<File> download({
    void Function(int received, int total)? onProgress,
    ModelCancel? cancel,
  }) async {
    final dest = await _file();
    final part = File('${dest.path}.part');
    await dest.parent.create(recursive: true);
    final http.StreamedResponse res;
    try {
      res = await _client
          .send(http.Request('GET', Uri.parse(model.url)))
          .timeout(modelConnectTimeout);
    } on TimeoutException {
      throw const ModelDownloadFailed('network');
    } on SocketException {
      throw const ModelDownloadFailed('network');
    } on http.ClientException {
      throw const ModelDownloadFailed('network');
    }
    if (res.statusCode != 200) {
      await res.stream.drain<void>();
      throw ModelDownloadFailed('http_${res.statusCode}');
    }
    final sink = part.openWrite();
    final out = _DigestSink();
    final hasher = sha256.startChunkedConversion(out);
    var received = 0;
    try {
      await for (final chunk in res.stream) {
        if (cancel?.cancelled ?? false) throw const ModelDownloadCancelled();
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        onProgress?.call(received, model.bytes);
      }
    } on ModelDownloadCancelled {
      await sink.close();
      if (await part.exists()) await part.delete();
      rethrow;
    } catch (_) {
      await sink.close();
      if (await part.exists()) await part.delete();
      throw const ModelDownloadFailed('network');
    }
    await sink.close();
    hasher.close();
    if (out.digest.toString() != model.sha256 || received != model.bytes) {
      await part.delete();
      throw const ModelDownloadFailed('checksum');
    }
    await part.rename(dest.path);
    return dest;
  }
}
