// CSS custom properties + flat JSON + Figma variables outputs.
import { kebab } from './model.mjs';
import { colorToCss, colorToHex, num, toPortable } from './values.mjs';

const px = (n) => `${num(n)}px`;

function cssValue(e) {
  const v = e.value;
  switch (e.type) {
    case 'color': return [['', colorToCss(v)]];
    case 'dimension': return [['', px(v)]];
    case 'number': return [['', num(v)]];
    case 'duration': return [['', `${num(v)}ms`]];
    case 'cubicBezier': return [['', `cubic-bezier(${v.map(num).join(', ')})`]];
    case 'fontWeight': return [['', num(v)]];
    case 'fontFamily': return [['', v.map((f) => `"${f}"`).join(', ')]];
    case 'gradient': return [['', `linear-gradient(180deg, ${v.map((s) => `${colorToCss(s.color)} ${num(s.position * 100)}%`).join(', ')})`]];
    case 'shadow':
      if (v.length === 0) return [['', 'none']];
      return [['', v.map((l) => `${l.inset ? 'inset ' : ''}${px(l.x)} ${px(l.y)} ${px(l.blur)} ${px(l.spread)} ${colorToCss(l.color)}`).join(', ')]];
    case 'typography':
      return [
        ['font-family', v.fontFamily.map((f) => `"${f}"`).join(', ')],
        ['font-weight', num(v.fontWeight)],
        ['font-size', px(v.fontSize)],
        ['letter-spacing', px(v.letterSpacing)],
        ['line-height', num(v.lineHeight)],
        ['text-transform', e.textCase === 'upper' ? 'uppercase' : 'none'],
      ];
    case 'spring':
      return [['stiffness', num(v.stiffness)], ['damping', num(v.damping)], ['mass', num(v.mass)]];
    default:
      throw new Error(`No CSS mapping for ${e.type}`);
  }
}

export function cssFile(theme, isDefault, layers) {
  const selector = isDefault ? `:root,\n[data-up-theme="${theme.id}"]` : `[data-up-theme="${theme.id}"]`;
  const out = [`/* GENERATED CODE - DO NOT MODIFY BY HAND. Theme: ${theme.id} (${theme.brightness}). Source: design/tokens/src */`, `${selector} {`, `  color-scheme: ${theme.brightness};`];
  for (const [layer, entries] of Object.entries(layers)) {
    out.push(`\n  /* ${layer} */`);
    for (const e of entries) {
      for (const [suffix, value] of cssValue(e)) {
        out.push(`  --up-${kebab(e.path)}${suffix ? `-${suffix}` : ''}: ${value};`);
      }
    }
  }
  out.push('}\n');
  return out.join('\n');
}

export function flatJson(theme, layers) {
  const tokens = {};
  for (const [layer, entries] of Object.entries(layers)) {
    for (const e of entries) {
      tokens[e.path.join('.')] = { layer, type: e.type, value: toPortable(e.type, e.value) };
    }
  }
  return `${JSON.stringify({ $generated: 'design/tokens/scripts/build.mjs', theme: theme.id, brightness: theme.brightness, tokens }, null, 2)}\n`;
}

const FIGMA_TYPE = { color: 'COLOR', dimension: 'FLOAT', number: 'FLOAT', duration: 'FLOAT', fontWeight: 'FLOAT', fontFamily: 'STRING' };

function figmaValue(e) {
  switch (e.type) {
    case 'color': return colorToHex(e.value);
    case 'fontFamily': return e.value[0];
    default: return e.value;
  }
}

/**
 * Figma Variables import file: one collection per layer, semantic collection
 * has one mode per theme. Composite tokens (shadow/gradient/typography/...)
 * are not expressible as Figma variables and are listed under `styles`.
 */
export function figmaFile(themes, perTheme) {
  const first = perTheme[themes[0].id];
  const collections = [];
  for (const layer of ['primitive', 'component']) {
    collections.push({
      name: layer === 'primitive' ? 'Primitives' : 'Components',
      modes: ['default'],
      variables: first[layer].filter((e) => FIGMA_TYPE[e.type]).map((e) => ({
        name: e.path.join('/'), type: FIGMA_TYPE[e.type], values: { default: figmaValue(e) },
      })),
    });
  }
  const sem = first.semantic.filter((e) => FIGMA_TYPE[e.type]);
  collections.push({
    name: 'Semantic',
    modes: themes.map((t) => t.id),
    variables: sem.map((e) => {
      const key = e.path.join('.');
      const values = {};
      for (const t of themes) values[t.id] = figmaValue(perTheme[t.id].semantic.find((x) => x.path.join('.') === key));
      return { name: e.path.join('/'), type: FIGMA_TYPE[e.type], values };
    }),
  });
  const styles = [];
  for (const layer of ['primitive', 'semantic', 'component']) {
    for (const e of first[layer]) {
      if (!FIGMA_TYPE[e.type]) styles.push({ name: e.path.join('/'), layer, type: e.type, value: toPortable(e.type, e.value) });
    }
  }
  return `${JSON.stringify({ $generated: 'design/tokens/scripts/build.mjs', collections, styles }, null, 2)}\n`;
}
