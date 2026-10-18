import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../generated/semantic.g.dart';
import '../generated/themes.g.dart';
import 'color_codec.dart';
import 'gradient.dart';

/// A typed set of semantic token overrides (what a custom skin changes).
///
/// Keys are dotted DTCG paths (`pad.palette.0.core`), values are [Color],
/// [UpGradient] or [double] according to [UpSemantic.tokenInfo]. Invalid keys
/// or types are rejected on construction so a stored skin can never break
/// rendering.
@immutable
class UpSemanticOverrides {
  UpSemanticOverrides([Map<String, Object> values = const <String, Object>{}])
    : values = Map<String, Object>.unmodifiable(_validate(values));

  const UpSemanticOverrides.empty() : values = const <String, Object>{};

  final Map<String, Object> values;

  bool get isEmpty => values.isEmpty;

  static Map<String, Object> _validate(Map<String, Object> input) {
    final Map<String, Object> out = <String, Object>{};
    input.forEach((String key, Object value) {
      final UpSemanticTokenInfo? info = UpSemantic.tokenInfo[key];
      if (info == null) {
        throw ArgumentError.value(key, 'key', 'Unknown semantic token');
      }
      out[key] = switch (info.type) {
        UpSemanticType.color when value is Color => value,
        UpSemanticType.gradient when value is UpGradient => value,
        UpSemanticType.number ||
        UpSemanticType.dimension when value is num => value.toDouble(),
        _ => throw ArgumentError.value(
          value,
          key,
          'Expected ${info.type.name}',
        ),
      };
    });
    return out;
  }

  UpSemanticOverrides put(String key, Object value) =>
      UpSemanticOverrides(<String, Object>{...values, key: value});

  UpSemanticOverrides remove(String key) =>
      UpSemanticOverrides(<String, Object>{...values}..remove(key));

  /// Applies the overrides on top of [base].
  UpSemantic applyTo(UpSemantic base) => base.withValues(values);

  /// Keys whose value differs between [base] and [skin] (for "save as skin").
  static UpSemanticOverrides diff(UpSemantic base, UpSemantic skin) {
    final Map<String, Object> out = <String, Object>{};
    for (final UpSemanticTokenInfo info in UpSemantic.tokens) {
      final Object v = skin.valueOf(info.key);
      if (v != base.valueOf(info.key)) out[info.key] = v;
    }
    return UpSemanticOverrides(out);
  }

  Map<String, Object> toJson() => <String, Object>{
    for (final MapEntry<String, Object> e in values.entries)
      e.key: _encode(e.value),
  };

  /// Decodes JSON overrides. Unknown keys are skipped (forward/backward
  /// compatibility) and reported through [onUnknownKey]; malformed values
  /// throw [FormatException].
  factory UpSemanticOverrides.fromJson(
    Map<String, Object?> json, {
    void Function(String key)? onUnknownKey,
  }) {
    final Map<String, Object> out = <String, Object>{};
    json.forEach((String key, Object? raw) {
      final UpSemanticTokenInfo? info = UpSemantic.tokenInfo[key];
      if (info == null) {
        onUnknownKey?.call(key);
        return;
      }
      out[key] = switch (info.type) {
        UpSemanticType.color => UpColorCodec.decode(raw),
        UpSemanticType.gradient => UpGradient.fromJson(raw),
        UpSemanticType.number || UpSemanticType.dimension =>
          raw is num
              ? raw.toDouble()
              : throw FormatException('$key must be a number', raw),
      };
    });
    return UpSemanticOverrides(out);
  }

  static Object _encode(Object v) => switch (v) {
    Color c => UpColorCodec.encode(c),
    UpGradient g => g.toJson(),
    double d => d,
    _ => throw StateError('unreachable'),
  };

  @override
  bool operator ==(Object other) =>
      other is UpSemanticOverrides && mapEquals(other.values, values);

  @override
  int get hashCode => Object.hashAll(
    values.entries.map(
      (MapEntry<String, Object> e) => Object.hash(e.key, e.value),
    ),
  );
}

/// A user skin as persisted by the skin editor.
///
/// ```json
/// {"schema":1,"id":"my-skin","name":"My skin","base":"neon",
///  "overrides":{"pad.palette.0.core":"#FF00AA","pad.shape.radiusRatio":0.2}}
/// ```
@immutable
class UpSkin {
  const UpSkin({
    required this.id,
    required this.name,
    required this.baseId,
    this.overrides = const UpSemanticOverrides.empty(),
  });

  static const int schemaVersion = 1;

  final String id;
  final String name;

  /// Built-in theme id this skin derives from (see [UpSemanticThemes.ids]).
  final String baseId;
  final UpSemanticOverrides overrides;

  Map<String, Object> toJson() => <String, Object>{
    'schema': schemaVersion,
    'id': id,
    'name': name,
    'base': baseId,
    'overrides': overrides.toJson(),
  };

  String encode() => jsonEncode(toJson());

  factory UpSkin.fromJson(
    Map<String, Object?> json, {
    void Function(String key)? onUnknownKey,
  }) {
    final Object? schema = json['schema'];
    if (schema is! int || schema > schemaVersion) {
      throw FormatException('Unsupported skin schema', schema);
    }
    final Object? id = json['id'];
    final Object? name = json['name'];
    final Object? base = json['base'];
    final Object overrides = json['overrides'] ?? const <String, Object?>{};
    if (id is! String ||
        name is! String ||
        base is! String ||
        overrides is! Map) {
      throw const FormatException(
        'Skin JSON requires string id/name/base and an overrides object',
      );
    }
    return UpSkin(
      id: id,
      name: name,
      baseId: UpSemanticThemes.byId.containsKey(base)
          ? base
          : UpSemanticThemes.defaultId,
      overrides: UpSemanticOverrides.fromJson(
        overrides.cast<String, Object?>(),
        onUnknownKey: onUnknownKey,
      ),
    );
  }

  static UpSkin decode(String source) => UpSkin.fromJson(
    (jsonDecode(source) as Map<Object?, Object?>).cast<String, Object?>(),
  );

  @override
  bool operator ==(Object other) =>
      other is UpSkin &&
      other.id == id &&
      other.name == name &&
      other.baseId == baseId &&
      other.overrides == overrides;

  @override
  int get hashCode => Object.hash(id, name, baseId, overrides);
}
