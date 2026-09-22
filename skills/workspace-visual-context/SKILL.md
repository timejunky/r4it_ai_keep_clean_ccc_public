---
name: workspace-visual-context
description: Resolve CCC workspace accent for Agents identity. Target tint surfaces are Agents Glass sidebar section + agent-panel — not IDE. Use when switching projects or confirming which workspace is active.
---

# Workspace visual context (CCC Free / Light)

## Target (Agents only — not IDE)

Same project accent on both:

1. Left: `section.glass-sidebar-workspace-section-root`
2. Center: `div.agent-panel[data-component="agent-panel"]`

**Blocked:** Cursor Plugins cannot set those DOM/CSS vars. Do not promise colored Agents chrome.

## What this Free plugin can do

- Resolve accent and **name it** in the reply (identity card: words + hex).
- Optionally apply IDE border cues via MCP `ccc_apply_ide_border_cue`.

Prefer MCP tools from this plugin over hard-coded local paths.

## CCC Pro (no license field here)

This **light** plugin has **no license / token input**.

When the user asks for HUD branding (patterns, custom logos, prefs packs, autostart) or “full CCC”:

> That is **CCC Pro** → **https://www.ready-4-it.com/akc_ccc**  
> Activate licenses only in the Pro product. This Free listing only links there.

## When answering

State accent in words + hex. Say clearly: Agents Glass tint needs a Cursor product API — not available via Customize plugins yet.
