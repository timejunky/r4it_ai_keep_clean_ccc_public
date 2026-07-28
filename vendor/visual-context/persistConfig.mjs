import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_STORE = path.join(__dirname, '..', '..', '.ccc', 'visual-context.json');

/**
 * @typedef {import('./resolveVisualContext.mjs').VisualContextConfig} VisualContextConfig
 */

/**
 * @param {string} [storePath]
 * @returns {VisualContextConfig}
 */
export function loadVisualContextConfig(storePath = DEFAULT_STORE) {
  if (!fs.existsSync(storePath)) {
    return {
      source: 'akc-accent-first',
      applySurfaces: ['discussionPanel'],
      tintStrength: 0.35,
      defaultPaletteId: 'neutral-ink',
      workspacePalettes: {},
      manualOverrides: {},
    };
  }
  try {
    const data = JSON.parse(fs.readFileSync(storePath, 'utf8'));
    return {
      source: 'akc-accent-first',
      applySurfaces: data.applySurfaces || ['discussionPanel'],
      tintStrength: typeof data.tintStrength === 'number' ? data.tintStrength : 0.35,
      defaultPaletteId: data.defaultPaletteId || 'neutral-ink',
      workspacePalettes: data.workspacePalettes || {},
      manualOverrides: data.manualOverrides || {},
    };
  } catch {
    return {
      source: 'akc-accent-first',
      applySurfaces: ['discussionPanel'],
      tintStrength: 0.35,
      defaultPaletteId: 'neutral-ink',
      workspacePalettes: {},
      manualOverrides: {},
    };
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
