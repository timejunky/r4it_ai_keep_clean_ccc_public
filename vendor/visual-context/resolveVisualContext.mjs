import fs from 'node:fs';
import path from 'node:path';
import {
  DEFAULT_WORKSPACE_PALETTES,
  FALLBACK_PALETTES,
} from './palettes.mjs';

const ACCENT_TOKEN_ORDER = [
  'titleBar.activeBackground',
  'activityBar.background',
  'statusBar.background',
  'sideBar.background',
];

/** IDE divider / column-edge tokens (AKC-owned; not Agents chrome). */
export const BORDER_TOKEN_ORDER = [
  'sideBar.border',
  'activityBar.border',
  'editorGroup.border',
  'panel.border',
  'editorGroupHeader.tabsBorder',
];

/**
 * @param {unknown} value
 * @returns {value is string}
 */
function isHexColor(value) {
  return typeof value === 'string' && /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(value.trim());
}

/**
 * Flatten workbench.colorCustomizations: prefer root tokens, else first theme block.
 * @param {Record<string, unknown>} customizations
 * @returns {Record<string, string>}
 */
export function flattenColorCustomizations(customizations) {
  if (!customizations || typeof customizations !== 'object') {
    return {};
  }
  /** @type {Record<string, string>} */
  const flat = {};
  for (const [key, value] of Object.entries(customizations)) {
    if (typeof value === 'string' && isHexColor(value)) {
      flat[key] = value.trim();
    }
  }
  if (Object.keys(flat).length > 0) {
    return flat;
  }
  for (const [key, value] of Object.entries(customizations)) {
    if (key.startsWith('[') && value && typeof value === 'object') {
      for (const [token, color] of Object.entries(/** @type {Record<string, unknown>} */ (value))) {
        if (typeof color === 'string' && isHexColor(color)) {
          flat[token] = color.trim();
        }
      }
      if (Object.keys(flat).length > 0) {
        return flat;
      }
    }
  }
  return flat;
}

/**
 * @param {Record<string, string>} flat
 * @returns {{ token: string, color: string } | null}
 */
export function pickAccentToken(flat) {
  for (const token of ACCENT_TOKEN_ORDER) {
    if (isHexColor(flat[token])) {
      return { token, color: flat[token] };
    }
  }
  const first = Object.entries(flat).find(([, color]) => isHexColor(color));
  return first ? { token: first[0], color: first[1] } : null;
}

/**
 * @param {Record<string, string>} flat
 * @returns {{ token: string, color: string } | null}
 */
export function pickBorderToken(flat) {
  for (const token of BORDER_TOKEN_ORDER) {
    if (isHexColor(flat[token])) {
      return { token, color: flat[token] };
    }
  }
  return null;
}

/**
 * Soft wash from solid hex + tintStrength (0–1).
 * @param {string} hex
 * @param {number} tintStrength
 */
export function hexToWash(hex, tintStrength = 0.35) {
  const raw = hex.replace('#', '');
  const full = raw.length === 3 ? raw.split('').map((c) => c + c).join('') : raw.slice(0, 6);
  const r = Number.parseInt(full.slice(0, 2), 16);
  const g = Number.parseInt(full.slice(2, 4), 16);
  const b = Number.parseInt(full.slice(4, 6), 16);
  const a = Math.min(0.55, Math.max(0.12, tintStrength));
  return `rgba(${r}, ${g}, ${b}, ${a})`;
}

/**
 * @param {string} workspacePath
 */
export function workspaceIdFromPath(workspacePath) {
  const normalized = workspacePath.replace(/\\/g, '/').replace(/\/+$/, '');
  return path.basename(normalized);
}

/**
 * Read AKC / IDE color customizations for a workspace folder.
 * @param {string} workspacePath
 * @returns {{ flat: Record<string, string>, accent: { token: string, color: string } | null, border: { token: string, color: string } | null, settingsPath: string | null }}
 */
export function readAkcAccent(workspacePath) {
  const settingsPath = path.join(workspacePath, '.vscode', 'settings.json');
  if (!fs.existsSync(settingsPath)) {
    return { flat: {}, accent: null, border: null, settingsPath: null };
  }
  try {
    const raw = fs.readFileSync(settingsPath, 'utf8');
    const data = JSON.parse(raw);
    const flat = flattenColorCustomizations(data['workbench.colorCustomizations'] || {});
    return {
      flat,
      accent: pickAccentToken(flat),
      border: pickBorderToken(flat),
      settingsPath,
    };
  } catch {
    return { flat: {}, accent: null, border: null, settingsPath };
  }
}

/**
 * @typedef {object} VisualContextConfig
 * @property {'akc-accent-first'} [source]
 * @property {string[]} [applySurfaces]
 * @property {number} [tintStrength]
 * @property {Record<string, string>} [workspacePalettes]
 * @property {string} [defaultPaletteId]
 * @property {Record<string, string>} [manualOverrides] workspaceId → paletteId
 */

/**
 * Resolve discussion-panel visual context for a workspace path.
 * CCC never writes IDE workbench.colorCustomizations — read only.
 *
 * @param {string} workspacePath
 * @param {VisualContextConfig} [config]
 */
export function resolveVisualContext(workspacePath, config = {}) {
  const tintStrength = typeof config.tintStrength === 'number' ? config.tintStrength : 0.35;
  const defaultPaletteId = config.defaultPaletteId || 'neutral-ink';
  const workspacePalettes = {
    ...DEFAULT_WORKSPACE_PALETTES,
    ...(config.workspacePalettes || {}),
  };
  const manualOverrides = config.manualOverrides || {};
  const workspaceId = workspaceIdFromPath(workspacePath);

  const manualId = manualOverrides[workspaceId];
  if (manualId && FALLBACK_PALETTES[manualId]) {
    const palette = FALLBACK_PALETTES[manualId];
    return {
      workspaceId,
      workspacePath,
      source: 'manual-override',
      paletteId: palette.id,
      paletteLabel: palette.label,
      accent: palette.accent,
      wash: palette.wash,
      strip: palette.strip,
      border: palette.border,
      borderToken: null,
      tintStrength,
      applySurfaces: config.applySurfaces || ['discussionPanel'],
    };
  }

  const akc = readAkcAccent(workspacePath);
  if (akc.accent) {
    const borderColor = akc.border?.color || akc.accent.color;
    return {
      workspaceId,
      workspacePath,
      source: 'akc-accent',
      paletteId: null,
      paletteLabel: null,
      accent: akc.accent.color,
      accentToken: akc.accent.token,
      wash: hexToWash(akc.accent.color, tintStrength),
      strip: akc.accent.color,
      border: borderColor,
      borderToken: akc.border?.token || null,
      tintStrength,
      applySurfaces: config.applySurfaces || ['discussionPanel'],
      settingsPath: akc.settingsPath,
    };
  }

  const paletteId = workspacePalettes[workspaceId] || defaultPaletteId;
  const palette = FALLBACK_PALETTES[paletteId] || FALLBACK_PALETTES['neutral-ink'];
  return {
    workspaceId,
    workspacePath,
    source: 'ccc-fallback',
    paletteId: palette.id,
    paletteLabel: palette.label,
    accent: palette.accent,
    wash: palette.wash,
    strip: palette.strip,
    border: palette.border,
    borderToken: null,
    tintStrength,
    applySurfaces: config.applySurfaces || ['discussionPanel'],
  };
}

/**
 * Short identity card for Agent replies (verbal accent — Agents chrome cannot tint yet).
 * @param {ReturnType<typeof resolveVisualContext>} ctx
 * @param {string} [label]
 */
export function formatIdentityCard(ctx, label) {
  const name = label || ctx.workspaceId;
  const palette = ctx.paletteLabel || ctx.paletteId || '—';
  const borderTok = ctx.borderToken ? ` (${ctx.borderToken})` : ' (suggested for AKC IDE)';
  return [
    `Workspace identity: ${name}`,
    `Id: ${ctx.workspaceId}`,
    `Source: ${ctx.source}`,
    `Accent: ${ctx.accent}${ctx.accentToken ? ` ← ${ctx.accentToken}` : ''}`,
    `Palette: ${palette}`,
    `IDE border cue: ${ctx.border}${borderTok}`,
    'Note: Agents chrome stays untinted. IDE border cue is applied by the CCC Agent plugin (MCP ccc_apply_ide_border_cue).',
  ].join('\n');
}

/**
 * CSS custom properties for the discussion panel.
 * @param {ReturnType<typeof resolveVisualContext>} ctx
 */
export function discussionPanelCssVars(ctx) {
  return {
    '--ccc-discussion-wash': ctx.wash,
    '--ccc-discussion-strip': ctx.strip,
    '--ccc-discussion-accent': ctx.accent,
    '--ccc-discussion-border': ctx.border,
  };
}
