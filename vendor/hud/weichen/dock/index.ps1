# Copyright (c) 2026 ready-4-it
# Dock weichen dispatcher + shared clamp. Sources one file per derivative, then
# provides Test-IsHudDockTarget, Get-AgentsHost*, and Clamp-Offsets for the pill.
# Pill calls these; it does not grow inlined host branches.

. (Join-Path $PSScriptRoot 'cursor.ps1')
. (Join-Path $PSScriptRoot 'vscode.ps1')
. (Join-Path $PSScriptRoot 'antigravity.ps1')

function Test-IsAgentsWindowTitle([string]$t) {
  if ([string]::IsNullOrWhiteSpace($t)) { return $false }
  $trim = $t.Trim()
  # Exact multi-host Agents titles that are unambiguous:
  if ($trim -eq 'Agents') { return $true }
  if ($trim -match '^Agents(\s*[—\-:].*)?$') { return $true }
  # Per-derivative dispatch:
  if (Test-IsCursorAgentsTitle $trim) { return $true }
  if (Test-IsVsCodeAgentsTitle $trim) { return $true }
  if (Test-IsAntigravityAgentsTitle $trim) { return $true }
  return $false
}

# One dock predicate for every accept site: Agents titles, or an Antigravity
# window that is not the main IDE. Cursor, VS Code, and Antigravity IDE stay out.
function Test-IsHudDockTarget([string]$title, [string]$hostId) {
  if (Test-IsAgentsWindowTitle $title) { return $true }
  if (Test-IsAntigravityAgentWindow $title $hostId) { return $true }
  return $false
}

function Get-AgentsHostFromProcessName([string]$name) {
  if ([string]::IsNullOrWhiteSpace($name)) { return $null }
  $n = $name.Trim()
  if ($n -like '*.exe') { $n = $n.Substring(0, $n.Length - 4) }
  $h = Get-CursorHostFromProcess $n
  if ($h) { return $h }
  $h = Get-VsCodeHostFromProcess $n
  if ($h) { return $h }
  $h = Get-AntigravityHostFromProcess $n
  if ($h) { return $h }
  return $null
}

function Get-AgentsHostFromTitle([string]$t) {
  if ([string]::IsNullOrWhiteSpace($t)) { return $null }
  $h = Get-CursorHostFromTitle $t
  if ($h) { return $h }
  $h = Get-VsCodeHostFromTitle $t
  if ($h) { return $h }
  $h = Get-AntigravityHostFromTitle $t
  if ($h) { return $h }
  # Bare "Agents" is used by hosts — caller should use process name
  return $null
}

function Get-AgentsHostFromHwnd([IntPtr]$h) {
  if ($h -eq [IntPtr]::Zero) { return $null }
  $procHost = $null
  try {
    # Do not use $pid — it aliases PowerShell's read-only $PID.
    $wndPid = 0
    [void][CccHudWin]::GetWindowThreadProcessId($h, [ref]$wndPid)
    if ($wndPid -gt 0) {
      $now = [Environment]::TickCount64
      $hit = $script:hostByPid[$wndPid]
      if ($null -ne $hit -and ($now - [int64]$hit.at) -ge 0 -and ($now - [int64]$hit.at) -lt $script:hostByPidTtlMs) {
        return [string]$hit.host
      }
      $proc = [System.Diagnostics.Process]::GetProcessById([int]$wndPid)
      $procHost = Get-AgentsHostFromProcessName $proc.ProcessName
      if ($procHost) {
        if ($script:hostByPid.Count -ge 32) {
          foreach ($k in @($script:hostByPid.Keys)) {
            $age = $now - [int64]$script:hostByPid[$k].at
            if ($age -ge $script:hostByPidTtlMs -or $age -lt 0) { [void]$script:hostByPid.Remove($k) }
          }
          if ($script:hostByPid.Count -ge 32) { $script:hostByPid.Clear() }
        }
        $script:hostByPid[$wndPid] = @{ host = $procHost; at = $now }
        return $procHost
      }
    }
  } catch { }
  if ($procHost) { return $procHost }
  $title = [CccHudWin]::WindowTitle($h)
  $fromTitle = Get-AgentsHostFromTitle $title
  if ($fromTitle) { return $fromTitle }
  # Last resort: documented VS Code title "Agents"
  if (Test-IsAgentsWindowTitle $title) { return 'vscode' }
  return $null
}

# Shared clamp — used by all three dock derivatives; host differences must not go here.
function Clamp-Offsets([CccHudWin+RECT]$anchor) {
  # Live Agents frame. Every edge uses the same pad, so the pill can sit on the
  # window border. No composer band and no fixed 500px or 8000px cap.
  $aw = [int]($anchor.Right - $anchor.Left)
  $ah = [int]($anchor.Bottom - $anchor.Top)
  $minO = [int]$pad
  $maxR = [Math]::Max($minO, $aw - $form.Width - $minO)
  $maxB = [Math]::Max($minO, $ah - $form.Height - $minO)
  if ($script:offRight -lt $minO) { $script:offRight = $minO }
  elseif ($script:offRight -gt $maxR) { $script:offRight = $maxR }
  if ($script:offBottom -lt $minO) { $script:offBottom = $minO }
  elseif ($script:offBottom -gt $maxB) { $script:offBottom = $maxB }
}
