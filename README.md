# Cursor Control Center (CCC) — Free Agents Plugin

**Cursor Agents plugin** (Customize / Marketplace) — **not** a VS Code `.vsix` extension.

> **Free vs Pro:** This public repo is the **Free** edition only.  
> **CCC Pro** (Project HUD branding: patterns, custom logos, prefs export, autostart, …) is sold only on **[ready-4-it.com/ccc](https://www.ready-4-it.com/ccc)** with an `R4IT.…` license key.  
> There is **no** paid checkout on the Cursor Marketplace (Publisher Terms §3.1).

| Edition | Where | What you get |
|---|---|---|
| **Free (this repo)** | Cursor Marketplace / GitHub | Accent identity for Agents (skill + MCP + rules); optional IDE border cue |
| **CCC Pro** | [ready-4-it.com/ccc](https://www.ready-4-it.com/ccc) | Licensed Project HUD + Pro feature gates |

## Install (local)

Copy this repo into:

```text
%USERPROFILE%\.cursor\plugins\local\cursor-control-center\
```

Reload Cursor → **Customize** → search **cursor-control-center** / **CCC**.

## What Free includes

- Skill: `workspace-visual-context` — name project accent (words + hex)
- Commands: `show-workspace-visual-context`, `apply-ide-border-cue`
- MCP: `ccc-visual-context`
  - `ccc_resolve_visual_context`
  - `ccc_apply_ide_border_cue`
- Rule: speak identity; never claim Agents Glass chrome tint

## What Free does **not** include (CCC Pro)

- WinForms / Project HUD host over Agents
- Pattern markers, custom logos, logo→URL
- Prefs export/import, autostart
- License activation UI

**Upgrade:** https://www.ready-4-it.com/ccc — paste the license key in the Pro HUD (Einstellungen → Lizenz).

## Logos

| File | Use |
|---|---|
| `assets/logo.png` / `logo-marketplace-128.png` | Marketplace / plugin tile (128×128) |
| `assets/logo-about-32.png` | Small / About |
| `assets/logo-social-1200.png` | Social / store preview |

## License

MIT for this Free Agents plugin. Pro product terms apply on ready-4-it.com/ccc.
