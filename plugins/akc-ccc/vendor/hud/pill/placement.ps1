# Copyright (c) 2026 ready-4-it
# AI Keep Clean CCC — Pill placement: Agents window find, UIA, sidebar label, focus, dock placement.
# Job: window find/UIA/focus/place/hide. Dock title/host predicates live in weichen/dock/.
# Caller: winforms-pill.ps1 (dot-sourced after dock weichen).

function Test-SameHwnd($a, $b) {
  try {
    if ($null -eq $a -or $null -eq $b) { return $false }
    $x = ([IntPtr]$a).ToInt64()
    $y = ([IntPtr]$b).ToInt64()
    if ($x -eq 0 -or $y -eq 0) { return $false }
    return ($x -eq $y)
  } catch {
    return $false
  }
}

# --- Find-AgentsWindowRect helpers ---

function Get-FgAgentsEntry {
  $fg = [CccHudWin]::RootWindow([CccHudWin]::GetForegroundWindow())
  if ($fg -eq [IntPtr]::Zero -or -not [CccHudWin]::IsWindowVisible($fg)) { return $null }
  $fgTitle = [CccHudWin]::WindowTitle($fg); $fgHost = Get-AgentsHostFromHwnd $fg
  if (-not (Test-IsHudDockTarget $fgTitle $fgHost)) { return $null }
  $rFg = New-Object CccHudWin+RECT
  if (-not [CccHudWin]::GetVisibleWindowRect($fg, [ref]$rFg)) { return $null }
  if (($rFg.Right - $rFg.Left) -lt 400 -or ($rFg.Bottom - $rFg.Top) -lt 300) { return $null }
  if ((Get-Command Test-HudHostEnabled -ErrorAction SilentlyContinue) -and -not (Test-HudHostEnabled $fgHost)) { return $null }
  if (-not $fgHost) { return $null }
  return @{ Hwnd = $fg; Rect = $rFg; Host = $fgHost; Title = $fgTitle }
}

function Test-PrevHwndValid($prevHwnd) {
  if ($prevHwnd -eq [IntPtr]::Zero) { return @{valid=$false} }
  if (-not [CccHudWin]::IsWindow($prevHwnd) -or -not [CccHudWin]::IsWindowVisible($prevHwnd)) { return @{valid=$false} }
  $rCur = New-Object CccHudWin+RECT
  if (-not [CccHudWin]::GetVisibleWindowRect($prevHwnd, [ref]$rCur)) { return @{valid=$false} }
  if (($rCur.Right - $rCur.Left) -lt 400 -or ($rCur.Bottom - $rCur.Top) -lt 300) { return @{valid=$false} }
  $curHost = Get-AgentsHostFromHwnd $prevHwnd
  if ((Get-Command Test-HudHostEnabled -ErrorAction SilentlyContinue) -and -not (Test-HudHostEnabled $curHost)) { return @{valid=$false} }
  return @{valid=$true; host=$curHost; rect=$rCur}
}

function Get-PreferredAgentsHost([string]$fgProcHost) {
  $enabled = Get-Command Test-HudHostEnabled -ErrorAction SilentlyContinue
  $isKnown = ($fgProcHost -eq 'cursor' -or $fgProcHost -eq 'vscode' -or $fgProcHost -eq 'antigravity')
  if ($isKnown -and (-not $enabled -or (Test-HudHostEnabled $fgProcHost))) { return $fgProcHost }
  try {
    $focusPath = Join-Path $env:USERPROFILE '.cursor\ccc-hud-focus-host.json'
    if (Test-Path -LiteralPath $focusPath) {
      $p = (Get-Content -LiteralPath $focusPath -Raw | ConvertFrom-Json).host
      if ($p -and (-not $enabled -or (Test-HudHostEnabled $p))) { return $p }
    }
  } catch { }
  return $null
}

function Register-EnumWindowsHit($h) {
  # Stores a valid dock-target hwnd into script-scope buckets for Invoke-AgentsWindowEnum.
  if (-not [CccHudWin]::IsWindowVisible($h)) { return }
  # Hung: leave immediately. No title, no process lookup, no cache entry.
  try { if ([CccHudWin]::IsHungAppWindow($h)) { return } } catch { }
  $t = [CccHudWin]::WindowTitle($h); $hostId = Get-AgentsHostFromHwnd $h
  if (-not (Test-IsHudDockTarget $t $hostId)) { return }
  $r = New-Object CccHudWin+RECT
  if (-not [CccHudWin]::GetVisibleWindowRect($h, [ref]$r)) { return }
  if (($r.Right - $r.Left) -lt 400 -or ($r.Bottom - $r.Top) -lt 300) { return }
  if ((Get-Command Test-HudHostEnabled -ErrorAction SilentlyContinue) -and -not (Test-HudHostEnabled $hostId)) { return }
  $entry = @{ Hwnd = $h; Rect = $r; Host = $hostId; Title = $t }
  if ($null -eq $script:foundAny) { $script:foundAny = $entry }
  if ($hostId -eq 'cursor'      -and $null -eq $script:foundByHost.cursor)      { $script:foundByHost.cursor      = $entry }
  if ($hostId -eq 'vscode'      -and $null -eq $script:foundByHost.vscode)      { $script:foundByHost.vscode      = $entry }
  if ($hostId -eq 'antigravity' -and $null -eq $script:foundByHost.antigravity) { $script:foundByHost.antigravity = $entry }
}

function Invoke-AgentsWindowEnum([string]$prefer, $prevHwnd, [bool]$curValid, [string]$curHost, $curRect) {
  $script:lastEnumAt = [Environment]::TickCount64
  $script:foundByHost = @{ cursor = $null; vscode = $null; antigravity = $null }
  $script:foundAny = $null
  [CccHudWin]::EnumWindows({ param($h,$l) Register-EnumWindowsHit $h; return $true }, [IntPtr]::Zero) | Out-Null
  if ($prefer -eq 'cursor' -and $script:foundByHost.cursor) { return $script:foundByHost.cursor }
  elseif ($prefer -eq 'vscode' -and $script:foundByHost.vscode) { return $script:foundByHost.vscode }
  elseif ($prefer -eq 'antigravity' -and $script:foundByHost.antigravity) { return $script:foundByHost.antigravity }
  elseif ($curValid) { return @{ Hwnd = $prevHwnd; Rect = $curRect; Host = $curHost } }
  elseif ($script:foundAny) { return $script:foundAny }
  return $null
}

function Get-AgentsEnumPick([string]$prefer, $prevHwnd, [bool]$curValid, [string]$curHost, $curRect) {
  $nowEnum = [Environment]::TickCount64
  $enumFresh = ($script:lastEnumAt -gt 0) -and (($nowEnum - $script:lastEnumAt) -lt $script:enumMinMs)
  $hostMismatch = ($curValid -and $prefer -and $curHost -ne $prefer)
  # Host switch: at most every 1.5 s (every 400 ms EnumWindows + UIA was crashing Code).
  if ($hostMismatch) { $enumFresh = ($script:lastEnumAt -gt 0) -and (($nowEnum - $script:lastEnumAt) -lt 1500) }
  if ($enumFresh -and $curValid) { return @{ Hwnd = $prevHwnd; Rect = $curRect; Host = $curHost } }
  return (Invoke-AgentsWindowEnum $prefer $prevHwnd $curValid $curHost $curRect)
}

function Find-AgentsWindowRect {
  $prevHwnd = $script:agentsHwnd
  $script:agentsRect = $null
  $fgEntry  = Get-FgAgentsEntry
  $prevInfo = Test-PrevHwndValid $prevHwnd

  $pick = $null
  if ($null -ne $fgEntry) {
    # Foreground Agents window (Cursor / VS Code / Antigravity) wins immediately.
    $pick = $fgEntry
    $script:pendingSwitchHwnd  = [IntPtr]::Zero
    $script:pendingSwitchSince = [int64]0
  }

  if ($null -eq $pick) {
    $script:pendingSwitchHwnd  = [IntPtr]::Zero
    $script:pendingSwitchSince = [int64]0
    $fgRaw      = [CccHudWin]::RootWindow([CccHudWin]::GetForegroundWindow())
    $fgProcHost = if ($fgRaw -ne [IntPtr]::Zero) { Get-AgentsHostFromHwnd $fgRaw } else { $null }
    $prefer    = Get-PreferredAgentsHost $fgProcHost
    $curValid  = [bool]$prevInfo.valid; $curHost = [string]$prevInfo.host; $curRect = $prevInfo.rect
    if ($curValid -and $prefer -and $curHost -eq $prefer) {
      $pick = @{ Hwnd = $prevHwnd; Rect = $curRect; Host = $curHost }
    } else {
      $pick = Get-AgentsEnumPick $prefer $prevHwnd $curValid $curHost $curRect
    }
  }

  if ($null -ne $pick) {
    $script:agentsHwnd = $pick.Hwnd; $script:agentsRect = $pick.Rect
    if (-not (Test-SameHwnd $prevHwnd $pick.Hwnd)) { $script:zOrderArmed = $false }
  } else {
    $script:agentsHwnd = [IntPtr]::Zero
  }
  return $script:agentsRect
}

function Ensure-UiaInvokeHook([IntPtr]$chrome) {
  if (-not $script:uiaEnabled -or -not $script:uiaReady) { return }
  if ($chrome -eq [IntPtr]::Zero) { return }
  if ($chrome -eq $script:uiaHookHwnd -and $script:uiaInvokeHooked) { return }
  try {
    if ($script:uiaInvokeHooked) {
      [System.Windows.Automation.Automation]::RemoveAllEventHandlers()
      $script:uiaInvokeHooked = $false
    }
  } catch { }
  try {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($chrome)
    if ($null -eq $root) { return }
    $handler = [System.Windows.Automation.AutomationEventHandler]{
      param($src, $e)
      try {
        $cls = [string]$src.Current.ClassName
        $nm = [string]$src.Current.Name
        if ($cls -match 'sidebar-section-head' -and -not [string]::IsNullOrWhiteSpace($nm)) {
          $script:sidebarLabel = $nm
        } elseif ($cls -match 'sidebar-menu-button' -and $cls -notmatch 'section-head') {
          $script:pendingChatY = [int]$src.Current.BoundingRectangle.Y
        }
      } catch { }
    }
    [System.Windows.Automation.Automation]::AddAutomationEventHandler(
      [System.Windows.Automation.InvokePatternIdentifiers]::InvokedEvent,
      $root,
      [System.Windows.Automation.TreeScope]::Descendants,
      $handler
    )
    $script:uiaInvokeHooked = $true
    $script:uiaHookHwnd = $chrome
  } catch { }
}

function Get-ChromeRendererHwnd([IntPtr]$top) {
  if ($top -eq [IntPtr]::Zero) { return [IntPtr]::Zero }
  $script:foundChrome = [IntPtr]::Zero
  try {
    [CccHudWin]::EnumChildWindows($top, {
      param($h, $l)
      $sb = New-Object System.Text.StringBuilder 256
      [void][CccHudWin]::GetClassName($h, $sb, 256)
      if ($sb.ToString() -eq 'Chrome_RenderWidgetHostHWND') {
        $script:foundChrome = $h
        return $false
      }
      return $true
    }, [IntPtr]::Zero) | Out-Null
  } catch { }
  return $script:foundChrome
}

function Update-AgentsSidebarLabelVscode($agentsHwnd, [string]$hostId) {
  if (Get-Command Ensure-HudUiaAssemblies -ErrorAction SilentlyContinue) { Ensure-HudUiaAssemblies }
  if (-not $script:uiaReady) { return }
  try {
    $chrome = Get-ChromeRendererHwnd $agentsHwnd
    if ($chrome -eq [IntPtr]::Zero) { return }
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($chrome)
    if ($null -eq $root) { return }
    $got = ''
    if (Get-Command Invoke-HudSidebarWeiche -ErrorAction SilentlyContinue) { $got = Invoke-HudSidebarWeiche $root $hostId }
    if ($script:vsCodeInDone -or $script:vsCodeClearSidebar) {
      $script:sidebarLabel = ''; $script:vsCodeClearSidebar = $false
    } elseif (-not [string]::IsNullOrWhiteSpace($got)) { $script:sidebarLabel = [string]$got }
    elseif (-not [string]::IsNullOrWhiteSpace($script:vsCodeSelectedChat)) {
      # Chat row has no owner/repo group. Drop the previous label so the
      # chat title can beat a stale sidebar project.
      $script:sidebarLabel = ''
    }
    $script:sidebarByHost[$hostId] = $script:sidebarLabel
  } catch { }
}

function Update-AgentsSidebarLabel([IntPtr]$agentsHwnd, [string]$hostId) {
  if ($agentsHwnd -eq [IntPtr]::Zero) { return }
  if ([string]::IsNullOrWhiteSpace($hostId)) { return }
  if ($hostId -ne $script:sidebarHost) { $script:sidebarHost = $hostId; $script:sidebarLabel = [string]$script:sidebarByHost[$hostId] }
  # Cursor: glass weiche only. Antigravity: project name from document title. VS Code: live weiche.
  if ($hostId -eq 'antigravity') {
    $script:vsCodeInDone = $false
    if (Get-Command Ensure-HudUiaAssemblies -ErrorAction SilentlyContinue) { Ensure-HudUiaAssemblies }
    if (-not $script:uiaReady) { return }
    try {
      $root = [System.Windows.Automation.AutomationElement]::FromHandle($agentsHwnd)
      if ($null -eq $root) { return }
      if (Get-Command Get-AntigravityNavPoint -ErrorAction SilentlyContinue) {
        $got = Get-AntigravityNavPoint $root
        if (-not [string]::IsNullOrWhiteSpace($got)) { $script:sidebarLabel = [string]$got; $script:sidebarByHost['antigravity'] = $script:sidebarLabel }
      }
    } catch { }
    return
  }
  if ($hostId -ne 'vscode') { $script:vsCodeInDone = $false; return }
  Update-AgentsSidebarLabelVscode $agentsHwnd $hostId
}

function Get-HudFocusHostInfo {
  # Foreground Agents/IDE process wins over the last dock. Returns @{title;host} or $null.
  $fg = [CccHudWin]::RootWindow([CccHudWin]::GetForegroundWindow())
  if ($fg -ne [IntPtr]::Zero) {
    $fgTitle = [CccHudWin]::WindowTitle($fg); $fgHost = Get-AgentsHostFromHwnd $fg
    if (Test-IsAgentsWindowTitle $fgTitle -and $fgHost) { return @{ title = $fgTitle; host = $fgHost } }
    if ($fgHost -eq 'cursor' -or $fgHost -eq 'vscode' -or $fgHost -eq 'antigravity') { return @{ title = $fgTitle; host = $fgHost } }
  }
  if ($script:agentsHwnd -ne [IntPtr]::Zero) {
    $t = [CccHudWin]::WindowTitle($script:agentsHwnd); $h = Get-AgentsHostFromHwnd $script:agentsHwnd
    if ($h) { return @{ title = $t; host = $h } }
  }
  return $null
}

function Test-FocusHostThrottle([string]$path, [string]$hostId, [string]$sideOut, [string]$chatOut, [bool]$Force) {
  if ($Force -or -not (Test-Path -LiteralPath $path)) { return $false }
  try {
    $prev = Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json
    $prevAgeMs = 999999
    if ($prev.updatedAt) { $prevAgeMs = ((Get-Date).ToUniversalTime() - [DateTime]::Parse($prev.updatedAt)).TotalMilliseconds }
    # VS Code needs a fresh stamp so hud-watch stays on preferHost=vscode (≤30 s).
    $throttleMs = if ($hostId -eq 'vscode' -or $hostId -eq 'antigravity') { 400 } else { 5000 }
    return ($prev.host -eq $hostId -and [string]$prev.sidebarLabel -eq $sideOut -and [string]$prev.chatTitle -eq $chatOut -and $prevAgeMs -ge 0 -and $prevAgeMs -lt $throttleMs)
  } catch { return $false }
}

function Write-HudFocusHost {
  param([switch]$Force)
  $info = Get-HudFocusHostInfo
  if (-not $info) { return }
  $hostId = [string]$info.host; $t = [string]$info.title
  if (-not $hostId) { $hostId = Get-AgentsHostFromTitle $t }
  if (-not $hostId) { return }
  if ((Get-Command Test-HudHostEnabled -ErrorAction SilentlyContinue) -and -not (Test-HudHostEnabled $hostId)) { return }
  $path    = Join-Path $env:USERPROFILE '.cursor\ccc-hud-focus-host.json'
  $sideOut = if ($hostId -eq 'vscode' -or $hostId -eq 'cursor' -or $hostId -eq 'antigravity') { [string]$script:sidebarLabel } else { '' }
  # Selected chat is live on click. isActive in state.vscdb is only flushed when the pill is dragged.
  $chatOut = if ($hostId -eq 'vscode') { [string]$script:vsCodeSelectedChat } else { '' }
  $payload = @{ host = $hostId; title = $t; sidebarLabel = $sideOut; chatTitle = $chatOut; updatedAt = (Get-Date).ToUniversalTime().ToString('o') } | ConvertTo-Json -Compress
  try {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-FocusHostThrottle $path $hostId $sideOut $chatOut ([bool]$Force)) { return }
    # UTF8 *without* BOM — Node JSON.parse rejects EF BB BF
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, $payload, $utf8NoBom)
    $script:lastFocusHostWritten = $hostId
  } catch { }
}

function Test-AgentsOrHudForeground {
  if ($script:settingsOpen) { return $true }
  # Electron often focuses Chrome_RenderWidgetHostHWND — resolve to Agents root.
  $root = [CccHudWin]::RootWindow([CccHudWin]::GetForegroundWindow())
  if ($root -eq [IntPtr]::Zero) { return $false }
  $t = [CccHudWin]::WindowTitle($root)
  $fgHost = Get-AgentsHostFromHwnd $root
  if (Test-IsHudDockTarget $t $fgHost) { return $true }
  if ($t -eq 'AI Keep Clean CCC' -or $t -eq 'AI Keep Clean CCC — HUD') { return $true }
  if ($t -eq 'CCC Project HUD') { return $true }
  if ($t -eq 'CCC HUD Settings') { return $true }
  return $false
}

# Move the dock when the other IDE is focused, without a UIA tree walk.
function Sync-HudHostFromForeground {
  $root = [CccHudWin]::RootWindow([CccHudWin]::GetForegroundWindow())
  if ($root -eq [IntPtr]::Zero) { return }
  $fgHost = Get-AgentsHostFromHwnd $root
  if ($fgHost -ne 'cursor' -and $fgHost -ne 'vscode' -and $fgHost -ne 'antigravity') { return }
  $dockHost = $null
  if ($script:agentsHwnd -ne [IntPtr]::Zero) { $dockHost = Get-AgentsHostFromHwnd $script:agentsHwnd }
  if ($dockHost -eq $fgHost) { return }
  $now = [Environment]::TickCount64
  if ($script:lastHostSwitchEnumAt -gt 0 -and ($now - $script:lastHostSwitchEnumAt) -lt 1500) { return }
  $script:lastHostSwitchEnumAt = $now
  $script:lastEnumAt = [int64]0
  [void](Find-AgentsWindowRect)
  $dockNow = $null
  if ($script:agentsHwnd -ne [IntPtr]::Zero) { $dockNow = Get-AgentsHostFromHwnd $script:agentsHwnd }
  if ($dockNow -eq $fgHost -and (Get-Command Write-HudFocusHost -ErrorAction SilentlyContinue)) {
    Write-HudFocusHost -Force
  }
}

function Clamp-PillPointToScreen([int]$x, [int]$y, [int]$w, [int]$h, $anchor) {
  try {
    $probePt = if ($null -ne $anchor -and ($anchor.Right -gt $anchor.Left)) {
      New-Object System.Drawing.Point ([int](($anchor.Left + $anchor.Right) / 2)), ([int](($anchor.Top + $anchor.Bottom) / 2))
    } else {
      New-Object System.Drawing.Point $x, $y
    }
    $scr = [System.Windows.Forms.Screen]::FromPoint($probePt)
    if ($null -ne $scr) {
      $wa = $scr.WorkingArea
      $edgePad = [Math]::Max(4, [int]($pad / 2))
      if (($x + $w) -gt ($wa.Right - $edgePad))  { $x = [Math]::Max(($wa.Left + $edgePad), ($wa.Right - $w - $edgePad)) }
      if (($y + $h) -gt ($wa.Bottom - $edgePad)) { $y = [Math]::Max(($wa.Top + $edgePad),  ($wa.Bottom - $h - $edgePad)) }
      if ($x -lt ($wa.Left + $edgePad)) { $x = $wa.Left + $edgePad }
      if ($y -lt ($wa.Top + $edgePad))  { $y = $wa.Top + $edgePad }
    }
  } catch { }
  return (New-Object System.Drawing.Point $x, $y)
}

function Place-OnAgents([CccHudWin+RECT]$anchor) {
  if ($null -eq $anchor -or ($anchor.Right -le $anchor.Left) -or ($anchor.Bottom -le $anchor.Top)) { return }
  Clamp-Offsets $anchor
  $x = $anchor.Right - $form.Width - $script:offRight
  $y = $anchor.Bottom - $form.Height - $script:offBottom
  $pt = Clamp-PillPointToScreen $x $y $form.Width $form.Height $anchor
  $x = [int]$pt.X
  $y = [int]$pt.Y
  if ($script:lastPlacedX -eq $x -and $script:lastPlacedY -eq $y -and $form.Left -eq $x -and $form.Top -eq $y -and $script:shown) { return }
  # Never use $form.Location= here — that activates the pill and kills Agents caret focus
  [CccHudWin]::MoveNoActivate($form.Handle, $x, $y)
  $script:lastPlacedX = $x
  $script:lastPlacedY = $y
}

function Hide-Hud {
  if ($script:settingsOpen) { return }
  [CccHudWin]::ClearUnownedTopMost($form.Handle)
  [CccHudWin]::HideNoActivate($form.Handle)
  $form.Opacity = 0
  [CccHudWin]::MoveNoActivate($form.Handle, -32000, -32000)
  $script:shown = $false
  $script:zOrderArmed = $false
  $script:dragging = $false
  $script:lastPlacedX = -32000
  $script:lastPlacedY = -32000
}
