// Normalisation helpers: DTCG token values -> plain JS values used by every
// output format (Dart, CSS, flat JSON). Keep all unit handling here.

const HEX = /^#([0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})$/i;

/** Returns {r,g,b,a} with r/g/b in 0..255 and a in 0..1. */
export function parseColor(value, where = '') {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    // DTCG 2025 colour object: { colorSpace: 'srgb', components: [r,g,b], alpha, hex }
    if (typeof value.hex === 'string') {
      const c = parseColor(value.hex, where);
      if (typeof value.alpha === 'number') c.a = value.alpha;
      return c;
    }
    if (value.colorSpace === 'srgb' && Array.isArray(value.components)) {
      const [r, g, b] = value.components.map((x) => Math.round(x * 255));
      return { r, g, b, a: typeof value.alpha === 'number' ? value.alpha : 1 };
    }
  }
  if (typeof value !== 'string' || !HEX.test(value)) {
    throw new Error(`Invalid colour ${JSON.stringify(value)} ${where}`);
  }
  let h = value.slice(1);
  if (h.length <= 4) h = [...h].map((c) => c + c).join('');
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  const a = h.length === 8 ? parseInt(h.slice(6, 8), 16) / 255 : 1;
  return { r, g, b, a };
}

const hx = (n) => n.toString(16).padStart(2, '0').toUpperCase();
export const alpha255 = (a) => Math.round(a * 255);

/** #RRGGBB or #RRGGBBAA (alpha only when < 1). */
export function colorToHex(c) {
  const base = `#${hx(c.r)}${hx(c.g)}${hx(c.b)}`;
  return c.a >= 1 ? base : base + hx(alpha255(c.a));
}

/** 0xAARRGGBB literal for Dart. */
export function colorToArgbLiteral(c) {
  return `0x${hx(alpha255(c.a))}${hx(c.r)}${hx(c.g)}${hx(c.b)}`;
}

export function colorToCss(c) {
  if (c.a >= 1) return colorToHex(c).toLowerCase();
  return `rgba(${c.r}, ${c.g}, ${c.b}, ${round(c.a, 3)})`;
}

/** Dimension -> logical pixels (number). */
export function parseDimension(value, where = '') {
  if (typeof value === 'number') return value;
  if (value && typeof value === 'object' && typeof value.value === 'number') {
    if (value.unit === 'px' || value.unit === undefined) return value.value;
    if (value.unit === 'rem') return value.value * 16;
    throw new Error(`Unsupported dimension unit ${value.unit} ${where}`);
  }
  if (typeof value === 'string') {
    const m = /^(-?\d*\.?\d+)(px|rem)?$/.exec(value.trim());
    if (m) return m[2] === 'rem' ? Number(m[1]) * 16 : Number(m[1]);
  }
  throw new Error(`Invalid dimension ${JSON.stringify(value)} ${where}`);
}

/** Duration -> milliseconds (number). */
export function parseDuration(value, where = '') {
  if (typeof value === 'number') return value;
  if (value && typeof value === 'object' && typeof value.value === 'number') {
    if (value.unit === 'ms') return value.value;
    if (value.unit === 's') return value.value * 1000;
  }
  if (typeof value === 'string') {
    const m = /^(\d*\.?\d+)(ms|s)$/.exec(value.trim());
    if (m) return m[2] === 's' ? Number(m[1]) * 1000 : Number(m[1]);
  }
  throw new Error(`Invalid duration ${JSON.stringify(value)} ${where}`);
}

export function parseCubic(value, where = '') {
  if (Array.isArray(value) && value.length === 4 && value.every((n) => typeof n === 'number')) {
    return value;
  }
  throw new Error(`Invalid cubicBezier ${JSON.stringify(value)} ${where}`);
}

export function parseNumber(value, where = '') {
  if (typeof value === 'number') return value;
  throw new Error(`Invalid number ${JSON.stringify(value)} ${where}`);
}

const WEIGHT_KEYWORDS = {
  thin: 100, hairline: 100, 'extra-light': 200, 'ultra-light': 200, light: 300,
  normal: 400, regular: 400, book: 400, medium: 500, 'semi-bold': 600, 'demi-bold': 600,
  bold: 700, 'extra-bold': 800, 'ultra-bold': 800, black: 900, heavy: 900,
};

export function parseFontWeight(value, where = '') {
  if (typeof value === 'number') return value;
  if (typeof value === 'string' && WEIGHT_KEYWORDS[value] !== undefined) return WEIGHT_KEYWORDS[value];
  throw new Error(`Invalid fontWeight ${JSON.stringify(value)} ${where}`);
}

export function parseFontFamily(value, where = '') {
  if (typeof value === 'string') return [value];
  if (Array.isArray(value) && value.every((s) => typeof s === 'string')) return value;
  throw new Error(`Invalid fontFamily ${JSON.stringify(value)} ${where}`);
}

export function parseShadow(value, where = '') {
  const layers = Array.isArray(value) ? value : [value];
  return layers.map((l) => ({
    color: parseColor(l.color, where),
    x: parseDimension(l.offsetX ?? 0, where),
    y: parseDimension(l.offsetY ?? 0, where),
    blur: parseDimension(l.blur ?? 0, where),
    spread: parseDimension(l.spread ?? 0, where),
    inset: Boolean(l.inset),
  }));
}

export function parseGradient(value, where = '') {
  if (!Array.isArray(value) || value.length < 2) {
    throw new Error(`Invalid gradient ${JSON.stringify(value)} ${where}`);
  }
  return value.map((s) => ({ color: parseColor(s.color, where), position: parseNumber(s.position, where) }));
}

export function parseTypography(value, where = '') {
  return {
    fontFamily: parseFontFamily(value.fontFamily, where),
    fontWeight: parseFontWeight(value.fontWeight, where),
    fontSize: parseDimension(value.fontSize, where),
    letterSpacing: parseDimension(value.letterSpacing ?? 0, where),
    lineHeight: parseNumber(value.lineHeight ?? 1, where),
  };
}

/** Parse any supported token into {type, value}. */
export function normalize(token) {
  const where = `at ${token.path.join('.')}`;
  const v = token.$value;
  switch (token.$type) {
    case 'color': return parseColor(v, where);
    case 'dimension': return parseDimension(v, where);
    case 'duration': return parseDuration(v, where);
    case 'cubicBezier': return parseCubic(v, where);
    case 'number': return parseNumber(v, where);
    case 'fontWeight': return parseFontWeight(v, where);
    case 'fontFamily': return parseFontFamily(v, where);
    case 'shadow': return parseShadow(v, where);
    case 'gradient': return parseGradient(v, where);
    case 'typography': return parseTypography(v, where);
    default: throw new Error(`Unsupported $type ${token.$type} ${where}`);
  }
}

export function round(n, digits = 4) {
  const f = 10 ** digits;
  return Math.round(n * f) / f;
}

/** Number literal valid in Dart and CSS (no exponent). */
export function num(n) {
  const r = round(n, 4);
  return Object.is(r, -0) ? '0' : String(r);
}

/** JSON-friendly value used by flat JSON / figma export. */
export function toPortable(type, v) {
  switch (type) {
    case 'color': return colorToHex(v);
    case 'gradient': return v.map((s) => ({ color: colorToHex(s.color), position: s.position }));
    case 'shadow': return v.map((l) => ({ ...l, color: colorToHex(l.color) }));
    default: return v;
  }
}
