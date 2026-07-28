---
name: apply-ide-border-cue
description: Apply CCC accent as IDE border colors for a workspace via the Agent plugin (sideBar.border etc.)
---

# Apply IDE border cue

1. Determine workspace path (from Agent folder or `.ccc/workspaces.json`).
2. Call MCP tool **`ccc_apply_ide_border_cue`** with `workspacePath` and `label`.
3. Show the returned identity card.
4. Instruct: open/focus that workspace in the **IDE** window (or Reload Window there) to see the colored border. Agents UI will not change color.
