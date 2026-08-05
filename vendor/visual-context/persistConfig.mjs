// Copyright (c) 2026 ready-4-it
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_STORE = path.join(__dirname, '..', '..', '.ccc', 'visual-context.json');

/**
 * @typedef {import('./resolveVisualContext.mjs').VisualContextConfig} VisualContextConfig
 */

/**
 * @param {unknown} data
 * @returns {VisualContextConfig}
 */
function normalizeVisualContextConfig(data) {
  const d = data && typeof data === 'object' ? data : {};
  return {
    source: 'akc-accent-first',
    applySurfaces: d.applySurfaces || ['discussionPanel'],
    tintStrength: typeof d.tintStrength === 'number' ? d.tintStrength : 0.35,
    defaultPaletteId: d.defaultPaletteId || 'neutral-ink',
    workspacePalettes: d.workspacePalettes || {},
    manualOverrides: d.manualOverrides || {},
  };
}

/**
 * @param {string} [storePath]
 * @returns {VisualContextConfig}
 */
export function loadVisualContextConfig(storePath = DEFAULT_STORE) {
  const empty = normalizeVisualContextConfig(null);
  let base = empty;
  if (fs.existsSync(storePath)) {
    try {
      base = normalizeVisualContextConfig(JSON.parse(fs.readFileSync(storePath, 'utf8')));
    } catch {
      base = empty;
    }
  }
  const localPath = path.join(path.dirname(storePath), 'visual-context.local.json');
  if (!fs.existsSync(localPath)) return base;
  try {
    const local = normalizeVisualContextConfig(JSON.parse(fs.readFileSync(localPath, 'utf8')));
    return {
      ...base,
      ...local,
      workspacePalettes: { ...base.workspacePalettes, ...local.workspacePalettes },
      manualOverrides: { ...base.manualOverrides, ...local.manualOverrides },
    };
  } catch {
    return base;
  }
}

/**
 * @param {VisualContextConfig} config
 * @param {string} [storePath]
 */
export function saveVisualContextConfig(config, storePath = DEFAULT_STORE) {
  fs.mkdirSync(path.dirname(storePath), { recursive: true });
  const payload = {
    source: 'akc-accent-first',
    applySurfaces: config.applySurfaces || ['discussionPanel'],
    tintStrength: typeof config.tintStrength === 'number' ? config.tintStrength : 0.35,
    defaultPaletteId: config.defaultPaletteId || 'neutral-ink',
    workspacePalettes: config.workspacePalettes || {},
    manualOverrides: config.manualOverrides || {},
  };
  fs.writeFileSync(storePath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
  return storePath;
}

export { DEFAULT_STORE };
