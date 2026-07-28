---
name: show-workspace-visual-context
description: Resolve and speak CCC visual identity (accent name + hex + IDE border cue) for the current or named workspace
---

# Show workspace visual context

1. Resolve workspace path (current Agent folder, or Unframed / HoReCanish / … from `.ccc/workspaces.json`).
2. Run:

```bash
Prefer MCP tool ccc_resolve_visual_context with the workspace path.
```

3. Paste the identity card at the top of your reply (accent **name** + hex). Example:

```text
Workspace identity: HoReCanish
Accent: Cyan (#3db8c5) · source: manual-override
IDE border cue: #3db8c5 (suggested for AKC IDE)
```

4. Remind: Agents chrome cannot tint yet; IDE borders/title are AKC-owned.
