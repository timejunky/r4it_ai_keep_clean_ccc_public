/**
 * Built-in CCC fallback palettes for discussion-panel tint.
 * Colour Zen: soft wash, not opaque neon.
 * `border` = suggested IDE divider accent when AKC owns workbench (sideBar.border etc.).
 */
export const FALLBACK_PALETTES = {
  'fallback-amber': {
    id: 'fallback-amber',
    label: 'Amber',
    accent: '#d4a24c',
    wash: 'rgba(212, 162, 76, 0.28)',
    strip: '#d4a24c',
    border: '#d4a24c',
  },
  'fallback-cyan': {
    id: 'fallback-cyan',
    label: 'Cyan',
    accent: '#3db8c5',
    wash: 'rgba(61, 184, 197, 0.28)',
    strip: '#3db8c5',
    border: '#3db8c5',
  },
  'fallback-teal': {
    id: 'fallback-teal',
    label: 'Teal',
    accent: '#5ad1e8',
    wash: 'rgba(90, 209, 232, 0.28)',
    strip: '#5ad1e8',
    border: '#5ad1e8',
  },
  'fallback-green': {
    id: 'fallback-green',
    label: 'Green',
    accent: '#5de0a0',
    wash: 'rgba(93, 224, 160, 0.28)',
    strip: '#5de0a0',
    border: '#5de0a0',
  },
  'neutral-ink': {
    id: 'neutral-ink',
    label: 'Neutral',
    accent: '#8a90a0',
    wash: 'rgba(138, 144, 160, 0.16)',
    strip: '#8a90a0',
    border: '#8a90a0',
  },
};

/** Default workspaceId → paletteId when AKC accent is missing. */
export const DEFAULT_WORKSPACE_PALETTES = {
  'dev.unframed-bit.loc': 'fallback-amber',
  'horecanish.dev.ready-4-it.loc': 'fallback-cyan',
  'horecanish2.dev.ready-f-it.loc': 'fallback-cyan',
  'vetter.dev.alveos.loc': 'fallback-green',
  'r4it_releaser': 'fallback-teal',
  'r4it_ai_keep_clean_ccc': 'fallback-teal',
  'r4it_clone_ville': 'fallback-green',
  'r4it_pixel_forge': 'fallback-amber',
};
