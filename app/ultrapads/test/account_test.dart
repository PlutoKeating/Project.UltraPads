import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ultrapads/src/account/account_state.dart';
import 'package:ultrapads/src/account/auth_flow.dart';
import 'package:ultrapads/src/account/auth_models.dart';
import 'package:ultrapads/src/account/token_store.dart';
import 'package:ultrapads/src/config/app_links.dart';

import 'catalog_fixtures.dart';

final _config = AuthConfig(
  issuer: Uri.parse('https://id.test/'),
  clientId: 'ultrapads-app',
);

String _jwt(Map<String, Object?> claims) {
  String enc(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${enc({'alg': 'none'})}.${enc(claims)}.sig';
}

/// 假的 Ory Hydra：发现文档、授权码换令牌、刷新令牌、userinfo。
class FakeIdp {
  final tokenRequests = <Map<String, String>>[];
  String refreshError = '';
  var counter = 0;

  http.Client client() => MockClient((req) async {
    final p = req.url.path;
    if (p == '/.well-known/openid-configuration') {
      return http.Response(
        jsonEncode({
          'authorization_endpoint': 'https://id.test/oauth2/auth',
          'token_endpoint': 'https://id.test/oauth2/token',
          'userinfo_endpoint': 'https://id.test/userinfo',
        }),
        200,
      );
    }
    if (p == '/oauth2/token') {
      final form = req.bodyFields;
      tokenRequests.add(form);
      if (form['grant_type'] == 'refresh_token' && refreshError.isNotEmpty) {
        return http.Response(jsonEncode({'error': refreshError}), 400);
      }
      counter++;
      return http.Response(
        jsonEncode({
          'access_token': 'access-$counter',
          'refresh_token': form['grant_type'] == 'refresh_token'
              ? null
              : 'refresh-$counter',
          'id_token': _jwt({'sub': 'u1', 'email': 'a@b.test'}),
          'token_type': 'bearer',
          'expires_in': 3600,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (p == '/userinfo') {
      return http.Response(
        jsonEncode({'sub': 'u1', 'email': 'info@b.test', 'name': 'U One'}),
        200,
      );
    }
    return http.Response('', 404);
  });
}

class _FakeFlow implements AuthFlow {
  _FakeFlow(this.result);
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

ProviderContainer _container({
  TokenStore? store,
  AuthFlow? flow,
  http.Client? http,
}) {
  final c = ProviderContainer(
    overrides: [
      authConfigProvider.overrideWithValue(_config),
      tokenStoreProvider.overrideWithValue(store ?? MemoryTokenStore()),
      ?flow == null ? null : authFlowProvider.overrideWithValue(flow),
      ?http == null ? null : authHttpClientProvider.overrideWithValue(http),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> _settled(ProviderContainer c) async {
  c.read(accountProvider);
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  tearDown(cleanTempDirs);

  test('AppLinks: site override and defaults', () {
    final l = AppLinks.fromJson({
      'siteBase': 'https://s.test',
      'idIssuer': 'https://id.test/',
      'idClientId': 'ultrapads-app',
    });
    expect(l.siteBase, Uri.parse('https://s.test'));
    expect(l.idIssuer, Uri.parse('https://id.test/'));
    expect(AppLinks.fromJson(const {}).idClientId, 'ultrapads-app');
  });

  test(
    'AuthConfig builds the discovery URL with or without trailing slash',
    () {
      expect(
        _config.discovery.toString(),
        'https://id.test/.well-known/openid-configuration',
      );
      final c = AuthConfig(issuer: Uri.parse('https://id.test'), clientId: 'x');
      expect(
        c.discovery.toString(),
        'https://id.test/.well-known/openid-configuration',
      );
    },
  );

  test(
    'signed out at start; sign-in stores tokens and reads the profile',
    () async {
      final store = MemoryTokenStore();
      final flow = _FakeFlow(
        AuthTokens(
          accessToken: 'a',
          refreshToken: 'r',
          idToken: _jwt({'sub': 'u1', 'email': 'a@b.test'}),
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
      );
      final c = _container(store: store, flow: flow);
      await _settled(c);
      expect(c.read(accountProvider).status, AccountStatus.signedOut);

      await c
          .read(accountProvider.notifier)
          .signIn(
            page: const LoopbackPage(title: 'T', body: 'B'),
          );
      final s = c.read(accountProvider);
      expect(s.signedIn, isTrue);
      expect(s.profile?.email, 'a@b.test');
      expect(s.profile?.label, 'a@b.test');
      expect(flow.page?.title, 'T');
      expect((await store.read())?.refreshToken, 'r');
      expect(await c.read(accountProvider.notifier).accessToken(), 'a');

      await c.read(accountProvider.notifier).signOut();
      expect(c.read(accountProvider).status, AccountStatus.signedOut);
      expect(await store.read(), isNull);
      expect(await c.read(accountProvider.notifier).accessToken(), isNull);
    },
  );

  test('missing email in the ID token falls back to userinfo', () async {
    final idp = FakeIdp();
    final flow = _FakeFlow(
      AuthTokens(
        accessToken: 'a',
        idToken: _jwt({'sub': 'u1'}),
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
    );
    final c = _container(flow: flow, http: idp.client());
    await _settled(c);
    await c.read(accountProvider.notifier).signIn();
    expect(c.read(accountProvider).profile?.email, 'info@b.test');
  });

  test(
    'cancel returns to signed out without an error; failure sets one',
    () async {
      final flow = _FakeFlow(const AuthCancelled());
      final c = _container(flow: flow);
      await _settled(c);
      await c.read(accountProvider.notifier).signIn();
      expect(c.read(accountProvider).status, AccountStatus.signedOut);
      expect(c.read(accountProvider).error, AccountError.none);

      flow.result = const AuthFailure('boom');
      await c.read(accountProvider.notifier).signIn();
      expect(c.read(accountProvider).error, AccountError.failed);
    },
  );

  test('restores a saved session at start', () async {
    final store = MemoryTokenStore(
      AuthTokens(
        accessToken: 'a',
        refreshToken: 'r',
        idToken: _jwt({'sub': 'u9', 'email': 'x@y.test'}),
      ),
    );
    final c = _container(store: store);
    await _settled(c);
    expect(c.read(accountProvider).signedIn, isTrue);
    expect(c.read(accountProvider).profile?.sub, 'u9');
  });

  test(
    'expired access token is refreshed once for concurrent callers',
    () async {
      final idp = FakeIdp();
      final store = MemoryTokenStore(
        AuthTokens(
          accessToken: 'old',
          refreshToken: 'r1',
          idToken: _jwt({'sub': 'u1'}),
          expiresAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 5),
          ),
        ),
      );
      final c = _container(store: store, http: idp.client());
      await _settled(c);
      final ctrl = c.read(accountProvider.notifier);
      final tokens = await Future.wait([
        ctrl.accessToken(),
        ctrl.accessToken(),
      ]);
      expect(tokens, ['access-1', 'access-1']);
      expect(idp.tokenRequests.length, 1);
      expect(idp.tokenRequests.single['grant_type'], 'refresh_token');
      expect(idp.tokenRequests.single['client_id'], 'ultrapads-app');
      final saved = await store.read();
      expect(saved?.accessToken, 'access-1');
      // 服务端没发新的刷新令牌：沿用旧的
      expect(saved?.refreshToken, 'r1');
    },
  );

  test(
    'invalid_grant on refresh signs the user out; a network error keeps the session',
    () async {
      final idp = FakeIdp()..refreshError = 'invalid_grant';
      final expired = AuthTokens(
        accessToken: 'old',
        refreshToken: 'r1',
        idToken: _jwt({'sub': 'u1'}),
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      );
      final store = MemoryTokenStore(expired);
      final c = _container(store: store, http: idp.client());
      await _settled(c);
      expect(await c.read(accountProvider.notifier).accessToken(), isNull);
      expect(c.read(accountProvider).status, AccountStatus.signedOut);
      expect(await store.read(), isNull);

      final offline = _container(
        store: MemoryTokenStore(expired),
        http: MockClient((_) async => throw const SocketException('down')),
      );
      await _settled(offline);
      expect(await offline.read(accountProvider.notifier).accessToken(), 'old');
      expect(offline.read(accountProvider).signedIn, isTrue);
    },
  );

  test('FileTokenStore round-trips and clears (0600 file)', () async {
    final dir = tempDir();
    final store = FileTokenStore(() async => dir);
    expect(await store.read(), isNull);
    await store.write(
      AuthTokens(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.utc(2030),
      ),
    );
    final back = await store.read();
    expect(back?.accessToken, 'a');
    expect(back?.expiresAt, DateTime.utc(2030));
    if (!Platform.isWindows) {
      final mode = File('${dir.path}/account.json').statSync().mode & 0x1ff;
      expect(mode, 0x180); // 0600
    }
    await store.clear();
    expect(await store.read(), isNull);
  });

  group('LoopbackAuthFlow (desktop)', () {
    /// 用裸 socket 模拟浏览器被重定向回本机回环地址。
    Future<String> hit(Uri redirect, Map<String, String> params) async {
      final socket = await Socket.connect(redirect.host, redirect.port);
      final target = redirect.replace(queryParameters: params);
      socket.write(
        'GET ${target.path}?${target.query} HTTP/1.1\r\n'
        'Host: ${redirect.host}:${redirect.port}\r\nConnection: close\r\n\r\n',
      );
      final out = await utf8.decoder.bind(socket).join();
      await socket.close();
      return out;
    }

    test('authorization code + PKCE round trip against a fake IdP', () async {
      final idp = FakeIdp();
      late Uri authUrl;
      String? browserReply;
      final flow = LoopbackAuthFlow(
        client: idp.client(),
        openBrowser: (url) async {
          authUrl = url;
          final redirect = Uri.parse(url.queryParameters['redirect_uri']!);
          unawaited(
            hit(redirect, {
              'code': 'the-code',
              'state': url.queryParameters['state']!,
            }).then((r) => browserReply = r),
          );
          return true;
        },
      );
      final tokens = await flow.signIn(
        _config,
        page: const LoopbackPage(title: 'Signed in', body: 'Close this tab'),
      );
      expect(tokens.accessToken, 'access-1');
      expect(tokens.refreshToken, 'refresh-1');
      expect(jwtClaims(tokens.idToken)['email'], 'a@b.test');
      expect(tokens.isFresh(DateTime.now()), isTrue);

      // 授权请求：授权码 + PKCE(S256)、回环重定向地址、客户端与 scope
      final q = authUrl.queryParameters;
      expect(authUrl.host, 'id.test');
      expect(q['response_type'], 'code');
      expect(q['client_id'], 'ultrapads-app');
      expect(q['code_challenge_method'], 'S256');
      expect(q['scope'], 'openid profile email offline_access');
      final redirect = Uri.parse(q['redirect_uri']!);
      expect(redirect.scheme, 'http');
      expect(redirect.host, '127.0.0.1');
      expect(redirect.path, '/callback');
      // 换令牌请求带 code_verifier，且没有客户端密钥
      final t = idp.tokenRequests.single;
      expect(t['grant_type'], 'authorization_code');
      expect(t['code'], 'the-code');
      expect(t['code_verifier'], isNotEmpty);
      expect(t.containsKey('client_secret'), isFalse);
      // 浏览器收到的页面用了传入的文案
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(browserReply, contains('Signed in'));
      expect(browserReply, contains('Close this tab'));
    });

    test('access_denied from the browser is a cancel', () async {
      final flow = LoopbackAuthFlow(
        client: FakeIdp().client(),
        openBrowser: (url) async {
          final redirect = Uri.parse(url.queryParameters['redirect_uri']!);
          unawaited(
            hit(redirect, {
              'error': 'access_denied',
              'state': url.queryParameters['state']!,
            }),
          );
          return true;
        },
      );
      await expectLater(flow.signIn(_config), throwsA(isA<AuthCancelled>()));
    });

    test('cancel() while waiting, and a browser that cannot open', () async {
      late LoopbackAuthFlow flow;
      flow = LoopbackAuthFlow(
        client: FakeIdp().client(),
        openBrowser: (url) async {
          scheduleMicrotask(flow.cancel);
          return true;
        },
      );
      await expectLater(flow.signIn(_config), throwsA(isA<AuthCancelled>()));

      final broken = LoopbackAuthFlow(
        client: FakeIdp().client(),
        openBrowser: (_) async => false,
      );
      await expectLater(broken.signIn(_config), throwsA(isA<AuthFailure>()));
    });

    test('times out when the browser never comes back', () async {
      final flow = LoopbackAuthFlow(
        client: FakeIdp().client(),
        openBrowser: (_) async => true,
        timeout: const Duration(milliseconds: 100),
      );
      await expectLater(flow.signIn(_config), throwsA(isA<AuthCancelled>()));
    });
  });
}
