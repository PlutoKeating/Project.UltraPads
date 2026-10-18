import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_links.dart';
import 'auth_flow.dart';
import 'auth_models.dart';
import 'token_store.dart';

/// OIDC 客户端配置；链接配置未载入或缺少 issuer 时为 null（账号功能不可用）。
final authConfigProvider = Provider<AuthConfig?>((ref) {
  final links = ref.watch(appLinksProvider).value;
  final issuer = links?.idIssuer;
  if (links == null || issuer == null) return null;
  return AuthConfig(issuer: issuer, clientId: links.idClientId);
});

/// 发往账号服务的 HTTP 客户端（测试中替换）。
final authHttpClientProvider = Provider<http.Client>((ref) {
  final c = http.Client();
  ref.onDispose(c.close);
  return c;
});

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => FileTokenStore(getApplicationSupportDirectory),
);

/// 平台对应的交互登录方式（测试中替换）。
final authFlowProvider = Provider<AuthFlow>((ref) {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
    return AppAuthFlow();
  }
  return LoopbackAuthFlow(
    client: ref.watch(authHttpClientProvider),
    openBrowser: (url) => launchUrl(url, mode: LaunchMode.externalApplication),
  );
});

enum AccountStatus { loading, signedOut, signingIn, signedIn }

enum AccountError { none, failed, notConfigured }

@immutable
class AccountState {
  const AccountState({
    this.status = AccountStatus.loading,
    this.profile,
    this.error = AccountError.none,
  });

  final AccountStatus status;
  final AccountProfile? profile;
  final AccountError error;

  bool get signedIn => status == AccountStatus.signedIn;
}

class AccountController extends Notifier<AccountState> {
  AuthTokens? _tokens;
  Future<String?>? _refreshing;

  AuthConfig? get _config => ref.read(authConfigProvider);

  @override
  AccountState build() {
    unawaited(Future.microtask(restore));
    return const AccountState();
  }

  /// 启动时读出上次保存的令牌（不触网）。
  Future<void> restore() async {
    final tokens = await ref.read(tokenStoreProvider).read();
    if (tokens == null) {
      state = const AccountState(status: AccountStatus.signedOut);
      return;
    }
    _tokens = tokens;
    state = AccountState(
      status: AccountStatus.signedIn,
      profile: AccountProfile.fromClaims(jwtClaims(tokens.idToken)),
    );
  }

  /// 打开系统浏览器登录。成功后保存令牌；取消时回到未登录且不报错。
  Future<void> signIn({LoopbackPage? page}) async {
    try {
      await ref.read(appLinksProvider.future); // 启动时配置可能还在读 asset
    } catch (_) {}
    final config = _config;
    if (config == null) {
      state = const AccountState(
        status: AccountStatus.signedOut,
        error: AccountError.notConfigured,
      );
      return;
    }
    state = const AccountState(status: AccountStatus.signingIn);
    try {
      final tokens = await ref
          .read(authFlowProvider)
          .signIn(config, page: page);
      await _adopt(tokens, config);
    } on AuthCancelled {
      state = const AccountState(status: AccountStatus.signedOut);
    } catch (_) {
      state = const AccountState(
        status: AccountStatus.signedOut,
        error: AccountError.failed,
      );
    }
  }

  void cancelSignIn() => ref.read(authFlowProvider).cancel();

  Future<void> _adopt(AuthTokens tokens, AuthConfig config) async {
    _tokens = tokens;
    await ref.read(tokenStoreProvider).write(tokens);
    var profile = AccountProfile.fromClaims(jwtClaims(tokens.idToken));
    if (profile?.email == null) {
      // ID 令牌里没有邮箱：问一次 userinfo（失败不影响登录）
      try {
        final info = await fetchUserinfo(
          ref.read(authHttpClientProvider),
          config,
          tokens.accessToken,
        );
        profile = AccountProfile.fromClaims(info) ?? profile;
      } catch (_) {}
    }
    state = AccountState(status: AccountStatus.signedIn, profile: profile);
  }

  /// 退出：清掉本机令牌（服务端的云端数据保留）。
  Future<void> signOut() async {
    _tokens = null;
    await ref.read(tokenStoreProvider).clear();
    state = const AccountState(status: AccountStatus.signedOut);
  }

  /// 给后端用的访问令牌：还有一分钟以上有效就直接用，否则先静默刷新（并发只刷新一次）。
  /// 未登录返回 null；刷新令牌失效时退出登录；仅网络问题时沿用旧令牌（服务端会拒绝则由调用方处理）。
  Future<String?> accessToken() async {
    final t = _tokens;
    if (t == null) return null;
    if (t.isFresh(DateTime.now())) return t.accessToken;
    if (t.refreshToken == null) return t.accessToken;
    return _refreshing ??= _refresh(t).whenComplete(() => _refreshing = null);
  }

  Future<String?> _refresh(AuthTokens old) async {
    final config = _config;
    if (config == null) return old.accessToken;
    try {
      final fresh = (await refreshTokens(
        ref.read(authHttpClientProvider),
        config,
        old.refreshToken!,
      )).mergedOver(old);
      _tokens = fresh;
      await ref.read(tokenStoreProvider).write(fresh);
      return fresh.accessToken;
    } on AuthFailure catch (e) {
      if (e.invalidGrant) {
        await signOut();
        return null;
      }
      return old.accessToken;
    } catch (_) {
      return old.accessToken;
    }
  }
}

final accountProvider = NotifierProvider<AccountController, AccountState>(
  AccountController.new,
);
