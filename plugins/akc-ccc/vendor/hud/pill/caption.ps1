# Copyright (c) 2026 ready-4-it
# AI Keep Clean CCC — Scope caption, version string, edition label, footer layout.
# Job: own all Get-ScopeCaption* / Update-ScopeCaption / Get-CccVersion / scope-line-height logic.
# Caller: winforms-pill.ps1 (dot-sourced after $scopeLabel / $tierLabel form controls exist).

function Get-ScopeHostName([string]$hostId) {
  $defaults = @{ cursor = 'Cursor'; vscode = 'VS Code'; antigravity = 'Antigravity' }
  if (-not $defaults.ContainsKey($hostId)) { return '—' }
  if (-not (Get-Command Get-HudT -ErrorAction SilentlyContinue)) { return $defaults[$hostId] }
  $key = "pill.scope.$hostId"
  $n = Get-HudT $key
  if ($n -and $n -ne $key) { return $n }
  return $defaults[$hostId]
}

function Get-ScopeCaptionText([string]$hostId) {
  $prefix = 'Scope:'
  if (Get-Command Get-HudT -ErrorAction SilentlyContinue) {
    $p = Get-HudT 'pill.scope'
    if ($p -and $p -ne 'pill.scope') { $prefix = $p }
  }
  return "$prefix $(Get-ScopeHostName $hostId)"
}

function Get-CccVersionDirs {
  $dirs = New-Object System.Collections.Generic.List[string]
  $d = $script:HudScriptRoot
  for ($i = 0; $i -lt 8 -and $d; $i++) { [void]$dirs.Add($d); $d = Split-Path -Parent $d }
  return $dirs
}

function Get-CccVersionFromIdentity($dirs) {
  # Returns @{display;version;build} from first ccc-hud-identity.json found, or $null.
  foreach ($dir in $dirs) {
    $idPath = Join-Path $dir 'ccc-hud-identity.json'
    if (-not (Test-Path -LiteralPath $idPath)) { continue }
    try {
      $id = Get-Content -LiteralPath $idPath -Raw -ErrorAction Stop | ConvertFrom-Json
      if ($id.display) { return @{ display = [string]$id.display } }
      $v = if ($id.version) { [string]$id.version } else { $null }
      $b = if ($null -ne $id.build -and "$($id.build)" -ne '') { [string]$id.build } else { $null }
      if ($v) { return @{ version = $v; build = $b } }
    } catch { }
  }
  return $null
}

function Get-CccVersionFromPackage($dirs) {
  foreach ($dir in $dirs) {
    foreach ($rel in @('package.json', '.cursor-plugin\plugin.json', 'plugin.json')) {
      $pj = Join-Path $dir $rel
      if (-not (Test-Path -LiteralPath $pj)) { continue }
      try {
        $json = Get-Content -LiteralPath $pj -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
        if ($json.version -and ([string]$json.version) -ne '0.0.0') { return [string]$json.version }
      } catch { }
    }
  }
  return $null
}

function Get-CccVersionBuild($dirs) {
  foreach ($dir in $dirs) {
    if (-not (Test-Path -LiteralPath (Join-Path $dir '.git'))) { continue }
    try {
      $count = (git -C $dir rev-list --count HEAD 2>$null)
      if ($count) { return ([string]$count).Trim() }
    } catch { }
  }
  return ''
}

function Get-CccVersion {
  if ($script:cachedVersion) { return $script:cachedVersion }
  $dirs = Get-CccVersionDirs
  $id = Get-CccVersionFromIdentity $dirs
  if ($id -and $id.display) { $script:cachedVersion = $id.display; return $script:cachedVersion }
  $version = if ($id -and $id.version) { $id.version } else { Get-CccVersionFromPackage $dirs }
  if (-not $version) { $version = '0.0.0' }
  $build = if ($id -and $id.build) { $id.build } else { Get-CccVersionBuild $dirs }
  $script:cachedVersion = if ($build -and $build -ne '0') { "$version.$build" } else { "$version" }
  return $script:cachedVersion
}

function Get-HudEditionLabel {
  $tier = if ($script:hudTier) { [string]$script:hudTier } else { 'none' }
  if ($tier -eq 'full') { return 'pro' }
  if ($tier -eq 'trial') { return 'trial' }
  return 'free'
}

# Pro-only top band: "akc ccc pro version". Git and cloud use their own feature ids.
function Test-HudProChrome {
  return (Test-HudFeature 'hud.chrome.version')
}

function Get-ScopeLineHeight {
  return [Math]::Max(12, [int][Math]::Round(14 * $scale))
}

function Get-ScopeFooterHeight {
  $lineH = Get-ScopeLineHeight
  $n = [int]$script:scopeFooterLines
  if ($n -lt 1) { $n = 1 }
  return ($lineH * $n)
}

function Get-ScopeCaptionHostId {
  $hostId = $null
  if ($script:agentsHwnd -ne [IntPtr]::Zero) { $hostId = Get-AgentsHostFromHwnd $script:agentsHwnd }
  if (-not $hostId) {
    try {
      $focusPath = Join-Path $env:USERPROFILE '.cursor\ccc-hud-focus-host.json'
      if (Test-Path -LiteralPath $focusPath) { $hostId = [string]((Get-Content -LiteralPath $focusPath -Raw | ConvertFrom-Json).host) }
    } catch { }
  }
  if ($hostId -ne 'cursor' -and $hostId -ne 'vscode' -and $hostId -ne 'antigravity') { return '' }
  return [string]$hostId
}

function Build-ScopeCaptionText([string]$scopeLine) {
  $showGit   = Test-HudFeature 'hud.gitContext'
  $showCloud = Test-HudFeature 'hud.chrome.cloud'
  $line1 = New-Object System.Collections.Generic.List[string]
  [void]$line1.Add($scopeLine)
  $line2 = ''
  if ($showCloud -and $script:lastCloud) { $line2 = 'cloud' }
  elseif ($showGit) {
    if (-not [string]::IsNullOrWhiteSpace($script:lastGitBranch)) { [void]$line1.Add("branch:$($script:lastGitBranch)") }
    if (-not [string]::IsNullOrWhiteSpace($script:lastGitTree)) { $line2 = "tree:$($script:lastGitTree)" }
  }
  $text = ($line1 -join '  ·  ')
  if ($line2) { $text = "$text`n$line2" }
  $script:scopeFooterLines = if ($line2) { 2 } else { 1 }
  return $text
}

function Apply-ScopeTierLabel([bool]$showVersion, [bool]$fxCover) {
  if ($showVersion) {
    $tierText = "akc ccc pro version $(Get-CccVersion)"
    if ($tierLabel.Text -ne $tierText) { $tierLabel.Text = $tierText }
    # 3D bitmap paints this line; visible label covers with text color.
    $want = -not $fxCover
    if ($tierLabel.Visible -ne $want) { $tierLabel.Visible = $want }
  } else {
    if ($tierLabel.Text -ne '') { $tierLabel.Text = '' }
    if ($tierLabel.Visible) { $tierLabel.Visible = $false }
  }
}

function Update-ScopeCaption {
  $hostId    = Get-ScopeCaptionHostId
  $scopeText = Build-ScopeCaptionText (Get-ScopeCaptionText $hostId)
  $fxCover   = (Test-HudFeature 'hud.lookPresets') -and (Get-Command Get-HudLookFxName -ErrorAction SilentlyContinue) -and -not [string]::IsNullOrWhiteSpace((Get-HudLookFxName ([string]$script:prefs.lookFx)))
  Apply-ScopeTierLabel (Test-HudFeature 'hud.chrome.version') $fxCover

  $script:scopeBandH = Get-ScopeFooterHeight
  if ($scopeLabel.Height -ne $script:scopeBandH) { $scopeLabel.Height = $script:scopeBandH }
  $scopeLabel.AutoEllipsis = ($script:scopeFooterLines -lt 2)
  $scopeChanged = ($scopeLabel.Text -ne $scopeText)
  if ($scopeChanged) { $scopeLabel.Text = $scopeText }
  $script:scopeHost = $hostId
  if ($fxCover -and (Get-Command Set-HudLookFxCanvasCover -ErrorAction SilentlyContinue)) { try { Set-HudLookFxCanvasCover $true } catch { } }
  if ($scopeChanged -and (Get-Command Refresh-PillWidth -ErrorAction SilentlyContinue)) { Refresh-PillWidth }
}
