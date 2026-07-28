#!/usr/bin/env node
/**
 * CCC visual-context MCP — public / Free Agents plugin.
 * Resolve accent + optional IDE border cue. No WinForms HUD / license host here.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pluginRoot = path.join(__dirname, '..');
const vendorVc = path.join(pluginRoot, 'vendor', 'visual-context');
const vendorCcc = path.join(pluginRoot, 'vendor', 'ccc');

async function loadMods() {
  const resolveUrl = pathToFileURL(path.join(vendorVc, 'resolveVisualContext.mjs')).href;
  const persistUrl = pathToFileURL(path.join(vendorVc, 'persistConfig.mjs')).href;
  const applyUrl = pathToFileURL(path.join(vendorVc, 'applyIdeBorderCue.mjs')).href;
  const resolveMod = await import(resolveUrl);
  const persistMod = await import(persistUrl);
  const applyMod = await import(applyUrl);
  return { ...resolveMod, ...persistMod, ...applyMod };
}

function send(msg) {
  process.stdout.write(`${JSON.stringify(msg)}\n`);
}

function ok(id, result) {
  send({ jsonrpc: '2.0', id, result });
}

function fail(id, code, message) {
  send({ jsonrpc: '2.0', id, error: { code, message } });
}

const TOOLS = [
  {
    name: 'ccc_resolve_visual_context',
    description:
      'Resolve CCC workspace visual identity (accent, palette, IDE border cue). Does not change Agents chrome.',
    inputSchema: {
      type: 'object',
      properties: {
        workspacePath: { type: 'string', description: 'Absolute path to the workspace folder' },
        label: { type: 'string', description: 'Optional display label' },
      },
      required: ['workspacePath'],
    },
  },
  {
    name: 'ccc_apply_ide_border_cue',
    description:
      'Apply CCC border cue into the workspace .vscode/settings.json (sideBar.border and related AKC tokens).',
    inputSchema: {
      type: 'object',
      properties: {
        workspacePath: { type: 'string', description: 'Absolute path to the workspace folder' },
        label: { type: 'string', description: 'Optional display label' },
      },
      required: ['workspacePath'],
    },
  },
];

/** @type {Awaited<ReturnType<typeof loadMods>> | null} */
let mods = null;

async function ensureMods() {
  if (!mods) mods = await loadMods();
  return mods;
}

function configPath() {
  return path.join(vendorCcc, 'visual-context.json');
}

const PRO_FOOTER =
  '\n\n—\nCCC Free Agents plugin. Project HUD / branding (patterns, logos, prefs) = CCC Pro → https://www.ready-4-it.com/ccc (not Marketplace checkout).';

async function handleResolve(args) {
  const m = await ensureMods();
  const config = m.loadVisualContextConfig(configPath());
  const ctx = m.resolveVisualContext(args.workspacePath, config);
  const card = m.formatIdentityCard(ctx, args.label);
  return { card, context: ctx };
}

async function handleApply(args) {
  const m = await ensureMods();
  const config = m.loadVisualContextConfig(configPath());
  const ctx = m.resolveVisualContext(args.workspacePath, config);
  const applied = m.applyIdeBorderCue(args.workspacePath, ctx.border);
  const card = m.formatIdentityCard(ctx, args.label);
  return {
    card,
    applied,
    context: ctx,
    note: 'IDE border cue written. Agents Glass chrome stays untinted (no Cursor plugin API yet).',
  };
}

let buffer = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', async (chunk) => {
  buffer += chunk;
  let idx;
  while ((idx = buffer.indexOf('\n')) >= 0) {
    const line = buffer.slice(0, idx).trim();
    buffer = buffer.slice(idx + 1);
    if (!line) continue;
    /** @type {{ id?: unknown, method?: string, params?: Record<string, unknown> }} */
    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      continue;
    }
    const id = msg.id;
    try {
      if (msg.method === 'initialize') {
        ok(id, {
          protocolVersion: '2024-11-05',
          capabilities: { tools: {} },
          serverInfo: { name: 'ccc-visual-context', version: '0.2.0' },
        });
        continue;
      }
      if (msg.method === 'notifications/initialized') continue;
      if (msg.method === 'tools/list') {
        ok(id, { tools: TOOLS });
        continue;
      }
      if (msg.method === 'tools/call') {
        const params = /** @type {{ name?: string, arguments?: Record<string, string> }} */ (
          msg.params || {}
        );
        const name = params.name;
        const args = params.arguments || {};
        if (name === 'ccc_resolve_visual_context') {
          const result = await handleResolve(args);
          ok(id, {
            content: [
              {
                type: 'text',
                text: `${result.card}\n\n${JSON.stringify(result.context, null, 2)}${PRO_FOOTER}`,
              },
            ],
          });
          continue;
        }
        if (name === 'ccc_apply_ide_border_cue') {
          const result = await handleApply(args);
          ok(id, {
            content: [
              {
                type: 'text',
                text: `${result.card}\n\nApplied: ${JSON.stringify(result.applied, null, 2)}\n${result.note}${PRO_FOOTER}`,
              },
            ],
          });
          continue;
        }
        fail(id, -32601, `Unknown tool: ${name}`);
        continue;
      }
      if (id !== undefined) fail(id, -32601, `Method not found: ${msg.method}`);
    } catch (err) {
      const message = err && err.message ? err.message : String(err);
      if (id !== undefined) fail(id, -32000, message);
    }
  }
});

if (!fs.existsSync(path.join(vendorVc, 'resolveVisualContext.mjs'))) {
  console.error('CCC MCP: vendor/visual-context missing — sync from private DEV via releaser sync_public_ccc.ps1.');
}
