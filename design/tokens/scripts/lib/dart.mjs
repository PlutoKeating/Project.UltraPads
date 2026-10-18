// Custom Dart output for Style Dictionary.
import { camel, pascal, primitiveClassOf } from './model.mjs';
import { colorToArgbLiteral, num } from './values.mjs';

export const DART_HEADER = `// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: design/tokens/src (W3C DTCG) -> Style Dictionary -> design/tokens/scripts/build.mjs
// Regenerate with \`just tokens\` (cd design/tokens && pnpm run build).
// ignore_for_file: type=lint, unused_import
`;

const str = (s) => `'${String(s).replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('$', '\\$').replaceAll('\n', '\\n')}'`;

function docLines(entry, indent = '  ') {
  const lines = [];
  if (entry.description) {
    for (const l of String(entry.description).split('\n')) lines.push(`${indent}/// ${l}`);
    lines.push(`${indent}///`);
  }
  lines.push(`${indent}/// Token: \`${entry.path.join('.')}\``);
  return lines.join('\n');
}

const color = (c) => `Color(${colorToArgbLiteral(c)})`;
const weight = (w) => `FontWeight.w${Math.min(900, Math.max(100, Math.round(w / 100) * 100))}`;

/** Dart type + const expression for an entry. */
export function dartTypeAndExpr(e) {
  const v = e.value;
  switch (e.type) {
    case 'color': return ['Color', color(v)];
    case 'dimension': return ['double', num(v)];
    case 'number': return e.isInt ? ['int', String(Math.round(v))] : ['double', num(v)];
    case 'duration': {
      const ms = Number(v);
      return Number.isInteger(ms)
        ? ['Duration', `Duration(milliseconds: ${ms})`]
        : ['Duration', `Duration(microseconds: ${Math.round(ms * 1000)})`];
    }
    case 'cubicBezier': return ['Cubic', `Cubic(${v.map(num).join(', ')})`];
    case 'fontWeight': return ['FontWeight', weight(v)];
    case 'fontFamily': return ['List<String>', `<String>[${v.map(str).join(', ')}]`];
    case 'gradient':
      return ['UpGradient', `UpGradient(colors: <Color>[${v.map((s) => color(s.color)).join(', ')}], stops: <double>[${v.map((s) => num(s.position)).join(', ')}])`];
    case 'shadow':
      if (e.isGlow) {
        return ['UpGlowSpec', `UpGlowSpec(<UpGlowLayer>[${v.map((l) => `UpGlowLayer(opacity: ${num(Math.round(l.color.a * 100) / 100)}, blur: ${num(l.blur)}, spread: ${num(l.spread)}, dx: ${num(l.x)}, dy: ${num(l.y)})`).join(', ')}])`];
      }
      return ['List<BoxShadow>', `<BoxShadow>[${v.map((l) => `BoxShadow(color: ${color(l.color)}, offset: Offset(${num(l.x)}, ${num(l.y)}), blurRadius: ${num(l.blur)}, spreadRadius: ${num(l.spread)})`).join(', ')}]`];
    case 'typography': {
      const [family] = v.fontFamily;
      return ['UpTextRoleSpec', `UpTextRoleSpec(family: ${str(family)}, size: ${num(v.fontSize)}, weight: ${weight(v.fontWeight)}, letterSpacing: ${num(v.letterSpacing)}, height: ${num(v.lineHeight)}, textCase: UpTextCase.${e.textCase === 'upper' ? 'upper' : 'none'})`];
    }
    case 'spring':
      return ['SpringDescription', `SpringDescription(mass: ${num(v.mass)}, stiffness: ${num(v.stiffness)}, damping: ${num(v.damping)})`];
    default:
      throw new Error(`No Dart mapping for type ${e.type} (${e.path.join('.')})`);
  }
}

const IMPORTS = `import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../runtime/glow.dart';
import '../runtime/gradient.dart';
import '../runtime/text_role.dart';
`;

function staticClasses(groups) {
  const out = [];
  for (const { cls, doc, members } of groups) {
    out.push(`/// ${doc}\nabstract final class ${cls} {`);
    for (const { name, entry } of members) {
      const [type, expr] = dartTypeAndExpr(entry);
      out.push(`${docLines(entry)}\n  static const ${type} ${name} = ${expr};\n`);
    }
    out.push('}\n');
  }
  return out.join('\n');
}

export function primitivesFile(entries) {
  const groups = new Map();
  for (const e of entries) {
    const { cls, doc, member } = primitiveClassOf(e.path);
    if (!groups.has(cls)) groups.set(cls, { cls, doc, members: [] });
    groups.get(cls).members.push({ name: camel(member), entry: e });
  }
  const roles = entries.filter((e) => e.path[0] === 'typography');
  const roleEnum = roles.length === 0 ? '' : `
/// Typography roles (DTCG \`typography.*\`). Resolve a TextStyle with
/// \`UpTheme.of(context).text[UpTextRole.title]\`.
enum UpTextRole {
${roles.map((e) => `${docLines(e)}\n  ${camel(e.path.slice(1))}(UpTextRoles.${camel(e.path.slice(1))}),`).join('\n')};

  const UpTextRole(this.spec);

  /// Raw token values for this role.
  final UpTextRoleSpec spec;
}
`;
  return `${DART_HEADER}\n${IMPORTS}\n${staticClasses([...groups.values()])}${roleEnum}`;
}

export function componentsFile(entries) {
  const groups = new Map();
  for (const e of entries) {
    const [head, ...rest] = e.path;
    const cls = `Up${pascal([head])}Tokens`;
    if (!groups.has(cls)) groups.set(cls, { cls, doc: `Component tokens for \`${head}\` (theme-independent geometry, motion and glow recipes).`, members: [] });
    groups.get(cls).members.push({ name: camel(rest), entry: e });
  }
  return `${DART_HEADER}\n${IMPORTS}\n${staticClasses([...groups.values()])}`;
}

const SEM_DART = { color: 'Color', gradient: 'UpGradient', number: 'double', dimension: 'double' };
const LERP = {
  color: (f) => `Color.lerp(a.${f}, b.${f}, t)!`,
  gradient: (f) => `UpGradient.lerp(a.${f}, b.${f}, t)`,
  number: (f) => `lerpDouble(a.${f}, b.${f}, t)!`,
  dimension: (f) => `lerpDouble(a.${f}, b.${f}, t)!`,
};

/** The UpSemantic value class (fields, copyWith, lerp, key access). */
export function semanticSchemaFile(entries) {
  const fields = entries.map((e) => ({ e, key: e.path.join('.'), name: camel(e.path), type: SEM_DART[e.type] }));
  for (const f of fields) if (!f.type) throw new Error(`Semantic token ${f.key} has unsupported type ${f.e.type}`);

  // Pad palette roles: pad.palette.<i>.<prop>
  const roles = new Map();
  for (const f of fields) {
    const p = f.e.path;
    if (p[0] === 'pad' && p[1] === 'palette') roles.set(Number(p[2]), { ...(roles.get(Number(p[2])) ?? {}), [p[3]]: f.name });
  }
  const roleIdx = [...roles.keys()].sort((a, b) => a - b);
  roleIdx.forEach((v, i) => { if (v !== i) throw new Error('pad.palette indices must be contiguous from 0'); });
  for (const i of roleIdx) {
    for (const k of ['core', 'mid', 'edge', 'glow', 'pressed']) if (!roles.get(i)[k]) throw new Error(`pad.palette.${i}.${k} missing`);
  }

  const L = [];
  L.push(DART_HEADER);
  L.push(`import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../runtime/gradient.dart';
import '../runtime/pad_role.dart';
`);
  L.push(`/// Value type of a semantic token (what a skin may override).
enum UpSemanticType { color, gradient, number, dimension }

/// Metadata for one semantic token (used by the skin editor and JSON codec).
@immutable
class UpSemanticTokenInfo {
  const UpSemanticTokenInfo(this.key, this.type, this.description);

  /// Dotted DTCG path, e.g. \`pad.palette.0.core\`. Stable JSON key.
  final String key;
  final UpSemanticType type;
  final String? description;

  /// First path segment (\`surface\`, \`pad\`, ...), for grouping in editors.
  String get group => key.split('.').first;
}
`);
  L.push(`/// All semantic tokens of one skin. Generated from the DTCG semantic layer;
/// themes (neon / outline / light) and user skins are instances of this class.
@immutable
class UpSemantic {
  const UpSemantic({
${fields.map((f) => `    required this.${f.name},`).join('\n')}
  });
`);
  for (const f of fields) {
    L.push(`${docLines(f.e)}\n  final ${f.type} ${f.name};\n`);
  }
  L.push(`  /// Number of pad colour roles. Kit pad colours are role indices (wrap around).
  static const int padPaletteLength = ${roleIdx.length};

  /// Colour role for a pad colour index (wraps modulo [padPaletteLength]).
  UpPadRole padRole(int index) {
    switch (index % padPaletteLength) {
${roleIdx.map((i) => {
    const r = roles.get(i);
    return `      case ${i}:\n        return UpPadRole(index: ${i}, core: ${r.core}, mid: ${r.mid}, edge: ${r.edge}, glow: ${r.glow}, pressed: ${r.pressed});`;
  }).join('\n')}
      default:
        throw StateError('unreachable');
    }
  }

  /// All pad roles in order.
  List<UpPadRole> get padPalette => List<UpPadRole>.generate(padPaletteLength, padRole, growable: false);

  /// Token metadata in declaration order.
  static const List<UpSemanticTokenInfo> tokens = <UpSemanticTokenInfo>[
${fields.map((f) => `    UpSemanticTokenInfo(${str(f.key)}, UpSemanticType.${f.e.type}, ${f.e.description ? str(f.e.description) : 'null'}),`).join('\n')}
  ];

  /// Token metadata by key.
  static final Map<String, UpSemanticTokenInfo> tokenInfo = <String, UpSemanticTokenInfo>{
    for (final UpSemanticTokenInfo info in tokens) info.key: info,
  };

  /// Reads a token by its dotted key. Throws [ArgumentError] for unknown keys.
  Object valueOf(String key) {
    switch (key) {
${fields.map((f) => `      case '${f.key}':\n        return ${f.name};`).join('\n')}
      default:
        throw ArgumentError.value(key, 'key', 'Unknown semantic token');
    }
  }

  /// Returns a copy where the given keys are replaced. Values must already be
  /// typed (Color / UpGradient / num). Unknown keys or wrong types throw.
  UpSemantic withValues(Map<String, Object> values) {
    if (values.isEmpty) return this;
    for (final String key in values.keys) {
      if (!tokenInfo.containsKey(key)) {
        throw ArgumentError.value(key, 'values', 'Unknown semantic token');
      }
    }
    T pick<T>(String key, T current) {
      final Object? v = values[key];
      if (v == null) return current;
      if (T == double && v is num) return v.toDouble() as T;
      if (v is T) return v as T;
      throw ArgumentError.value(v, key, 'Expected $T');
    }

    return UpSemantic(
${fields.map((f) => `      ${f.name}: pick<${f.type}>('${f.key}', ${f.name}),`).join('\n')}
    );
  }

  UpSemantic copyWith({
${fields.map((f) => `    ${f.type}? ${f.name},`).join('\n')}
  }) {
    return UpSemantic(
${fields.map((f) => `      ${f.name}: ${f.name} ?? this.${f.name},`).join('\n')}
    );
  }

  /// Linear interpolation of every token (used by theme switch animations).
  static UpSemantic lerp(UpSemantic a, UpSemantic b, double t) {
    if (identical(a, b)) return a;
    return UpSemantic(
${fields.map((f) => `      ${f.name}: ${LERP[f.e.type](f.name)},`).join('\n')}
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpSemantic &&
${fields.map((f) => `        other.${f.name} == ${f.name}`).join(' &&\n')};
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
${fields.map((f) => `        ${f.name},`).join('\n')}
      ]);
}
`);
  return L.join('\n');
}

export function semanticThemeFile(themeId, entries) {
  const fields = entries.map((e) => {
    const [, expr] = dartTypeAndExpr({ ...e, isInt: false, isGlow: false });
    return `  ${camel(e.path)}: ${expr},`;
  });
  return `${DART_HEADER}
import 'package:flutter/painting.dart';

import '../runtime/gradient.dart';
import 'semantic.g.dart';

/// Semantic values of the \`${themeId}\` skin.
const UpSemantic upSemantic${pascal([themeId])} = UpSemantic(
${fields.join('\n')}
);
`;
}

export function themeRegistryFile(themes) {
  const imports = themes.map((t) => `import 'semantic_${t.id}.g.dart';`).join('\n');
  return `${DART_HEADER}
import 'dart:ui' show Brightness;

import 'semantic.g.dart';
${imports}

/// Built-in skins generated from design/tokens/themes.config.json.
abstract final class UpSemanticThemes {
  /// Id of the default skin.
  static const String defaultId = '${themes[0].id}';

  /// Built-in skin ids in display order.
  static const List<String> ids = <String>[${themes.map((t) => `'${t.id}'`).join(', ')}];

  static const Map<String, UpSemantic> byId = <String, UpSemantic>{
${themes.map((t) => `    '${t.id}': upSemantic${pascal([t.id])},`).join('\n')}
  };

  static const Map<String, Brightness> brightness = <String, Brightness>{
${themes.map((t) => `    '${t.id}': Brightness.${t.brightness},`).join('\n')}
  };

  static const Map<String, String> descriptions = <String, String>{
${themes.map((t) => `    '${t.id}': ${str(t.description ?? '')},`).join('\n')}
  };
}
`;
}
