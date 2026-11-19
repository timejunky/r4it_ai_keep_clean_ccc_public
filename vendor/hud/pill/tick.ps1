# Copyright (c) 2026 ready-4-it
# AI Keep Clean CCC — Heartbeat, watch-revive, and tick dispatcher.
# Job: own Write-HudPillHeartbeat, Test-HudWatch*, Start-HudWatchIfDead, Tick-Hud, Set-HudTickInterval.
# Caller: winforms-pill.ps1 (dot-sourced before $script:hudTimer is created).

function Write-HudPillHeartbeat {
  try {
    $hbPath = Join-Path $cursorDir 'ccc-hud-pill-heartbeat.json'
    $hb = '{"updatedAt":"' + ((Get-Date).ToUniversalTime().ToString('o')) + '","pid":' + $PID + '}'
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($hbPath, $hb, $utf8NoBom)
  } catch { }
}

function Test-HudWatchWanted {
  if ($env:CCC_HUD_NO_WATCH -eq '1') { return $false }
  $watchEnv = [string]$env:CCC_HUD_WATCH
  if ($watchEnv -eq '0' -or $watchEnv -eq 'false') { return $false }
  if ((Get-Command Test-HudHostEnabled -ErrorAction SilentlyContinue) -and -not (Test-HudHostEnabled '')) {
    return $false
  }
  $expPath = Join-Path $env:USERPROFILE '.cursor\ccc-hud-experiments.json'
  if (-not (Test-Path -LiteralPath $expPath)) { return $true }
  try {
    $exp = Get-Content -LiteralPath $expPath -Raw -ErrorAction Stop | ConvertFrom-Json
    if ($exp.enabled -and -not $exp.hudWatch) { return $false }
  } catch { }
  return $true
}

function Test-HudWatchAlive {
  $pidPath = Join-Path $env:USERPROFILE '.cursor\ccc-hud-watch.pid'
  if (-not (Test-Path -LiteralPath $pidPath)) { return $false }
  try {
    $wp = 0
    [void][int]::TryParse((Get-Content -LiteralPath $pidPath -Raw).Trim(), [ref]$wp)
    if ($wp -le 0) { return $false }
    return ($null -ne (Get-Process -Id $wp -ErrorAction SilentlyContinue))
  } catch {
    return $false
  }
}

# Watch updates ccc-hud-state.json for Cursor, VS Code, and Antigravity.
# A dead watch leaves the pill on the last repo on every host.
function Start-HudWatchIfDead {
  if (-not (Test-HudWatchWanted)) { return }
  $now = [Environment]::TickCount64
  if ($null -ne $script:lastWatchReviveAt -and ($now - $script:lastWatchReviveAt) -lt 20000) { return }
  if (Test-HudWatchAlive) { return }
  $script:lastWatchReviveAt = $now
  $candidates = @(
    (Join-Path $script:HudScriptRoot 'hud-watch.mjs'),
    (Join-Path (Split-Path $script:HudScriptRoot) 'hud-watch.mjs')
  )
  $watchScript = $null
  foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { $watchScript = $c; break }
  }
  if (-not $watchScript) {
    Write-HudBoot 'watch revive skipped: hud-watch.mjs missing'
    return
  }
  $node = $null
  $cmd = Get-Command node -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { $node = [string]$cmd.Source }
  if (-not $node) {
    $guess = Join-Path $env:ProgramFiles 'nodejs\node.exe'
    if (Test-Path -LiteralPath $guess) { $node = $guess }
  }
  if (-not $node) {
    Write-HudBoot 'watch revive skipped: node missing'
    return
  }
  try {
    Start-Process -FilePath $node -ArgumentList @($watchScript) -WindowStyle Hidden -WorkingDirectory (Split-Path -Parent $watchScript) | Out-Null
    Write-HudBoot ("watch revive " + $watchScript)
  } catch {
    Write-HudBoot ("watch revive FAIL: " + $_.Exception.Message)
  }
}

function Tick-Hud {
  try {
    Start-HudWatchIfDead
    Tick-HudCore
  } catch {
    try {
      $errPath = Join-Path $cursorDir 'ccc-hud-pill.err.log'
      $line = ((Get-Date).ToUniversalTime().ToString('o')) + ' ' + $_.Exception.Message
      Add-Content -LiteralPath $errPath -Value $line -Encoding utf8
    } catch { }
  }
}

function Set-HudTickInterval([int]$wantMs) {
  if ($null -eq $script:hudTimer) { return }
  if ($wantMs -lt 400) { $wantMs = 400 }
  if ($script:hudTimer.Interval -ne $wantMs) { $script:hudTimer.Interval = $wantMs }
}


function Restore-AgentsCaretIfPillTookIt {
  if ($script:dragging -or $script:settingsOpen) { return }
  if ($script:agentsHwnd -eq [IntPtr]::Zero) { return }
  if (-not [CccHudWin]::IsWindow($script:agentsHwnd)) { return }
  $fg = [CccHudWin]::GetForegroundWindow()
  if ($fg -eq [IntPtr]::Zero) { return }
  $root = [CccHudWin]::RootWindow($fg)
  $pill = $form.Handle
  $isPill = ($fg -eq $pill -or $root -eq $pill)
  if (-not $isPill) {
    $t = [CccHudWin]::WindowTitle($root)
    if ($t -ne 'AI Keep Clean CCC' -and $t -ne 'AI Keep Clean CCC — HUD' -and $t -ne 'CCC Project HUD') { return }
  }
  [void][CccHudWin]::SetForegroundWindow($script:agentsHwnd)
}

function Invoke-TickWakePath {
  # Non-Agents foreground: hide, throttle heartbeat.
  if ($script:shown) { Hide-Hud }
  $script:notAgentsSince = [Environment]::TickCount64
  Set-HudTickInterval $script:tickWakeMs
  $nowHb = [Environment]::TickCount64
  if ($null -eq $script:lastWakeHeartbeatAt -or ($nowHb - $script:lastWakeHeartbeatAt) -ge 15000) {
    $script:lastWakeHeartbeatAt = $nowHb; Write-HudPillHeartbeat
  }
}

function Invoke-TickIdleHide {
  Hide-Hud; $script:notAgentsSince = $null
  Set-HudTickInterval $script:tickIdleMs; Write-HudPillHeartbeat
}

function Invoke-TickBindOwner {
  # Bind to focused Agents owner; clear armed flag on any ownership change.
  if ($script:agentsHwnd -eq [IntPtr]::Zero) { return }
  if (-not [CccHudWin]::IsWindow($script:agentsHwnd)) {
    [CccHudWin]::ClearOwner($form.Handle); $script:zOrderArmed = $false
  } else {
    $bound = [CccHudWin]::SetOwner($form.Handle, $script:agentsHwnd)
    if (-not $bound) { $script:zOrderArmed = $false }
  }
}

function Invoke-TickZOrder {
  # Do NOT toggle TopMost/NOTOPMOST every tick — SWP without SWP_NOACTIVATE steals caret.
  if ($script:zOrderArmed) { return }
  [CccHudWin]::ClearUnownedTopMost($form.Handle)
  [CccHudWin]::MakeNoActivateToolWindow($form.Handle)
  [CccHudWin]::RaiseAboveOwner($form.Handle)
  $script:zOrderArmed = $true
}

function Test-TickFormHwndAlive {
  if ($null -eq $form) { return $true }
  if (-not ($form.IsDisposed -or -not [CccHudWin]::IsWindow($form.Handle))) { return $true }
  try {
    Add-Content -LiteralPath (Join-Path $cursorDir 'ccc-hud-pill.err.log') -Value (((Get-Date).ToUniversalTime().ToString('o')) + ' form hwnd destroyed (owner teardown?) — exiting for watch revive') -Encoding utf8
  } catch { }
  [Environment]::Exit(1)
  return $false
}

function Invoke-TickDockedFrame($rect) {
  if ($null -ne $rect -and $script:agentsHwnd -ne [IntPtr]::Zero) {
    $hostNow = Get-AgentsHostFromHwnd $script:agentsHwnd
    Update-AgentsSidebarLabel $script:agentsHwnd $(if ($hostNow) { $hostNow } else { $script:scopeHost })
  }
  if ($null -ne $rect) { Write-HudFocusHost }
  Update-ScopeCaption
  if ($null -eq $rect) { Invoke-TickIdleHide; return $false }
  if ($script:vsCodeInDone) {
    if ($script:shown) { Hide-Hud }
    Set-HudTickInterval 400; Write-HudPillHeartbeat
    return $false
  }
  $script:notAgentsSince = $null
  Apply-StateFile
  if (-not $script:dragging) { Place-OnAgents $rect }
  $form.Opacity = 1.0
  if (-not $script:shown) { [CccHudWin]::ShowNoActivate($form.Handle); $script:shown = $true; $script:zOrderArmed = $false }
  Invoke-TickBindOwner
  Invoke-TickZOrder
  Restore-AgentsCaretIfPillTookIt
  Write-HudPillHeartbeat
  Set-HudTickInterval 400
  return $true
}

function Tick-HudCore {
  # Settings modal open — skip EnumWindows/UIA/dock work (freezes Agents + HUD UI thread).
  if ($script:settingsOpen) { Set-HudTickInterval $script:tickIdleMs; Write-HudPillHeartbeat; return }
  $fgRoot = [CccHudWin]::RootWindow([CccHudWin]::GetForegroundWindow())
  $fgHung = $false
  if ($fgRoot -ne [IntPtr]::Zero) {
    try { $fgHung = [CccHudWin]::IsHungAppWindow($fgRoot) } catch { $fgHung = $false }
  }
  if ($fgHung) {
    # Do not enum, read titles, or write focus/logs while the foreground app is Not Responding.
    Set-HudTickInterval $script:tickIdleMs
    $nowHb = [Environment]::TickCount64
    if ($null -eq $script:lastWakeHeartbeatAt -or ($nowHb - $script:lastWakeHeartbeatAt) -ge 15000) {
      $script:lastWakeHeartbeatAt = $nowHb; Write-HudPillHeartbeat
    }
    return
  }
  Write-HudDiag ("tick host=" + [string]$script:scopeHost + " offRight=" + $script:offRight + " offBottom=" + $script:offBottom)

  if ((Get-Command Test-HudHostEnabled -ErrorAction SilentlyContinue) -and -not (Test-HudHostEnabled '')) {
    Hide-Hud; Set-HudTickInterval $script:tickIdleMs; Write-HudPillHeartbeat; return
  }
  [void](Test-TickFormHwndAlive)
  if (-not (Test-AgentsOrHudForeground)) { Invoke-TickWakePath; return }
  try { Sync-HudHostFromForeground } catch { }
  [void](Invoke-TickDockedFrame (Find-AgentsWindowRect))
}