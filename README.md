# AI Keep Clean Context Control Center (CCC) — Free / Light Agents Plugin

<p align="center">
  <img src="assets/logo.png" alt="AI Keep Clean Context Control Center" width="128" height="128" />
</p>

**ready-4-it / AI Keep Clean** Agents plugin — **project identity** for multi-repo chats.

**CCC** = *AI Keep Clean Context Control Center* (AKC sibling). This GitHub repo serves **two Free channels** without mixing formats:

| Channel | Path | Host |
|---|---|---|
| **Cursor Agents** | `.cursor-plugin/` at repo root | Cursor Customize / local plugins |
| **VS Code Agents** | `.claude-plugin/marketplace.json` + `plugins/akc-ccc/` | VS Code / Copilot Chat agent plugins |

The **VS Code Control Center** (sidebar) is a separate Free **VSIX**: Marketplace / Open VSX `ready-4-it.akc-ccc-vs` — not this Agents package.

> **This light edition has no license input.**  
> There is only a pointer to **CCC Pro**: [https://www.ready-4-it.com/akc_ccc](https://www.ready-4-it.com/akc_ccc)  
> Activation keys exist **only** in the paid Pro product — never in this repo / Marketplace listing.

| Edition | Where | What |
|---|---|---|
| **Free / Light (this repo)** | Cursor Agents + VS Code Agents (GitHub) | Accent identity (skill + MCP + rules); optional IDE border cue; **Pro link only** |
| **Free VSIX companion** | Marketplace / Open VSX `ready-4-it.akc-ccc-vs` | Control Center + bridge (not the Agents plugin itself) |
| **CCC Trial / Pro** | [ready-4-it.com/akc_ccc](https://www.ready-4-it.com/akc_ccc) + Zebra `akc_ccc` | Licensed **extension** of Free: Project HUD, branding gates, device activation (`product_id` ccc). One license covers Cursor + VS Code. **Not** listed as a second paid Agents catalog item. |

Marketplace / Agents listings stay free of charge. No paid checkout here.

## Why CCC?

Working in several Cursor Agents projects at once? Free CCC names the active workspace accent (words + hex) and can apply an IDE border cue. **Pro** adds the always-on **Project HUD** so you always know which repo the current chat belongs to.

## CCC Pro (extension of this Free plugin)

Want the Agents Project HUD (patterns, custom logos, prefs packs, …)?

1. Buy Trial/Pro → **[https://www.ready-4-it.com/akc_ccc](https://www.ready-4-it.com/akc_ccc)**  
2. Install licensed package / activate device in the Project HUD. Further updates: HUD About → Zebra (`akc_ccc`) with stored license token — auto-apply into Cursor licensed Agents.  
3. Bootstrap once via My Licenses ZIP only if HUD/auto-update is not available yet.

Do **not** look for a license field in this Free plugin or in `@agentPlugins` — Pro is intentionally **not** a second marketplace listing.

## Install — Cursor Agents

**Counted install (recommended):** download the latest release ZIP from
[GitHub Releases](https://github.com/timejunky/r4it_ai_keep_clean_ccc_public/releases)
(`akc_ccc_public_x.y.z.zip`) and extract into:

```text
%USERPROFILE%\.cursor\plugins\local\ai-keep-clean-ccc\
```

The HUD **About → Check for updates** (Free, no license) uses the same release asset when
available so installs and in-app updates are counted consistently.

**From source / git:** clone or copy this repo into the same folder (not counted as a release
download). Use the release ZIP when you need a stable, counted package.

Copy this repo into:

```text
%USERPROFILE%\.cursor\plugins\local\ai-keep-clean-ccc\
```

Reload Cursor → **Agents → Customize → Plugins** → enable **ai-keep-clean-ccc** (Installed / Local).

## Install — VS Code Agents / GitHub Copilot Chat

Free **agent plugin** (not the VSIX). Enable plugins, then add this repo as a marketplace:

```json
"chat.plugins.enabled": true,
"chat.plugins.marketplaces": [
  "timejunky/r4it_ai_keep_clean_ccc_public"
]
```

Or Command Palette → **Chat: Install Plugin From Source** → `timejunky/r4it_ai_keep_clean_ccc_public`.

Then Extensions → search `@agentPlugins` → install **akc-ccc** (package under `plugins/akc-ccc/`).

Optional companion: install VSIX **AKC CCC VS** (`ready-4-it.akc-ccc-vs`) for the Control Center panel; use **Activate** to register a local copy via `chat.pluginLocations`.

## What Free includes

- Skill: `workspace-visual-context` — name project accent (words + hex)
- Commands: `show-workspace-visual-context`, `apply-ide-border-cue`
- MCP: `ccc-visual-context`
  - `ccc_resolve_visual_context`
  - `ccc_apply_ide_border_cue`
- Rule: workspace visual identity reminder

## What Free does **not** include

- WinForms Project HUD
- Aktivierungsschlüssel / device slots
- Pro feature gates (patterns, custom logos, prefs export, autostart, …)

## Legal (copyright / freemium)

Copyright (c) 2026 ready-4-it / Nejat Philip Eryigit. All rights reserved.
This **public Free / Light** edition is the free tier of a **freemium** product
(not MIT / not OSI open-source). Trial/Pro is a separate paid license. See [`LICENSE`](LICENSE).

It is provided **as-is**, **without warranty**, **without liability** beyond mandatory law, and **without support obligation**.

Trial/Pro downloads, activation, and in-app updates may use the ready-4-it **streamingZebra** platform (`api.streamingzebra.com`). Full terms:

- [streamingZebra Terms](https://www.streamingzebra.com/terms)
- [streamingZebra Privacy](https://www.streamingzebra.com/privacy)
- [ready-4-it corporate terms](https://www.ready-4-it.com/terms)

**streamingZebra** is a ready-4-it delivery name. **Cursor**, **VS Code**, and **Copilot** are trademarks of their respective owners — this plugin is **not** affiliated with or endorsed by them.

Licensed ZIP packages include `legal/LEGAL.en.md` (and `LEGAL.de.md`).

## Support

- Store / Pro: https://www.ready-4-it.com/akc_ccc  
- Email: support@ready-4-it.com  
