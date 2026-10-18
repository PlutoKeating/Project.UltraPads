#!/usr/bin/env node
// UltraPads token build.
//   pnpm run build   -> regenerate Dart / CSS / JSON outputs (committed to git)
//   pnpm run check   -> build into a temp dir and fail if committed outputs are stale
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync, existsSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import StyleDictionary from 'style-dictionary';

import { componentsFile, primitivesFile, semanticSchemaFile, semanticThemeFile, themeRegistryFile } from './lib/dart.mjs';
import { layerOf, SEMANTIC_TYPES, toEntries } from './lib/model.mjs';
import { cssFile, figmaFile, flatJson } from './lib/web.mjs';
import { loadSkins, skinsDartFile, skinsJsonFile } from './lib/skins.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const TOKENS_DIR = resolve(here, '..');
const REPO = resolve(TOKENS_DIR, '../..');
const SRC = join(TOKENS_DIR, 'src');
const CHECK = process.argv.includes('--check');

const { themes } = JSON.parse(readFileSync(join(TOKENS_DIR, 'themes.config.json'), 'utf8'));

const OUT_REAL = {
  dart: join(REPO, 'packages/up_tokens/lib/src/generated'),
  css: join(TOKENS_DIR, 'build/css'),
  json: join(TOKENS_DIR, 'build/json'),
};
const tmpRoot = CHECK ? mkdtempSync(join(tmpdir(), 'up-tokens-')) : null;
const OUT = CHECK
  ? { dart: join(tmpRoot, 'dart'), css: join(tmpRoot, 'css'), json: join(tmpRoot, 'json') }
  : OUT_REAL;

// ---------------------------------------------------------------- validation
function walk(dir) {
  return readdirSync(dir).flatMap((n) => {
    const p = join(dir, n);
    return statSync(p).isDirectory() ? walk(p) : p.endsWith('.tokens.json') ? [p] : [];
  });
}

/** Flattened token paths of a DTCG file (leaf = object with $value). */
function leafPaths(obj, prefix = []) {
  const out = [];
  for (const [k, v] of Object.entries(obj)) {
    if (k.startsWith('$') || v === null || typeof v !== 'object' || Array.isArray(v)) continue;
    if ('$value' in v) out.push([...prefix, k].join('.'));
    else out.push(...leafPaths(v, [...prefix, k]));
  }
  return out;
}

const semanticBase = new Set(walk(join(SRC, 'semantic')).flatMap((f) => leafPaths(JSON.parse(readFileSync(f, 'utf8')))));
const errors = [];
for (const t of themes) {
  const dir = join(SRC, 'themes', t.id);
  if (!existsSync(dir)) { errors.push(`Theme ${t.id}: missing ${relative(REPO, dir)}`); continue; }
  for (const f of walk(dir)) {
    for (const p of leafPaths(JSON.parse(readFileSync(f, 'utf8')))) {
      if (!semanticBase.has(p)) errors.push(`${relative(REPO, f)}: "${p}" is not a semantic token (themes may only override src/semantic paths)`);
    }
  }
}
if (errors.length) fail(errors);

function fail(list) {
  console.error(`\n✖ token build failed:\n  - ${list.join('\n  - ')}\n`);
  process.exit(1);
}

// ---------------------------------------------------------------- formats
const byLayer = (dictionary) => {
  const layers = { primitive: [], semantic: [], component: [] };
  for (const t of dictionary.allTokens) layers[layerOf(t)].push(t);
  const entries = Object.fromEntries(Object.entries(layers).map(([k, v]) => [k, toEntries(v)]));
  for (const e of entries.component) {
    if (e.type === 'color' || e.type === 'gradient') {
      throw new Error(`Component token ${e.path.join('.')} is a ${e.type}; colours belong to the semantic layer`);
    }
  }
  for (const e of entries.semantic) {
    if (!SEMANTIC_TYPES.has(e.type)) {
      throw new Error(`Semantic token ${e.path.join('.')} has type ${e.type}; allowed: ${[...SEMANTIC_TYPES].join(', ')}`);
    }
  }
  return entries;
};

const collected = {};

StyleDictionary.registerFormat({ name: 'up/dart/primitives', format: ({ dictionary }) => primitivesFile(byLayer(dictionary).primitive) });
StyleDictionary.registerFormat({ name: 'up/dart/components', format: ({ dictionary }) => componentsFile(byLayer(dictionary).component) });
StyleDictionary.registerFormat({ name: 'up/dart/semantic-schema', format: ({ dictionary }) => semanticSchemaFile(byLayer(dictionary).semantic) });
StyleDictionary.registerFormat({
  name: 'up/dart/semantic-theme',
  format: ({ dictionary, options }) => {
    const entries = byLayer(dictionary);
    collected[options.theme.id] = entries;
    return semanticThemeFile(options.theme.id, entries.semantic);
  },
});
StyleDictionary.registerFormat({
  name: 'up/css/theme',
  format: ({ dictionary, options }) => cssFile(options.theme, options.isDefault, byLayer(dictionary)),
});
StyleDictionary.registerFormat({
  name: 'up/json/flat',
  format: ({ dictionary, options }) => flatJson(options.theme, byLayer(dictionary)),
});
// Values are normalised inside the formats (scripts/lib/values.mjs), so the
// transform group is intentionally empty: references are still resolved.
StyleDictionary.registerTransformGroup({ name: 'up/none', transforms: [] });

// ---------------------------------------------------------------- build
for (const dir of Object.values(OUT)) mkdirSync(dir, { recursive: true });

for (const [i, theme] of themes.entries()) {
  const isDefault = i === 0;
  const options = { theme, isDefault };
  const dartFiles = [{ destination: `semantic_${theme.id}.g.dart`, format: 'up/dart/semantic-theme', options }];
  if (isDefault) {
    dartFiles.unshift(
      { destination: 'primitives.g.dart', format: 'up/dart/primitives' },
      { destination: 'components.g.dart', format: 'up/dart/components' },
      { destination: 'semantic.g.dart', format: 'up/dart/semantic-schema' },
    );
  }
  const sd = new StyleDictionary({
    source: [
      join(SRC, 'primitive/**/*.tokens.json'),
      join(SRC, 'semantic/**/*.tokens.json'),
      join(SRC, 'component/**/*.tokens.json'),
      join(SRC, `themes/${theme.id}/**/*.tokens.json`),
    ],
    usesDtcg: true,
    log: { warnings: 'disabled', verbosity: 'silent' },
    platforms: {
      dart: { transformGroup: 'up/none', buildPath: `${OUT.dart}/`, files: dartFiles },
      css: { transformGroup: 'up/none', buildPath: `${OUT.css}/`, files: [{ destination: `${theme.id}.css`, format: 'up/css/theme', options }] },
      json: { transformGroup: 'up/none', buildPath: `${OUT.json}/`, files: [{ destination: `${theme.id}.json`, format: 'up/json/flat', options }] },
    },
  });
  try {
    await sd.buildAllPlatforms();
  } catch (e) {
    fail([e.message]);
  }
}

// cross-theme outputs
const keysOf = (id) => collected[id].semantic.map((e) => e.path.join('.')).join('\n');
for (const t of themes.slice(1)) {
  if (keysOf(t.id) !== keysOf(themes[0].id)) fail([`Theme ${t.id} semantic key set differs from ${themes[0].id}`]);
}
writeFileSync(join(OUT.dart, 'themes.g.dart'), themeRegistryFile(themes));
writeFileSync(join(OUT.json, 'figma-variables.json'), figmaFile(themes, collected));

// skin presets (semantic overrides of the original app's skins)
let skins = [];
try {
  skins = loadSkins(join(SRC, 'skins'), collected[themes[0].id], themes.map((t) => t.id));
} catch (e) {
  fail([e.message]);
}
writeFileSync(join(OUT.dart, 'skins.g.dart'), skinsDartFile(skins));
writeFileSync(join(OUT.json, 'skins.json'), skinsJsonFile(skins));

// dart format keeps generated code analyzer/format clean
const fmt = spawnSync('dart', ['format', '--language-version=3.9', '--output=write', OUT.dart], { encoding: 'utf8' });
if (fmt.status !== 0) {
  console.warn(`⚠ dart format failed or not installed; generated Dart is unformatted.\n${fmt.stderr ?? ''}`);
}

// ---------------------------------------------------------------- report / check
const counts = Object.fromEntries(['primitive', 'semantic', 'component'].map((l) => [l, collected[themes[0].id][l].length]));

if (CHECK) {
  const stale = [];
  for (const [k, dir] of Object.entries(OUT)) {
    for (const f of readdirSync(dir)) {
      const real = join(OUT_REAL[k], f);
      if (!existsSync(real) || readFileSync(real, 'utf8') !== readFileSync(join(dir, f), 'utf8')) stale.push(relative(REPO, real));
    }
  }
  rmSync(tmpRoot, { recursive: true, force: true });
  if (stale.length) fail([`generated outputs are stale, run \`just tokens\`:`, ...stale]);
  console.log('✔ token outputs are up to date');
} else {
  console.log(`✔ tokens built for themes [${themes.map((t) => t.id).join(', ')}]`);
  console.log(`  primitive: ${counts.primitive}  semantic: ${counts.semantic}  component: ${counts.component}  skin presets: ${skins.length}`);
  for (const dir of Object.values(OUT)) console.log(`  → ${relative(REPO, dir)}/`);
}
