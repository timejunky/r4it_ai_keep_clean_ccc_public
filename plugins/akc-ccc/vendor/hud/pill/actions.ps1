# Copyright (c) 2026 ready-4-it
# AI Keep Clean CCC — Pill actions: workspace URL, settings open/close, modal guard.
# Job: own URL-open scheduling, settings dialog launch, and suppress/restore helpers.
# Caller: winforms-pill.ps1 (dot-sourced after form and openUrlTimer exist).
function Resolve-WorkspaceOpenTarget {
  if (-not [string]::IsNullOrWhiteSpace($script:workspaceUrl)) {
    return [string]$script:workspaceUrl
  }
  $id = [string]$script:currentWorkspaceId
  if ($id -and ($id -match '\.loc$')) {
    return "http://$id"
  }
  if (-not [string]::IsNullOrWhiteSpace($script:workspacePath) -and (Test-Path -LiteralPath $script:workspacePath)) {
    return [string]$script:workspacePath
  }
  return ''
}

function Open-WorkspaceUrl {
  $target = Resolve-WorkspaceOpenTarget
  if ([string]::IsNullOrWhiteSpace($target)) { return }
  # Local folder → Explorer; http(s) / other URIs → default handler
  if ((Test-Path -LiteralPath $target) -and -not ($target -match '^(https?|mailto):')) {
    try {
      Start-Process explorer.exe -ArgumentList @($target) | Out-Null
      return
    } catch { }
  }
  try {
    Start-Process $target | Out-Null
  } catch {
    if (Test-Path -LiteralPath $target) {
      Start-Process explorer.exe -ArgumentList @($target) | Out-Null
    }
  }
}

function Cancel-PendingOpenUrl {
  $script:pendingOpenUrl = $false
  if ($null -ne $script:openUrlTimer) {
    try { $script:openUrlTimer.Stop(); $script:openUrlTimer.Dispose() } catch { }
    $script:openUrlTimer = $null
  }
}

function Get-HudDoubleClickMs {
  $ms = [System.Windows.Forms.SystemInformation]::DoubleClickTime
  if ($ms -lt 400) { return 500 }
  return [int]$ms
}

$script:pillSuppressedForSettings = $false

function Restore-HudAfterSettings {
  $script:pillSuppressedForSettings = $false
  $script:notAgentsSince = $null
  $script:zOrderArmed = $false
  if (-not (Test-AgentsOrHudForeground)) {
    Hide-Hud
    return
  }
  $rect = $null
  try { $rect = Find-AgentsWindowRect } catch { }
  if ($null -eq $rect) {
    try { Tick-Hud } catch { }
    return
  }
  try { Apply-StateFile } catch { }
  if (-not $script:dragging) { Place-OnAgents $rect }
  $form.Opacity = 1.0
  [CccHudWin]::ShowNoActivate($form.Handle)
  $script:shown = $true
  if ($script:agentsHwnd -ne [IntPtr]::Zero) {
    [CccHudWin]::SetOwner($form.Handle, $script:agentsHwnd)
  }
  [CccHudWin]::MakeNoActivateToolWindow($form.Handle)
  [CccHudWin]::RaiseAboveOwner($form.Handle)
  $script:zOrderArmed = $true
  Set-HudTickInterval $script:tickFgMs
  # Layout after show — ClientSize is final; Padding indent must re-apply.
  try {
    if ($form.IsHandleCreated) {
      [void]$form.BeginInvoke([System.Windows.Forms.MethodInvoker]{
        Place-PillMarkerAndLabel
        try { $form.Invalidate($true); $form.Update() } catch { }
      })
    } else {
      Place-PillMarkerAndLabel
    }
  } catch {
    Place-PillMarkerAndLabel
  }
}

function Set-HudPillSuppressedForSettings {
  param([bool]$Suppressed)
  $script:pillSuppressedForSettings = [bool]$Suppressed
  if ($Suppressed) {
    if ($script:shown) {
      [CccHudWin]::HideNoActivate($form.Handle)
      $form.Opacity = 0
      [CccHudWin]::MoveNoActivate($form.Handle, -32000, -32000)
      $script:shown = $false
      $script:zOrderArmed = $false
    }
    return
  }
  Restore-HudAfterSettings
}

function Get-HudSettingsFailVersion {
  # Try runtime identity first, then Get-CccVersion, then walk for identity.json.
  $ver = '0.0.0'
  try { if (Get-Command Get-CccVersion -ErrorAction SilentlyContinue) { $ver = [string](Get-CccVersion) } } catch { }
  if ([string]::IsNullOrWhiteSpace($ver) -or $ver -eq '0.0.0') {
    try {
      $walk = $PSScriptRoot
      for ($i = 0; $i -lt 6 -and $walk; $i++) {
        $cand = Join-Path $walk 'ccc-hud-identity.json'
        if (Test-Path -LiteralPath $cand) {
          $j = (Get-Content -LiteralPath $cand -Raw -Encoding UTF8) | ConvertFrom-Json
          $ver = if ($j.display) { [string]$j.display } else { [string]$j.version }
          break
        }
        $walk = Split-Path -Parent $walk
      }
    } catch { }
  }
  if ([string]::IsNullOrWhiteSpace($ver)) { return '0.0.0' }
  return $ver
}

function Get-HudSettingsFailFooter {
  if (Get-Command Get-HudRuntimeIdentity -ErrorAction SilentlyContinue) {
    try { $id = Get-HudRuntimeIdentity; if ($id -and $id.Footer) { return [string]$id.Footer } } catch { }
  }
  $ver = Get-HudSettingsFailVersion
  $hint = @([string]$PSScriptRoot, [string]$script:HudScriptRoot) -join '|'
  $channel = if ($hint -match '(?i)r4it_ai_keep_clean_ccc_vs|akc-ccc-vs|vscode-agent-plugin|[\\/]extension[\\/](hud|agent-plugin)' -or $hint -match '(?i)globalStorage') { 'Extension' } else { 'Plugin' }
  $hid = if ($script:sidebarHost) { [string]$script:sidebarHost } elseif ($script:scopeHost) { [string]$script:scopeHost } else { '' }
  if ($hid -eq 'code') { $hid = 'vscode' }
  $deriv = switch ($hid) {
    'cursor' { 'Cursor' }; 'vscode' { 'VS Code' }; 'vscode-insiders' { 'VS Code Insiders' }
    'antigravity' { 'Antigravity' }; default { 'Unknown' }
  }
  $surface = if ($script:sidebarHost -or ($script:agentsHwnd -and $script:agentsHwnd -ne [IntPtr]::Zero)) { 'Agent' } else { 'IDE' }
  return "$ver · $surface · $deriv · $channel"
}

function Request-OpenSettings {
  param(
    [string]$StartPage = ''
  )
  $deep = -not [string]::IsNullOrWhiteSpace($StartPage)
  if ($script:settingsOpen -and -not $deep) { return }
  if (-not $deep) {
    $script:pendingSettings = $false
    $script:clickCount = 0
    $script:dragMoved = $false
    $script:dragging = $false
    try { $form.Capture = $false } catch { }
    Cancel-PendingOpenUrl
  }
  try {
    # Reload on each open — pill dot-sources settings once at boot; stale copy caused null-ref crashes after plugin:install.
    # actions.ps1 lives in pill/; the settings entry point is the HUD root next to this folder.
    $hudRoot = $PSScriptRoot
    if (-not (Test-Path -LiteralPath (Join-Path $hudRoot 'winforms-settings.ps1'))) {
      $parentHud = Split-Path $PSScriptRoot -Parent
      if (Test-Path -LiteralPath (Join-Path $parentHud 'winforms-settings.ps1')) { $hudRoot = $parentHud }
    }
    $errLoad = Join-Path $hudRoot 'settings\_error-load.ps1'
    if (Test-Path -LiteralPath $errLoad) { . $errLoad }
    $gatePs1 = Join-Path $hudRoot 'hud-gate.ps1'
    if (Test-Path -LiteralPath $gatePs1) { . $gatePs1 }
    $settingsPs1 = Join-Path $hudRoot 'winforms-settings.ps1'
    if (Test-Path -LiteralPath $settingsPs1) { . $settingsPs1 }
    if (Get-Command Initialize-HudI18n -ErrorAction SilentlyContinue) {
      $lang = if (Get-Command Get-HudLang -ErrorAction SilentlyContinue) { Get-HudLang } else { 'auto' }
      Initialize-HudI18n $lang | Out-Null
    }
    $gc = Get-Command Show-SettingsPanel -ErrorAction Stop
    & $gc -StartPage $StartPage
  } catch {
    if (Get-Command Show-HudSettingsFailed -ErrorAction SilentlyContinue) {
      Show-HudSettingsFailed $_
    } else {
      $msg = $_.Exception.Message
      if ([string]::IsNullOrWhiteSpace($msg)) { $msg = [string]$_ }
      $footer = Get-HudSettingsFailFooter
      try {
        [void][System.Windows.Forms.MessageBox]::Show(
          ("CCC HUD settings failed:`n$msg`n`n$footer"),
          'AI Keep Clean CCC',
          [System.Windows.Forms.MessageBoxButtons]::OK,
          [System.Windows.Forms.MessageBoxIcon]::Warning
        )
      } catch { }
    }
  }
}

function Schedule-OpenWorkspaceUrl {
  if (-not (Test-HudFeature 'hud.logo.openWorkspaceUrl')) {
    Show-ProUpgradeHint 'Logo-Klick öffnet Workspace-URL'
    return
  }
  Cancel-PendingOpenUrl
  $script:pendingOpenUrl = $true
  $script:openUrlTimer = New-Object System.Windows.Forms.Timer
  $script:openUrlTimer.Interval = 320
  $script:openUrlTimer.Add_Tick({
    $t = $script:openUrlTimer
    if ($null -ne $t) { $t.Stop() }
    if ($script:pendingOpenUrl -and $script:clickCount -lt 2 -and -not $script:dragMoved) {
      if (-not (Test-HudFeature 'hud.logo.openWorkspaceUrl')) { return }
      if ([string]$script:prefs.markerMode -eq 'image' -and $markerBox.Visible) {
        Open-WorkspaceUrl
      }
    }
    $script:pendingOpenUrl = $false
    if ($null -ne $script:openUrlTimer) {
      try { $script:openUrlTimer.Dispose() } catch { }
      $script:openUrlTimer = $null
    }
  })
  $script:openUrlTimer.Start()
}