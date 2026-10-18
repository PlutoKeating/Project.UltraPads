// Token model shared by all formats: layer detection, naming, spring grouping.
import { normalize } from './values.mjs';

export const SEMANTIC_TYPES = new Set(['color', 'gradient', 'number', 'dimension']);
const SPRING_KEYS = ['stiffness', 'damping', 'mass'];

export function layerOf(token) {
  const p = token.filePath.replaceAll('\\', '/');
  if (p.includes('/src/primitive/')) return 'primitive';
  if (p.includes('/src/component/')) return 'component';
  if (p.includes('/src/semantic/') || p.includes('/src/themes/')) return 'semantic';
  throw new Error(`Token ${token.path.join('.')} comes from an unknown layer: ${p}`);
}

const DART_RESERVED = new Set([
  'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case', 'catch', 'class', 'const',
  'continue', 'covariant', 'default', 'deferred', 'do', 'dynamic', 'else', 'enum', 'export',
  'extends', 'extension', 'external', 'factory', 'false', 'final', 'finally', 'for', 'Function',
  'get', 'hide', 'if', 'implements', 'import', 'in', 'interface', 'is', 'late', 'library', 'mixin',
  'new', 'null', 'of', 'on', 'operator', 'part', 'required', 'rethrow', 'return', 'sealed', 'set',
  'show', 'static', 'super', 'switch', 'sync', 'this', 'throw', 'true', 'try', 'type', 'typedef',
  'var', 'void', 'when', 'while', 'with', 'yield', 'hashCode', 'runtimeType', 'toString',
]);

const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);

/** ['pad','palette','0','core'] -> padPalette0Core */
export function camel(segments) {
  if (segments.length === 0) throw new Error('empty name');
  const [first, ...rest] = segments;
  let name = first.charAt(0).toLowerCase() + first.slice(1) + rest.map(cap).join('');
  if (/^[0-9]/.test(name)) name = `v${name}`;
  if (DART_RESERVED.has(name)) name = `${name}Value`;
  if (!/^[A-Za-z_$][A-Za-z0-9_$]*$/.test(name)) throw new Error(`Cannot derive Dart name from ${segments.join('.')}`);
  return name;
}

export const pascal = (segments) => cap(camel(segments));

export const kebab = (segments) =>
  segments.map((s) => s.replace(/([a-z0-9])([A-Z])/g, '$1-$2').toLowerCase()).join('-');

/**
 * Converts SD tokens into model entries. Groups whose children are exactly
 * stiffness/damping/mass are collapsed into one `spring` entry.
 */
export function toEntries(tokens) {
  const entries = [];
  const springs = new Map();
  for (const t of tokens) {
    const last = t.path[t.path.length - 1];
    if (SPRING_KEYS.includes(last)) {
      const key = t.path.slice(0, -1).join('.');
      if (!springs.has(key)) {
        const e = { path: t.path.slice(0, -1), type: 'spring', value: {}, token: t, description: undefined };
        springs.set(key, e);
        entries.push(e);
      }
      springs.get(key).value[last] = normalize(t);
      continue;
    }
    entries.push({
      path: t.path,
      type: t.$type,
      value: normalize(t),
      token: t,
      description: t.$description ?? t.comment,
      isGlow: t.$type === 'shadow' && (t.path[0] === 'glow' || refersTo(t, 'glow.')),
      isInt: Boolean(t.$extensions?.up?.int) || t.path[0] === 'zIndex',
      textCase: t.$extensions?.up?.textCase ?? 'none',
    });
  }
  for (const s of springs.values()) {
    for (const k of SPRING_KEYS) {
      if (typeof s.value[k] !== 'number') throw new Error(`Spring ${s.path.join('.')} misses ${k}`);
    }
  }
  return entries;
}

function refersTo(token, prefix) {
  const orig = token.original?.$value;
  return typeof orig === 'string' && orig.startsWith(`{${prefix}`);
}

/** Primitive group -> generated Dart class (longest prefix wins). */
export const PRIMITIVE_CLASSES = [
  ['color', 'UpPrimitiveColors', 'Primitive colour palette. UI code must use semantic colours from `UpTheme.of(context).colors` instead.'],
  ['gradient', 'UpGradients', 'Primitive gradients.'],
  ['radius', 'UpRadii', 'Corner radius scale (logical px).'],
  ['ratio', 'UpRatios', 'Proportional ratios (value = side * ratio).'],
  ['spacing', 'UpSpacing', 'Spacing scale (logical px).'],
  ['size', 'UpSizes', 'Size scale (logical px).'],
  ['font.family', 'UpFontFamilies', 'Font family stacks: [private family, open fallback].'],
  ['font.weight', 'UpFontWeights', 'Font weights.'],
  ['font.size', 'UpFontSizes', 'Font sizes (logical px).'],
  ['font.letterSpacing', 'UpLetterSpacings', 'Letter spacing (logical px).'],
  ['font.lineHeight', 'UpLineHeights', 'Line height multipliers.'],
  ['typography', 'UpTextRoles', 'Text role specs. Build a TextStyle via `UpTheme.of(context).text`.'],
  ['shadow', 'UpShadows', 'Elevation shadows.'],
  ['glow', 'UpGlows', 'Glow recipes; colour is supplied at runtime.'],
  ['motion.duration', 'UpDurations', 'Motion durations.'],
  ['motion.easing', 'UpEasings', 'Motion easing curves.'],
  ['motion.spring', 'UpSprings', 'Physics spring descriptions.'],
  ['opacity', 'UpOpacities', 'Opacity scale.'],
  ['blur', 'UpBlurs', 'Blur radii (logical px).'],
  ['zIndex', 'UpZIndex', 'Stacking order.'],
  ['borderWidth', 'UpBorderWidths', 'Border widths (logical px).'],
];

export function primitiveClassOf(path) {
  const joined = path.join('.');
  let best;
  for (const [prefix, cls, doc] of PRIMITIVE_CLASSES) {
    if (joined === prefix || joined.startsWith(`${prefix}.`)) {
      if (!best || prefix.length > best.prefix.length) best = { prefix, cls, doc };
    }
  }
  if (!best) throw new Error(`No Dart class mapping for primitive ${joined}; add it to PRIMITIVE_CLASSES`);
  return { ...best, member: path.slice(best.prefix.split('.').length) };
}
