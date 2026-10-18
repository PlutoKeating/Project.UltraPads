import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;

import 'auth_models.dart';

/// 登录完成后浏览器标签页上显示的文字（回环回调页），由调用方按当前语言传入。
class LoopbackPage {
  const LoopbackPage({required this.title, required this.body});
  final String title;
  final String body;
}

/// state 随机数的字节数。
const stateBytes = 16;

/// 等待浏览器完成授权的最长时间（网络请求超时，不是视觉时长）。
const defaultLoopbackTimeout = Duration(minutes: _loopbackMinutes);
const _loopbackMinutes = 5;

/// 交互式登录：返回一组令牌。
abstract interface class AuthFlow {
  Future<AuthTokens> signIn(AuthConfig config, {LoopbackPage? page});

  /// 取消正在等待的登录（桌面回环监听）。
  void cancel();
}

/// OIDC 发现文档里用到的端点。
class OidcEndpoints {
  const OidcEndpoints({
    required this.authorization,
    required this.token,
    this.userinfo,
  });
  final Uri authorization;
  final Uri token;
  final Uri? userinfo;

  static Future<OidcEndpoints> discover(
    http.Client client,
    AuthConfig config,
  ) async {
    final res = await client.get(config.discovery);
    if (res.statusCode != 200) {
      throw AuthFailure('discovery ${res.statusCode}');
    }
    final doc = jsonDecode(res.body) as Map<String, Object?>;
    Uri req(String k) => Uri.parse(doc[k] as String);
    return OidcEndpoints(
      authorization: req('authorization_endpoint'),
      token: req('token_endpoint'),
      userinfo: doc['userinfo_endpoint'] is String
          ? req('userinfo_endpoint')
          : null,
    );
  }
}

/// 用刷新令牌换新的访问令牌（公共客户端，不带密钥）。两个平台共用这一条路径。
Future<AuthTokens> refreshTokens(
  http.Client client,
  AuthConfig config,
  String refreshToken, {
  OidcEndpoints? endpoints,
  DateTime Function() now = DateTime.now,
}) async {
  final ep = endpoints ?? await OidcEndpoints.discover(client, config);
  final res = await client.post(
    ep.token,
    body: {
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': config.clientId,
    },
  );
  Map<String, Object?> json = const {};
  try {
    final decoded = jsonDecode(res.body);
    if (decoded is Map) json = decoded.cast<String, Object?>();
  } catch (_) {}
  if (res.statusCode != 200) {
    final err = '${json['error'] ?? res.statusCode}';
    throw AuthFailure(
      err,
      invalidGrant: err == 'invalid_grant' || err == 'unauthorized_client',
    );
  }
  final expiresIn = json['expires_in'];
  return AuthTokens(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String?,
    idToken: json['id_token'] as String?,
    expiresAt: expiresIn is num
        ? now().toUtc().add(Duration(seconds: expiresIn.toInt()))
        : null,
  );
}

/// 向 userinfo 端点取资料（ID 令牌里没有邮箱时的补充）。
Future<Map<String, Object?>> fetchUserinfo(
  http.Client client,
  AuthConfig config,
  String accessToken,
) async {
  final ep = await OidcEndpoints.discover(client, config);
  final url = ep.userinfo;
  if (url == null) return const {};
  final res = await client.get(
    url,
    headers: {'Authorization': 'Bearer $accessToken'},
  );
  if (res.statusCode != 200) return const {};
  final d = jsonDecode(res.body);
  return d is Map ? d.cast<String, Object?>() : const {};
}

/// Android / iOS / macOS：flutter_appauth（Custom Tabs / ASWebAuthenticationSession），
/// 授权码 + PKCE，回调是自定义 scheme。
class AppAuthFlow implements AuthFlow {
  AppAuthFlow({FlutterAppAuth? appAuth})
    : _appAuth = appAuth ?? const FlutterAppAuth();
  final FlutterAppAuth _appAuth;

  @override
  Future<AuthTokens> signIn(AuthConfig config, {LoopbackPage? page}) async {
    try {
      final r = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          config.clientId,
          config.mobileRedirect,
          discoveryUrl: config.discovery.toString(),
          scopes: config.scopes,
        ),
      );
      final access = r.accessToken;
      if (access == null) throw const AuthFailure('no_access_token');
      return AuthTokens(
        accessToken: access,
        refreshToken: r.refreshToken,
        idToken: r.idToken,
        expiresAt: r.accessTokenExpirationDateTime?.toUtc(),
      );
    } on FlutterAppAuthUserCancelledException {
      throw const AuthCancelled();
    } on FlutterAppAuthPlatformException catch (e) {
      throw AuthFailure(e.platformErrorDetails.error ?? e.message ?? 'appauth');
    }
  }

  @override
  void cancel() {}
}

/// 桌面（Linux 等）：flutter_appauth 没有 Linux 实现，所以走 RFC 8252 的回环方案——
/// 在 127.0.0.1 随机端口起一个一次性 HTTP 监听，用系统浏览器打开授权页，浏览器重定向回来后
/// 用 oauth2 包做授权码 + PKCE 的换取。Hydra 对 `http://127.0.0.1/callback` 这类回环地址
/// 允许任意端口（clients.json 登记的是不带端口的形式）。
class LoopbackAuthFlow implements AuthFlow {
  LoopbackAuthFlow({
    required this.openBrowser,
    http.Client? client,
    this.timeout = defaultLoopbackTimeout,
  }) : _client = client ?? http.Client();

  /// 用系统浏览器打开授权地址（url_launcher）。
  final Future<bool> Function(Uri url) openBrowser;
  final http.Client _client;
  final Duration timeout;
  Completer<Uri>? _callback;

  @override
  void cancel() {
    final c = _callback;
    if (c != null && !c.isCompleted) c.completeError(const AuthCancelled());
  }

  @override
  Future<AuthTokens> signIn(AuthConfig config, {LoopbackPage? page}) async {
    final endpoints = await OidcEndpoints.discover(_client, config);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final callback = _callback = Completer<Uri>();
    final redirect = Uri(
      scheme: 'http',
      host: server.address.address,
      port: server.port,
      path: '/callback',
    );
    final grant = oauth2.AuthorizationCodeGrant(
      config.clientId,
      endpoints.authorization,
      endpoints.token,
      httpClient: _client,
    );
    final state = _randomState();
    final url = grant.getAuthorizationUrl(
      redirect,
      scopes: config.scopes,
      state: state,
    );

    final sub = server.listen((req) async {
      if (req.uri.path != '/callback') {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }
      final ok = !req.uri.queryParameters.containsKey('error');
      req.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(_pageHtml(page, ok));
      await req.response.close();
      if (!callback.isCompleted) callback.complete(req.uri);
    });

    try {
      if (!await openBrowser(url)) {
        throw const AuthFailure('browser_unavailable');
      }
      final uri = await callback.future.timeout(
        timeout,
        onTimeout: () => throw const AuthCancelled(),
      );
      final params = uri.queryParameters;
      if (params['error'] == 'access_denied') throw const AuthCancelled();
      final cl = await grant.handleAuthorizationResponse(params);
      final cred = cl.credentials;
      return AuthTokens(
        accessToken: cred.accessToken,
        refreshToken: cred.refreshToken,
        idToken: cred.idToken,
        expiresAt: cred.expiration?.toUtc(),
      );
    } on oauth2.AuthorizationException catch (e) {
      throw AuthFailure(e.error, invalidGrant: e.error == 'invalid_grant');
    } on FormatException catch (e) {
      // state 不匹配、缺少 code 等：回调不是我们发起的那次授权
      throw AuthFailure(e.message);
    } finally {
      await sub.cancel();
      await server.close(force: true);
      _callback = null;
    }
  }

  /// 防 CSRF 的随机 state（授权请求发出、回调时核对）。
  static String _randomState() {
    final r = Random.secure();
    return base64Url
        .encode(List<int>.generate(stateBytes, (_) => r.nextInt(256)))
        .replaceAll('=', '');
  }

  String _pageHtml(LoopbackPage? page, bool ok) {
    final title = _escape(page?.title ?? 'UltraPads');
    final body = _escape(page?.body ?? (ok ? 'OK' : 'Error'));
    return '<!doctype html><meta charset="utf-8"><title>$title</title>'
        '<body style="font-family:sans-serif;text-align:center;margin-top:20vh">'
        '<h2>$title</h2><p>$body</p></body>';
  }

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
