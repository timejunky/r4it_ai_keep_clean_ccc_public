# Copyright (c) 2026 ready-4-it
# AI Keep Clean CCC — Pill drag handlers: Begin-Drag, Move-Drag, End-Drag.
# Job: own all mouse-drag state and double-click guard for the HUD pill.
# Caller: winforms-pill.ps1 (dot-sourced after form controls and  are declared).
function Begin-Drag($sender, $e) {
  if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
  try { $sender.Capture = $true } catch { }
  $now = [Environment]::TickCount64
  $dblMs = Get-HudDoubleClickMs
  $screenPt = $sender.PointToScreen($e.Location)
  $dblSize = [System.Windows.Forms.SystemInformation]::DoubleClickSize
  $slop = [Math]::Max(32, [Math]::Max($dblSize.Width, $dblSize.Height) * 4)
  $nearPrev = (
    [Math]::Abs($screenPt.X - $script:lastClickScreen.X) -le $slop -and
    [Math]::Abs($screenPt.Y - $script:lastClickScreen.Y) -le $slop
  )
  if (($now - $script:lastClickTick) -lt $dblMs -and $nearPrev) {
    $script:clickCount++
  } else {
    $script:clickCount = 1
  }
  $script:lastClickTick = $now
  $script:lastClickScreen = $screenPt
  $script:dragMoved = $false
  $script:pendingSettings = ($script:clickCount -ge 2)
  $script:clickOnMarker = [object]::ReferenceEquals($sender, $markerBox)
  if (-not $script:clickOnMarker -and $lookFxCanvas -and [object]::ReferenceEquals($sender, $lookFxCanvas)) {
    $script:clickOnMarker = ($e.X -le [int]$script:lookFxMarkerRight)
  }
  $script:dragging = $true
  $script:dragOffset = $e.Location
  if ($sender -ne $form) {
    $pt = $form.PointToClient($screenPt)
    $script:dragOffset = $pt
  }
  # Click / DND on the pill: scrape while Chromium is not focused (UIA tree is readable).
  $rect = Find-AgentsWindowRect
  if ($null -ne $rect -and $script:agentsHwnd -ne [IntPtr]::Zero) {
    $hostNow = Get-AgentsHostFromHwnd $script:agentsHwnd
    if (-not $hostNow) { $hostNow = $script:scopeHost }
    Update-AgentsSidebarLabel $script:agentsHwnd $hostNow
  }
  if ($null -ne $rect) { Write-HudFocusHost -Force }
  Apply-StateFile
  if ($script:clickCount -ge 2) {
    Request-OpenSettings
  }
}

function Move-Drag($sender, $e) {
  if (-not $script:dragging) { return }
  if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
  if ($script:clickCount -ge 2 -or $script:pendingSettings) { return }
  $screen = $sender.PointToScreen($e.Location)
  $nx = $screen.X - $script:dragOffset.X
  $ny = $screen.Y - $script:dragOffset.Y
  $cur = $form.Location
  $dragSz = [System.Windows.Forms.SystemInformation]::DragSize
  # Jitter under this slop is not a drag (keeps double-click). Real DND starts immediately past it.
  $slopX = [Math]::Max(8, $dragSz.Width)
  $slopY = [Math]::Max(8, $dragSz.Height)
  if ([Math]::Abs($nx - $cur.X) -le $slopX -and [Math]::Abs($ny - $cur.Y) -le $slopY) {
    return
  }
  $script:dragMoved = $true
  $script:pendingSettings = $false
  $script:clickCount = 0
  Cancel-PendingOpenUrl
  $rect = Find-AgentsWindowRect
  if ($null -eq $rect) { return }
  $minX = $rect.Left + $pad
  $minY = $rect.Top + $pad
  $maxX = $rect.Right - $form.Width - $pad
  $maxY = $rect.Bottom - $form.Height - $pad
  # Narrow Agents strip: keep horizontal free range even if pill is wider than ideal.
  if ($maxX -lt $minX) { $maxX = $minX }
  if ($maxY -lt $minY) { $maxY = $minY }
  if ($nx -lt $minX) { $nx = $minX }
  if ($ny -lt $minY) { $ny = $minY }
  if ($nx -gt $maxX) { $nx = $maxX }
  if ($ny -gt $maxY) { $ny = $maxY }
  [CccHudWin]::MoveNoActivate($form.Handle, $nx, $ny)
  $script:offRight = $rect.Right - $form.Width - $nx
  $script:offBottom = $rect.Bottom - $form.Height - $ny
}

function End-Drag {
  if (-not $script:dragging) { return }
  $script:dragging = $false
  try { $form.Capture = $false } catch { }
  if ($script:pendingSettings) {
    Request-OpenSettings
    return
  }
  if ($script:dragMoved) {
    $script:clickCount = 0
    Save-Pos
    return
  }
  if ($script:clickOnMarker -and ([string]$script:prefs.markerMode -eq 'image') -and $markerBox.Visible) {
    Schedule-OpenWorkspaceUrl
  } else {
    Save-Pos
  }
}