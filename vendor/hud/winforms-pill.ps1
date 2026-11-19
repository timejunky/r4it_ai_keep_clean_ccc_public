# Copyright (c) 2026 ready-4-it
# AI Keep Clean CCC — Project HUD (pill over Agents)
# Double-click (MouseUp, no drag) → settings · drag inside Agents · hide when IDE / other apps focused
# Z-order: owned by Agents (not global TopMost) so Chrome/image viewers are never covered

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class CccHudDpi {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int value);
  public static void Enable() {
    try { SetProcessDpiAwareness(2); }
    catch { try { SetProcessDPIAware(); } catch { } }
  }
}
"@
[void][CccHudDpi]::Enable()

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Native double-click (WM_LBUTTONDBLCLK) — WinForms DoubleClick is unreliable with WS_EX_NOACTIVATE.
try {
  [CccHudDblClickFilter] | Out-Null
} catch {
  Add-Type -ReferencedAssemblies @('System.Windows.Forms') -TypeDefinition @"
using System;
using System.Windows.Forms;
public sealed class CccHudDblClickFilter : IMessageFilter {
  public static Action Handler;
  public bool PreFilterMessage(ref Message m) {
    if (m.Msg == 0x0203 || m.Msg == 0x00A3) {
      Action h = Handler;
      if (h != null) h();
    }
    return false;
  }
}
"@
}

# Detach/hide the host console so "powershell bleibt offen" is not the product UX
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class CccHudConsole {
  [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("kernel32.dll")] public static extern bool FreeConsole();
  public static void Hide() {
    try {
      IntPtr hwnd = GetConsoleWindow();
      if (hwnd != IntPtr.Zero) { ShowWindow(hwnd, 0); }
      FreeConsole();
    } catch { }
  }
}
"@
[void][CccHudConsole]::Hide()

$script:HudScriptRoot = $PSScriptRoot
$cursorDir = Join-Path $env:USERPROFILE '.cursor'
$bootLog = Join-Path $cursorDir 'ccc-hud-pill-boot.log'
. (Join-Path $PSScriptRoot 'pill\diag.ps1')
Write-HudBoot "start pid=$PID"
$lookFxPath = Join-Path $PSScriptRoot 'winforms-lookfx.ps1'
if (Test-Path -LiteralPath $lookFxPath) { . $lookFxPath }

$ErrorActionPreference = 'Continue'
$statePath = Join-Path $cursorDir 'ccc-hud-state.json'
$posPath = Join-Path $cursorDir 'ccc-hud-pos.json'
$prefsPath = Join-Path $cursorDir 'ccc-hud-prefs.json'
$script:zebraNetworkConsentAt = $null
$script:zebraNetworkConsentVersion = $null
$licensePath = Join-Path $cursorDir 'ccc-hud-license.json'
$assetsDir = Join-Path $cursorDir 'ccc-hud-assets'
$pidPath = Join-Path $cursorDir 'ccc-hud.pid'
$mutexName = 'Global\CCC.ProjectHud.WinFormsPill'

if ($PSScriptRoot) {
  $i18nPath = Join-Path $PSScriptRoot 'i18n\winforms-i18n.ps1'
  if (Test-Path -LiteralPath $i18nPath) { . $i18nPath }
}

$createdNew = $false
$mutex = $null
try {
  $mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
} catch [System.Threading.AbandonedMutexException] {
  $createdNew = $true
}
if (-not $createdNew -and $null -ne $mutex) {
  try {
    if ($mutex.WaitOne(0, $false)) {
      $createdNew = $true
    }
  } catch [System.Threading.AbandonedMutexException] {
    $createdNew = $true
  } catch { }
}
if (-not $createdNew) {
  Write-HudBoot 'exit: mutex busy'
  exit 0
}
Write-HudBoot 'mutex ok'

# Clear-PidFile, Write-PidFile → pill\diag.ps1
# native-win.ps1 claims the pid before Add-Type CccHudWin (slow compile guard).
. (Join-Path $PSScriptRoot 'pill\native-win.ps1')

$ErrorActionPreference = 'Continue'
Write-PidFile
Write-HudBoot "pid claimed early pid=$PID"
# Heartbeat immediately so hud-watch does not treat a slow WinForms boot as a zombie and kill us.
try {
  $hbPath = Join-Path $cursorDir 'ccc-hud-pill-heartbeat.json'
  $hb = '{"updatedAt":"' + ((Get-Date).ToUniversalTime().ToString('o')) + '","pid":' + $PID + '}'
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($hbPath, $hb, $utf8NoBom)
} catch { }
trap {
  try {
    Write-HudBoot ("TRAP: " + $_.Exception.Message)
    Write-HudBoot ("TRAP at: " + $_.InvocationInfo.PositionMessage)
  } catch { }
  continue
}
$dpi = 96
try {
  $g = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
  $dpi = [int]$g.DpiX
  $g.Dispose()
} catch { }
$scale = [Math]::Max(1.0, $dpi / 96.0)
$basePillH = [int][Math]::Round(48 * $scale)
$script:currentPillH = $basePillH
$pad = [int][Math]::Round(16 * $scale)
$hideDebounceMs = 1200

. (Join-Path $PSScriptRoot 'pill\prefs.ps1')

. (Join-Path $PSScriptRoot 'hud-gate.ps1')
$weichenSidebar = Join-Path $PSScriptRoot 'weichen\sidebar\index.ps1'
if (Test-Path -LiteralPath $weichenSidebar) { . $weichenSidebar }
$weichenHostGate = Join-Path $PSScriptRoot 'weichen\host-gate\index.ps1'
if (Test-Path -LiteralPath $weichenHostGate) { . $weichenHostGate }
$weichenDock = Join-Path $PSScriptRoot 'weichen\dock\index.ps1'
if (Test-Path -LiteralPath $weichenDock) { . $weichenDock }
. (Join-Path $PSScriptRoot 'pill\license.ps1')
. (Join-Path $PSScriptRoot 'pill\logo-assets.ps1')
$markerBmpHelper = Join-Path $PSScriptRoot 'settings\preview\marker-bitmap.ps1'
if (Test-Path -LiteralPath $markerBmpHelper) { . $markerBmpHelper }
. (Join-Path $PSScriptRoot 'pill\marker-gfx.ps1')
$form = New-Object System.Windows.Forms.Form
$form.Text = 'AI Keep Clean CCC'
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.ShowInTaskbar = $false
$form.TopMost = $false
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$form.Location = New-Object System.Drawing.Point(-32000, -32000)
try {
  $prop = $form.GetType().GetProperty('ShowWithoutActivation', [System.Reflection.BindingFlags]'Instance, NonPublic')
  if ($null -ne $prop) { $prop.SetValue($form, $true, $null) }
} catch { }
$script:scopeBandH = [int][Math]::Max(12, [Math]::Round(14 * $scale))
# Free/Trial: pill + scope only. Pro chrome (+ version band) applied after tier assess.
$form.Size = New-Object System.Drawing.Size(([int][Math]::Round(220 * $scale)), ($basePillH + $script:scopeBandH))
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 36, 48)
$form.Opacity = 0.0
$form.Visible = $false
$form.Cursor = [System.Windows.Forms.Cursors]::SizeAll

$script:pillToolTip = New-Object System.Windows.Forms.ToolTip
$script:pillToolTip.AutoPopDelay = 12000
$script:pillToolTip.InitialDelay = 400
$script:pillToolTip.ReshowDelay = 200
$script:pillToolTip.ShowAlways = $true
$script:pillTipText = ''
$script:pillTipShown = $false
$script:homeTip = ''
. (Join-Path $PSScriptRoot 'pill\tips.ps1')


# Mini caption under the pill rectangle (host scope: Cursor ↔ VS Code)
$scopeLabel = New-Object System.Windows.Forms.Label
$scopeLabel.Dock = [System.Windows.Forms.DockStyle]::Bottom
$scopeLabel.Height = $script:scopeBandH
$scopeLabel.AutoSize = $false
$scopeLabel.AutoEllipsis = $true
$scopeLabel.UseMnemonic = $false
$scopeLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$script:scopeFooterLines = 1
$scopeLabel.ForeColor = [System.Drawing.Color]::FromArgb(170, 180, 195)
$scopeLabel.BackColor = [System.Drawing.Color]::FromArgb(30, 36, 48)
$scopeLabel.Font = New-Object System.Drawing.Font('Segoe UI', ([float][Math]::Max(6.5, 7.0 * $scale)), [System.Drawing.FontStyle]::Regular)
$scopeLabel.Text = 'Scope: —'
$scopeLabel.Cursor = [System.Windows.Forms.Cursors]::SizeAll
$form.Controls.Add($scopeLabel)

$tierLabel = New-Object System.Windows.Forms.Label
$tierLabel.Dock = [System.Windows.Forms.DockStyle]::Top
$tierLabel.Height = $script:scopeBandH
$tierLabel.AutoSize = $false
$tierLabel.AutoEllipsis = $true
$tierLabel.UseMnemonic = $false
$tierLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$tierLabel.ForeColor = [System.Drawing.Color]::FromArgb(170, 180, 195)
$tierLabel.BackColor = [System.Drawing.Color]::FromArgb(30, 36, 48)
$tierLabel.Font = New-Object System.Drawing.Font('Segoe UI', ([float][Math]::Max(6.5, 7.0 * $scale)), [System.Drawing.FontStyle]::Regular)
$tierLabel.Text = ''
$tierLabel.Visible = $false
$tierLabel.Height = 0
$tierLabel.Cursor = [System.Windows.Forms.Cursors]::SizeAll
$form.Controls.Add($tierLabel)

$border = New-Object System.Windows.Forms.Panel
# Fill between top version band and bottom scope band — avoids Dock.Top height thrash.
$border.Dock = [System.Windows.Forms.DockStyle]::Fill
$border.Padding = New-Object System.Windows.Forms.Padding(2)
$border.BackColor = [System.Drawing.Color]::FromArgb(90, 209, 232)
$form.Controls.Add($border)

$inner = New-Object System.Windows.Forms.Panel
$inner.Dock = [System.Windows.Forms.DockStyle]::Fill
$inner.BackColor = [System.Drawing.Color]::FromArgb(22, 28, 38)
$border.Controls.Add($inner)

$markerBox = New-Object System.Windows.Forms.PictureBox
$markerBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
$markerBox.Size = New-Object System.Drawing.Size(([int][Math]::Round(36 * $scale)), ([int][Math]::Round(36 * $scale)))
$markerBox.Location = New-Object System.Drawing.Point(4, 4)
$markerBox.Visible = $false
$markerBox.Cursor = [System.Windows.Forms.Cursors]::SizeAll
$inner.Controls.Add($markerBox)

$strip = New-Object System.Windows.Forms.Panel
$strip.Size = New-Object System.Drawing.Size(([int][Math]::Round(12 * $scale)), ($basePillH - 4))
$strip.Location = New-Object System.Drawing.Point(0, 0)
$strip.BackColor = [System.Drawing.Color]::FromArgb(90, 209, 232)
$strip.Cursor = [System.Windows.Forms.Cursors]::SizeAll
$inner.Controls.Add($strip)

$label = New-Object System.Windows.Forms.Label
$label.AutoSize = $false
$label.AutoEllipsis = $true
$label.UseMnemonic = $false
$label.Size = New-Object System.Drawing.Size(($form.Width - 40), ($basePillH - 4))
$label.Location = New-Object System.Drawing.Point(([int][Math]::Round(20 * $scale)), 0)
$label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$label.ForeColor = [System.Drawing.Color]::White
$label.Font = New-Object System.Drawing.Font('Segoe UI', ([float](11 * $scale)), [System.Drawing.FontStyle]::Regular)
$label.Text = 'CCC…'
$label.Cursor = [System.Windows.Forms.Cursors]::SizeAll
$inner.Controls.Add($label)

$lookFxCanvas = New-Object System.Windows.Forms.PictureBox
$lookFxCanvas.Dock = [System.Windows.Forms.DockStyle]::None
$lookFxCanvas.Location = New-Object System.Drawing.Point(0, 0)
$lookFxCanvas.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Normal
$lookFxCanvas.Visible = $false
$lookFxCanvas.TabStop = $false
$lookFxCanvas.BackColor = [System.Drawing.Color]::Black
$lookFxCanvas.Cursor = [System.Windows.Forms.Cursors]::SizeAll
$form.Controls.Add($lookFxCanvas)
$script:lookFxMarkerRight = 40
$onPillTip = { try { Show-HudPillTipAbove } catch { } }
$onPillTipLeave = { try { Hide-HudPillTipAbove } catch { } }
foreach ($tipCtrl in @($form, $label, $scopeLabel, $tierLabel, $border, $inner, $markerBox, $lookFxCanvas)) {
  if ($tipCtrl) {
    $tipCtrl.add_MouseEnter($onPillTip)
    $tipCtrl.add_MouseLeave($onPillTipLeave)
  }
}
$script:lookFxCoverBusy = $false
$form.add_Layout({
  if ($script:lookFxCoverBusy) { return }
  if (-not $lookFxCanvas -or -not $lookFxCanvas.Visible) { return }
  $script:lookFxCoverBusy = $true
  try {
    if ($tierLabel -and $tierLabel.Visible) { $tierLabel.Visible = $false }
    try { $form.Controls.SetChildIndex($lookFxCanvas, 0) } catch { }
  } finally {
    $script:lookFxCoverBusy = $false
  }
})

$script:agentsRect = $null
$script:lastStamp = ''
$script:lastLabelCore = ''
$script:shown = $false
$script:dragging = $false
$script:dragOffset = New-Object System.Drawing.Point(0, 0)
$script:offRight = $pad
$script:offBottom = $pad
$script:notAgentsSince = $null
$script:zOrderArmed = $false
$script:settingsOpen = $false
$script:hudChildModalOpen = $false
$script:agentsHwnd = [IntPtr]::Zero
$script:pendingSwitchHwnd = [IntPtr]::Zero
$script:pendingSwitchSince = [int64]0
# hostSwitchDwellMs unused — FG Agents / FG IDE process selects host immediately.
$script:hostSwitchDwellMs = 0
$script:accentColor = [System.Drawing.Color]::FromArgb(90, 209, 232)
$script:patternBrush = $null
$script:markerImage = $null
$script:lookFxKey = ''
$script:clickCount = 0
$script:lastClickTick = 0
$script:lastClickScreen = New-Object System.Drawing.Point(-32000, -32000)
$script:dragMoved = $false
$script:pendingSettings = $false
$script:workspaceUrl = ''
$script:workspacePath = ''
$script:openUrlTimer = $null
$script:pendingOpenUrl = $false
$script:clickOnMarker = $false
$script:forceVisual = $false
$script:sidebarLabel = ''
$script:sidebarHost = ''
$script:lastFocusHostWritten = ''
$script:sidebarByHost = @{ cursor = ''; vscode = ''; antigravity = '' }
$script:vsCodeInDone = $false
$script:prevExpand = @{}
$script:pendingChatY = $null
# UIA walks the Agents Chromium tree and freezes the desktop. Opt-in via
# Experiments → UIA or CCC_HUD_UIA=1.
$script:expPrefs = [ordered]@{ enabled = $false; hudWatch = $false; quiet = $false; uia = $false; glass = $false }
try {
  $expPath = Join-Path $cursorDir 'ccc-hud-experiments.json'
  if (Test-Path -LiteralPath $expPath) {
    $ej = Get-Content -LiteralPath $expPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -ne $ej.enabled) { $script:expPrefs.enabled = [bool]$ej.enabled }
    if ($null -ne $ej.hudWatch) { $script:expPrefs.hudWatch = [bool]$ej.hudWatch }
    if ($null -ne $ej.quiet) { $script:expPrefs.quiet = [bool]$ej.quiet }
    if ($null -ne $ej.uia) { $script:expPrefs.uia = [bool]$ej.uia }
    if ($null -ne $ej.glass) { $script:expPrefs.glass = [bool]$ej.glass }
  }
} catch { }
$script:uiaEnabled = (
  ($script:expPrefs.enabled -and $script:expPrefs.uia) -or
  ($env:CCC_HUD_UIA -eq '1' -or $env:CCC_HUD_UIA -eq 'true')
)
$script:uiaReady = $false
$script:uiaInvokeHooked = $false
$script:uiaHookHwnd = [IntPtr]::Zero
if ($script:uiaEnabled) {
  try {
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    $script:uiaReady = $true
  } catch { $script:uiaReady = $false }
}
# Process.GetProcessById + EnumWindows (PS callbacks) freeze the desktop under load.
$script:hostByPid = @{}
$script:hostByPidTtlMs = 30000
$script:lastEnumAt = [int64]0
$script:enumMinMs = 12000
$script:lastStateMtimeUtc = $null
$script:tickFgMs = 2000
$script:tickIdleMs = 6000
# While the IDE editor (not Agents) is focused the pill stays hidden. Poll only the
# foreground title so returning to Cursor/VS Code Agents shows the pill at once.
# Do not EnumWindows or write focus files on this path.
$script:tickWakeMs = 400
# Stable mode (experiments master OFF): slower ticks, rarer enum — pre-experiment feel.
if (-not [bool]$script:expPrefs.enabled) {
  $script:tickFgMs = 2500
  $script:tickIdleMs = 8000
  $script:enumMinMs = 20000
}
try {
  $eFg = [int]$env:CCC_HUD_TICK_MS
  if ($eFg -ge 500 -and $eFg -le 10000) { $script:tickFgMs = $eFg }
} catch { }
try {
  $eIdle = [int]$env:CCC_HUD_TICK_IDLE_MS
  if ($eIdle -ge 1000 -and $eIdle -le 30000) { $script:tickIdleMs = $eIdle }
} catch { }
$script:prefsSnapshot = $null
$script:scopeHost = ''
$script:lastSettingsOpenTick = 0
$script:settingsOpenCooldownMs = 400
$script:lastGitBranch = ''
$script:lastGitTree = ''
$script:lastCloud = $false
$script:cachedVersion = $null
$script:scopeFooterLines = 1
. (Join-Path $PSScriptRoot 'pill\caption.ps1')
. (Join-Path $PSScriptRoot 'pill\position.ps1')


. (Join-Path $PSScriptRoot 'pill\placement.ps1')


. (Join-Path $PSScriptRoot 'pill\visual.ps1')

. (Join-Path $PSScriptRoot 'pill\state.ps1')

. (Join-Path $PSScriptRoot 'pill\actions.ps1')

. (Join-Path $PSScriptRoot 'pill\drag.ps1')

# Visual box-model settings dialog (Schrift/Innen/Rand → clickable layers)
. (Join-Path $PSScriptRoot 'winforms-settings.ps1')

$onDown = [System.Windows.Forms.MouseEventHandler]{ param($s, $e) Begin-Drag $s $e }
$onMove = [System.Windows.Forms.MouseEventHandler]{ param($s, $e) Move-Drag $s $e }
$onUp = [System.Windows.Forms.MouseEventHandler]{ param($s, $e) End-Drag }
$form.add_MouseDown($onDown); $border.add_MouseDown($onDown); $inner.add_MouseDown($onDown); $strip.add_MouseDown($onDown); $label.add_MouseDown($onDown); $markerBox.add_MouseDown($onDown); $scopeLabel.add_MouseDown($onDown); $tierLabel.add_MouseDown($onDown); $lookFxCanvas.add_MouseDown($onDown)
$form.add_MouseMove($onMove); $border.add_MouseMove($onMove); $inner.add_MouseMove($onMove); $strip.add_MouseMove($onMove); $label.add_MouseMove($onMove); $markerBox.add_MouseMove($onMove); $scopeLabel.add_MouseMove($onMove); $tierLabel.add_MouseMove($onMove); $lookFxCanvas.add_MouseMove($onMove)
$form.add_MouseUp($onUp); $border.add_MouseUp($onUp); $inner.add_MouseUp($onUp); $strip.add_MouseUp($onUp); $label.add_MouseUp($onUp); $markerBox.add_MouseUp($onUp); $scopeLabel.add_MouseUp($onUp); $tierLabel.add_MouseUp($onUp); $lookFxCanvas.add_MouseUp($onUp)
$onDbl = [System.EventHandler]{ param($s, $e)
  Request-OpenSettings
}
$form.add_DoubleClick($onDbl); $border.add_DoubleClick($onDbl); $inner.add_DoubleClick($onDbl); $strip.add_DoubleClick($onDbl); $label.add_DoubleClick($onDbl); $markerBox.add_DoubleClick($onDbl); $scopeLabel.add_DoubleClick($onDbl); $tierLabel.add_DoubleClick($onDbl); $lookFxCanvas.add_DoubleClick($onDbl)
try {
  [CccHudDblClickFilter]::Handler = [System.Action]{
    if ($script:settingsOpen -or $script:hudChildModalOpen) { return }
    try {
      [void]$form.BeginInvoke([System.Windows.Forms.MethodInvoker]{ Request-OpenSettings })
    } catch { Request-OpenSettings }
  }
  [void][System.Windows.Forms.Application]::AddMessageFilter((New-Object CccHudDblClickFilter))
} catch { }

. (Join-Path $PSScriptRoot 'pill\tick.ps1')


Load-Prefs
if (Get-Command Initialize-HudI18n -ErrorAction SilentlyContinue) {
  [void](Initialize-HudI18n $script:uiLanguage)
}
Load-LicenseStatus
Refresh-HudGate
Enforce-FreeMarkerPrefs
Apply-HudAutostart
Load-Pos
Apply-PrefsVisual

$script:hudTimer = New-Object System.Windows.Forms.Timer
$script:hudTimer.Interval = $script:tickFgMs
$script:hudTimer.Add_Tick({ Tick-Hud })
$script:hudTimer.Start()

try {
  $script:stateWatcher = New-Object System.IO.FileSystemWatcher
  $script:stateWatcher.Path = $cursorDir
  $script:stateWatcher.Filter = 'ccc-hud-state.json'
  $script:stateWatcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::FileName
  $script:stateWatcher.SynchronizingObject = $form
  $onState = [System.IO.FileSystemEventHandler]{
    try {
      if ($form.IsHandleCreated) {
        [void]$form.BeginInvoke([System.Windows.Forms.MethodInvoker]{ Apply-StateFile })
      } else {
        Apply-StateFile
      }
    } catch { }
  }
  $script:stateWatcher.add_Changed($onState)
  $script:stateWatcher.add_Created($onState)
  try { $script:stateWatcher.add_Renamed($onState) } catch { }
  $script:stateWatcher.EnableRaisingEvents = $true
} catch { }

$form.Add_Shown({
  Write-PidFile
  [void][CccHudWin]::MakeNoActivateToolWindow($form.Handle)
  if (-not (Test-AgentsOrHudForeground)) {
    Hide-Hud
  } else {
    Tick-Hud
    if ($script:agentsHwnd -ne [IntPtr]::Zero) {
      [CccHudWin]::SetOwner($form.Handle, $script:agentsHwnd)
    }
    [CccHudWin]::RaiseAboveOwner($form.Handle)
    $script:zOrderArmed = $true
  }
  if ($env:CCC_HUD_OPEN_SETTINGS -eq '1') {
    $env:CCC_HUD_OPEN_SETTINGS = $null
    try {
      [void]$form.BeginInvoke([System.Windows.Forms.MethodInvoker]{ Request-OpenSettings })
    } catch { Request-OpenSettings }
  }
})

$form.Add_FormClosed({
  Clear-PidFile
  try { [System.Windows.Automation.Automation]::RemoveAllEventHandlers() } catch { }
  try { if ($null -ne $script:stateWatcher) { $script:stateWatcher.EnableRaisingEvents = $false; $script:stateWatcher.Dispose() } } catch { }
  try { $mutex.ReleaseMutex() } catch { }
  $mutex.Dispose()
})

try {
  [System.Windows.Forms.Application]::SetUnhandledExceptionMode(
    [System.Windows.Forms.UnhandledExceptionMode]::CatchException
  )
  [System.Windows.Forms.Application]::add_ThreadException({
    param($src, $ev)
    $ex = $ev.Exception
    if ($ex -is [System.ObjectDisposedException]) { return }
    try {
      $errPath = Join-Path $cursorDir 'ccc-hud-pill.err.log'
      $line = ((Get-Date).ToUniversalTime().ToString('o')) + ' ' + $ex.GetType().FullName + ': ' + $ex.Message
      Add-Content -LiteralPath $errPath -Value $line -Encoding utf8
    } catch { }
  })
} catch { }

Write-PidFile
[void][System.Windows.Forms.Application]::Run($form)
