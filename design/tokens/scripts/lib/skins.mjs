// Skin presets: src/skins/*.skin.json -> validated semantic overrides
// (primitive references resolved) -> Dart + JSON.
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';

import { DART_HEADER } from './dart.mjs';
import { colorToHex, parseColor, toPortable } from './values.mjs';

const TECHNIQUES = ['overlay', 'tint', 'image', 'scale'];
const FIDELITY = ['full', 'partial'];

export function loadSkins(dir, entries, themeIds) {
  if (!existsSync(dir)) return [];
  const prim = new Map(entries.primitive.map((e) => [e.path.join('.'), e]));
  const sem = new Map(entries.semantic.map((e) => [e.path.join('.'), e]));
  const errors = [];
  const skins = readdirSync(dir).filter((f) => f.endsWith('.skin.json')).sort().map((f) => {
    const where = `src/skins/${f}`;
    const raw = JSON.parse(readFileSync(join(dir, f), 'utf8'));
    for (const k of ['id', 'order', 'nameKey', 'base', 'technique', 'fidelity', 'overrides']) {
      if (raw[k] === undefined) errors.push(`${where}: missing "${k}"`);
    }
    if (!themeIds.includes(raw.base)) errors.push(`${where}: unknown base theme "${raw.base}"`);
    if (!TECHNIQUES.includes(raw.technique)) errors.push(`${where}: technique must be one of ${TECHNIQUES}`);
    if (!FIDELITY.includes(raw.fidelity)) errors.push(`${where}: fidelity must be one of ${FIDELITY}`);
    if (`${raw.id}.skin.json` !== f) errors.push(`${where}: id must match the file name`);
    const overrides = {};
    for (const [key, value] of Object.entries(raw.overrides ?? {})) {
      const target = sem.get(key);
      if (!target) { errors.push(`${where}: "${key}" is not a semantic token`); continue; }
      let resolved = value;
      let type = target.type;
      if (typeof value === 'string' && /^\{[^}]+\}$/.test(value)) {
        const p = prim.get(value.slice(1, -1));
        if (!p) { errors.push(`${where}: ${key} references unknown primitive ${value}`); continue; }
        if (p.type !== type && !(type === 'number' && p.type === 'dimension') && !(type === 'dimension' && p.type === 'number')) {
          errors.push(`${where}: ${key} expects ${type} but ${value} is ${p.type}`); continue;
        }
        resolved = toPortable(p.type, p.value);
        type = p.type;
      }
      try {
        if (target.type === 'color') resolved = colorToHex(parseColor(resolved, `${where} ${key}`));
        else if (target.type === 'number' || target.type === 'dimension') {
          if (typeof resolved !== 'number') throw new Error(`${key} must be a number`);
        } else if (target.type === 'gradient') {
          if (!Array.isArray(resolved)) throw new Error(`${key} must be a gradient`);
        }
      } catch (e) { errors.push(`${where}: ${e.message}`); continue; }
      overrides[key] = resolved;
    }
    return { id: raw.id, order: raw.order, nameKey: raw.nameKey, base: raw.base, technique: raw.technique, fidelity: raw.fidelity, description: raw.$description ?? '', overrides };
  });
  if (errors.length) throw new Error(errors.join('\n  - '));
  return skins.sort((a, b) => a.order - b.order);
}

const dstr = (s) => `'${String(s).replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('$', '\\$').replaceAll('\n', '\\n')}'`;

function dartJson(v) {
  if (typeof v === 'string') return dstr(v);
  if (typeof v === 'number') return String(v);
  if (Array.isArray(v)) return `<Object>[${v.map(dartJson).join(', ')}]`;
  return `<String, Object>{${Object.entries(v).map(([k, x]) => `${dstr(k)}: ${dartJson(x)}`).join(', ')}}`;
}

export function skinsDartFile(skins) {
  return `${DART_HEADER}
import '../runtime/skin_preset.dart';

/// Original Ref 4.7.0 skins as semantic-override presets
/// (design/tokens/src/skins/*.skin.json).
abstract final class UpSkinPresets {
  static const List<UpSkinPreset> all = <UpSkinPreset>[
${skins.map((s) => `    UpSkinPreset(
      id: ${dstr(s.id)},
      order: ${s.order},
      nameKey: ${dstr(s.nameKey)},
      baseId: ${dstr(s.base)},
      technique: UpSkinTechnique.${s.technique},
      fidelity: UpSkinFidelity.${s.fidelity},
      description: ${dstr(s.description)},
      overrides: ${dartJson(s.overrides)},
    ),`).join('\n')}
  ];

  /// Preset by id, or null.
  static UpSkinPreset? byId(String id) {
    for (final UpSkinPreset p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
`;
}

export function skinsJsonFile(skins) {
  return `${JSON.stringify({ $generated: 'design/tokens/scripts/build.mjs', skins }, null, 2)}\n`;
}
