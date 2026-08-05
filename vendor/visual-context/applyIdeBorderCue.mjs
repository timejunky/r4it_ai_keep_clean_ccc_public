// Copyright (c) 2026 ready-4-it
import fs from 'node:fs';
import path from 'node:path';
import { BORDER_TOKEN_ORDER } from './resolveVisualContext.mjs';

/**
 * Strip // and /* *\/ comments for JSONC settings files (best-effort).
 * @param {string} raw
 */
export function stripJsonc(raw) {
  return raw
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '');
}

/**
 * @param {string} settingsPath
 * @returns {Record<string, unknown>}
 */
export function readSettingsJson(settingsPath) {
  if (!fs.existsSync(settingsPath)) {
    return {};
  }
  const raw = fs.readFileSync(settingsPath, 'utf8');
  try {
    return JSON.parse(stripJsonc(raw));
  } catch {
    return JSON.parse(raw);
  }
}

/**
 * Merge border cue colors into workbench.colorCustomizations.
 * Writes into every `[Theme]` block if present, else at root.
 * Does not remove existing AKC colors.
 *
 * @param {Record<string, unknown>} settings
 * @param {string} borderColor
 * @param {string[]} [tokens]
 * @returns {{ settings: Record<string, unknown>, targets: string[] }}
 */
export function mergeBorderCueIntoSettings(settings, borderColor, tokens = BORDER_TOKEN_ORDER) {
  const next = { ...settings };
  /** @type {Record<string, unknown>} */
  const custom =
    next['workbench.colorCustomizations'] && typeof next['workbench.colorCustomizations'] === 'object'
      ? { .../** @type {Record<string, unknown>} */ (next['workbench.colorCustomizations']) }
      : {};

  const themeKeys = Object.keys(custom).filter((k) => k.startsWith('['));
  /** @type {string[]} */
  const targets = [];

  const applyToMap = (/** @type {Record<string, unknown>} */ map, label) => {
    const out = { ...map };
    for (const token of tokens) {
      out[token] = borderColor;
    }
    targets.push(label);
    return out;
  };

  if (themeKeys.length > 0) {
    for (const key of themeKeys) {
      const block = custom[key];
      if (block && typeof block === 'object') {
        custom[key] = applyToMap(/** @type {Record<string, unknown>} */ (block), key);
      }
    }
  } else {
    Object.assign(custom, applyToMap(custom, 'root'));
  }

  next['workbench.colorCustomizations'] = custom;
  return { settings: next, targets };
}

/**
 * Apply CCC-resolved border cue into a workspace's IDE settings (plugin-driven).
 * @param {string} workspacePath
 * @param {string} borderColor
 * @param {{ tokens?: string[], dryRun?: boolean }} [opts]
 */
export function applyIdeBorderCue(workspacePath, borderColor, opts = {}) {
  const vscodeDir = path.join(workspacePath, '.vscode');
  const settingsPath = path.join(vscodeDir, 'settings.json');
  const existing = readSettingsJson(settingsPath);
  const { settings, targets } = mergeBorderCueIntoSettings(existing, borderColor, opts.tokens);

  if (!opts.dryRun) {
    fs.mkdirSync(vscodeDir, { recursive: true });
    fs.writeFileSync(settingsPath, `${JSON.stringify(settings, null, 4)}\n`, 'utf8');
  }

  return {
    settingsPath,
    borderColor,
    targets,
    wrote: !opts.dryRun,
  };
}
