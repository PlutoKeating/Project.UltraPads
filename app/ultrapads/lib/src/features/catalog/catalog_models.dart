import 'package:flutter/foundation.dart';

/// 许可证（docs/API.md §7.2 的 `license` 字段）。
@immutable
class LicenseInfo {
  const LicenseInfo._(this.id, this.badge);

  /// 目录里的许可证 ID，如 `CC-BY-SA-4.0`。
  final String id;

  /// 徽标上的简写（不翻译：许可证名称是通用代号）。
  final String badge;

  factory LicenseInfo.of(String id) {
    final up = id.toUpperCase();
    final badge = switch (up) {
      'CC0-1.0' => 'CC0',
      'PD' => 'PD',
      final s when s.startsWith('CC-') => () {
        // CC-BY-NC-SA-4.0 → BY-NC-SA；去掉前缀与末尾版本号
        final parts = s.split('-')..removeAt(0);
        if (parts.isNotEmpty && RegExp(r'^\d').hasMatch(parts.last)) {
          parts.removeLast();
        }
        return parts.join('-');
      }(),
      _ => id,
    };
    return LicenseInfo._(id, badge);
  }

  bool get nonCommercial => id.toUpperCase().contains('-NC');
  bool get shareAlike => id.toUpperCase().contains('-SA');

  /// CC0 / 公有领域不需要署名，其余都要。
  bool get needsAttribution {
    final up = id.toUpperCase();
    return up != 'CC0-1.0' && up != 'PD';
  }

  @override
  bool operator ==(Object other) => other is LicenseInfo && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

/// 目录条目（docs/API.md §7.2 `CatalogItem`）。
@immutable
class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.title,
    this.artist = '',
    this.description = '',
    this.origin = '',
    required this.license,
    this.licenseUrl = '',
    this.attribution = '',
    this.sourceUrl = '',
    this.bpm = 0,
    this.genres = const [],
    this.tags = const [],
    this.groupCount = 1,
    this.padCount = 0,
    this.durationSecs = 0,
    this.size = 0,
    this.sha256 = '',
    this.themeColor,
    this.updatedAtMs = 0,
  });

  final String id;
  final String title;
  final String artist;
  final String description;
  final String origin;
  final LicenseInfo license;
  final String licenseUrl;
  final String attribution;
  final String sourceUrl;
  final double bpm;
  final List<String> genres;
  final List<String> tags;
  final int groupCount;
  final int padCount;
  final double durationSecs;
  final int size;
  final String sha256;
  final String? themeColor;
  final int updatedAtMs;

  String get genre => genres.isEmpty ? '' : genres.first;

  factory CatalogItem.fromJson(Map<String, Object?> j) {
    List<String> strings(Object? v) =>
        v is List ? v.map((e) => '$e').toList() : const [];
    return CatalogItem(
      id: j['id'] as String,
      title: (j['title'] as String?) ?? '',
      artist: (j['artist'] as String?) ?? '',
      description: (j['description'] as String?) ?? '',
      origin: (j['origin'] as String?) ?? '',
      license: LicenseInfo.of((j['license'] as String?) ?? ''),
      licenseUrl: (j['license_url'] as String?) ?? '',
      attribution: (j['attribution'] as String?) ?? '',
      sourceUrl: (j['source_url'] as String?) ?? '',
      bpm: (j['bpm'] as num?)?.toDouble() ?? 0,
      genres: strings(j['genres']),
      tags: strings(j['tags']),
      groupCount: (j['group_count'] as num?)?.toInt() ?? 1,
      padCount: (j['pad_count'] as num?)?.toInt() ?? 0,
      durationSecs: (j['duration_secs'] as num?)?.toDouble() ?? 0,
      size: (j['size'] as num?)?.toInt() ?? 0,
      sha256: ((j['sha256'] as String?) ?? '').toLowerCase(),
      themeColor: j['theme_color'] as String?,
      updatedAtMs: (j['updated_at_ms'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'description': description,
    'origin': origin,
    'license': license.id,
    'license_url': licenseUrl,
    'attribution': attribution,
    'source_url': sourceUrl,
    'bpm': bpm,
    'genres': genres,
    'tags': tags,
    'group_count': groupCount,
    'pad_count': padCount,
    'duration_secs': durationSecs,
    'size': size,
    'sha256': sha256,
    'theme_color': themeColor,
    'updated_at_ms': updatedAtMs,
  };
}

enum CatalogSort { newest, bpm, title }

/// 目录筛选（`GET /api/catalog` 的查询参数）。
@immutable
class CatalogQuery {
  const CatalogQuery({
    this.text = '',
    this.licenses = const {},
    this.genre,
    this.origin,
    this.bpmMin,
    this.bpmMax,
    this.sort = CatalogSort.newest,
  });

  final String text;
  final Set<String> licenses;
  final String? genre;

  /// 来源筛选（`album` / `online` / `synth` / `ugc`）；null = 全部。
  final String? origin;
  final int? bpmMin;
  final int? bpmMax;
  final CatalogSort sort;

  CatalogQuery copyWith({
    String? text,
    Set<String>? licenses,
    String? Function()? genre,
    String? Function()? origin,
    int? Function()? bpmMin,
    int? Function()? bpmMax,
    CatalogSort? sort,
  }) => CatalogQuery(
    text: text ?? this.text,
    licenses: licenses ?? this.licenses,
    genre: genre != null ? genre() : this.genre,
    origin: origin != null ? origin() : this.origin,
    bpmMin: bpmMin != null ? bpmMin() : this.bpmMin,
    bpmMax: bpmMax != null ? bpmMax() : this.bpmMax,
    sort: sort ?? this.sort,
  );

  bool get isFiltered =>
      licenses.isNotEmpty ||
      genre != null ||
      origin != null ||
      bpmMin != null ||
      bpmMax != null;

  Map<String, String> toParams({String? cursor, int limit = 30}) => {
    if (text.trim().isNotEmpty) 'q': text.trim(),
    if (licenses.isNotEmpty) 'license': (licenses.toList()..sort()).join(','),
    'genre': ?genre,
    'origin': ?origin,
    if (bpmMin != null) 'bpm_min': '$bpmMin',
    if (bpmMax != null) 'bpm_max': '$bpmMax',
    'sort': switch (sort) {
      CatalogSort.newest => 'new',
      CatalogSort.bpm => 'bpm',
      CatalogSort.title => 'title',
    },
    'limit': '$limit',
    'cursor': ?cursor,
  };

  @override
  bool operator ==(Object other) =>
      other is CatalogQuery &&
      other.text == text &&
      setEquals(other.licenses, licenses) &&
      other.genre == genre &&
      other.origin == origin &&
      other.bpmMin == bpmMin &&
      other.bpmMax == bpmMax &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(
    text,
    Object.hashAllUnordered(licenses),
    genre,
    origin,
    bpmMin,
    bpmMax,
    sort,
  );
}

@immutable
class CatalogPage {
  const CatalogPage({required this.items, this.nextCursor, this.total = 0});
  final List<CatalogItem> items;
  final String? nextCursor;
  final int total;
}

@immutable
class Facet {
  const Facet(this.id, this.count);
  final String id;
  final int count;
}

@immutable
class CatalogFacets {
  const CatalogFacets({
    this.licenses = const [],
    this.genres = const [],
    this.origins = const [],
  });
  final List<Facet> licenses;
  final List<Facet> genres;
  final List<Facet> origins;

  static CatalogFacets fromJson(Map<String, Object?> j) {
    List<Facet> facets(Object? v) => v is List
        ? [
            for (final e in v)
              if (e is Map)
                Facet('${e['id']}', (e['count'] as num?)?.toInt() ?? 0),
          ]
        : const [];
    return CatalogFacets(
      licenses: facets(j['licenses']),
      genres: facets(j['genres']),
      origins: facets(j['origins']),
    );
  }
}

/// `GET /api/me/state`。
@immutable
class MeState {
  const MeState({
    this.favorites = const [],
    this.recent = const [],
    this.downloads = const [],
  });
  final List<String> favorites;
  final List<StampedId> recent;
  final List<StampedId> downloads;

  static MeState fromJson(Map<String, Object?> j) {
    List<StampedId> stamped(Object? v) => v is List
        ? [
            for (final e in v)
              if (e is Map)
                StampedId('${e['id']}', (e['at_ms'] as num?)?.toInt() ?? 0),
          ]
        : const [];
    return MeState(
      favorites: [
        if (j['favorites'] is List)
          for (final e in j['favorites']! as List) '$e',
      ],
      recent: stamped(j['recent']),
      downloads: stamped(j['downloads']),
    );
  }
}

@immutable
class StampedId {
  const StampedId(this.id, this.atMs);
  final String id;
  final int atMs;
}

/// 目录接口错误：[code] 是服务返回的 `error` 码（如 `not_found`、`invalid_token`），
/// 网络 / 解析问题为 `network` / `bad_response`。
class CatalogException implements Exception {
  const CatalogException(this.code, {this.status, this.message});
  final String code;
  final int? status;
  final String? message;

  bool get unauthorized => status == 401 || status == 403;
  bool get notFound => status == 404;
  bool get isNetwork => code == 'network';

  @override
  String toString() => 'CatalogException($code, $status)';
}

/// 下载被用户取消。
class CatalogCancelled implements Exception {
  const CatalogCancelled();
}
