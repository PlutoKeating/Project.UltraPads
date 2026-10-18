import 'dart:convert';

/// 令牌过期前多久就当作需要刷新。
const defaultTokenSkew = Duration(minutes: _skewMinutes);
const _skewMinutes = 1;

/// 一组 OIDC 令牌（授权码换来或刷新得到）。
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    this.refreshToken,
    this.idToken,
    this.expiresAt,
  });

  final String accessToken;
  final String? refreshToken;
  final String? idToken;

  /// 访问令牌的过期时刻（UTC）；未知时为 null（当作已过期，下次使用前刷新）。
  final DateTime? expiresAt;

  /// 还剩 [skew] 以上有效才算可用。
  bool isFresh(DateTime now, {Duration skew = defaultTokenSkew}) =>
      expiresAt != null && expiresAt!.isAfter(now.add(skew));

  /// 刷新后沿用旧的刷新令牌 / ID 令牌（服务端不一定每次都发新的）。
  AuthTokens mergedOver(AuthTokens old) => AuthTokens(
    accessToken: accessToken,
    refreshToken: refreshToken ?? old.refreshToken,
    idToken: idToken ?? old.idToken,
    expiresAt: expiresAt,
  );

  Map<String, Object?> toJson() => {
    'access': accessToken,
    'refresh': refreshToken,
    'id': idToken,
    'expires': expiresAt?.toUtc().toIso8601String(),
  };

  static AuthTokens? fromJson(Object? json) {
    if (json is! Map) return null;
    final access = json['access'];
    if (access is! String || access.isEmpty) return null;
    return AuthTokens(
      accessToken: access,
      refreshToken: json['refresh'] as String?,
      idToken: json['id'] as String?,
      expiresAt: DateTime.tryParse('${json['expires'] ?? ''}'),
    );
  }
}

/// 令牌里解出的资料（ID 令牌声明或 userinfo）。
class AccountProfile {
  const AccountProfile({required this.sub, this.email, this.name});

  final String sub;
  final String? email;
  final String? name;

  /// 设置页显示用：邮箱优先，其次名字。
  String get label => email ?? name ?? sub;

  static AccountProfile? fromClaims(Map<String, Object?> claims) {
    final sub = claims['sub'];
    if (sub is! String || sub.isEmpty) return null;
    final name = claims['name'] ?? claims['preferred_username'];
    return AccountProfile(
      sub: sub,
      email: claims['email'] as String?,
      name: name is String ? name : null,
    );
  }
}

/// 解 JWT 的载荷（不验签：仅用于在本机显示资料，验签由 Worker 负责）。
Map<String, Object?> jwtClaims(String? jwt) {
  if (jwt == null) return const {};
  final parts = jwt.split('.');
  if (parts.length < 2) return const {};
  try {
    final json = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return json is Map ? json.cast<String, Object?>() : const {};
  } catch (_) {
    return const {};
  }
}

/// OIDC 客户端配置（来自 `assets/config/links.json`）。
class AuthConfig {
  const AuthConfig({
    required this.issuer,
    required this.clientId,
    this.scopes = const ['openid', 'profile', 'email', 'offline_access'],
    this.mobileRedirect = 'com.plutokeating.ultrapads://callback',
  });

  final Uri issuer;
  final String clientId;
  final List<String> scopes;

  /// Android / iOS 的自定义 scheme 回调（AndroidManifest 里登记同一个 scheme）。
  final String mobileRedirect;

  /// OIDC 发现文档。
  Uri get discovery => issuer.replace(
    path:
        '${issuer.path.endsWith('/') ? issuer.path : '${issuer.path}/'}'
        '.well-known/openid-configuration',
  );
}

/// 用户在浏览器里取消，或关掉了等待。
class AuthCancelled implements Exception {
  const AuthCancelled();
  @override
  String toString() => 'AuthCancelled';
}

/// 登录 / 刷新失败。[invalidGrant] 表示刷新令牌已失效（被吊销或过期），需要重新登录。
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.invalidGrant = false});
  final String message;
  final bool invalidGrant;
  @override
  String toString() => 'AuthFailure($message)';
}
