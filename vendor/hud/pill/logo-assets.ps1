# Copyright (c) 2026 ready-4-it
# AI Keep Clean CCC — Logo and asset-file management helpers.
# Job: read/write ccc-hud-assets/ (custom logos, source-name map, prefs profiles, validators).
# Caller: winforms-pill.ps1 (dot-sourced after $assetsDir / $cursorDir / $PSScriptRoot are set).

function Get-HudCustomLogoFiles {
  if (-not (Test-HudPath $assetsDir)) { return @() }
  # Look-Preset orbs are shipped product art (orb-*), not user uploads (custom-*).
  Get-ChildItem -LiteralPath $assetsDir -File -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Extension -match '^\.(png|jpg|jpeg|bmp|gif|ico|webp)$' -and
      $_.Name -notmatch '^(?i)orb-'
    }
}

function Test-HudIsUserCustomLogo([string]$path) {
  if ([string]::IsNullOrWhiteSpace($path)) { return $false }
  if (-not (Test-HudPath $path)) { return $false }
  try {
    $full = [System.IO.Path]::GetFullPath($path)
    $root = [System.IO.Path]::GetFullPath($assetsDir)
    if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
    $name = [System.IO.Path]::GetFileName($full)
    # User uploads: custom-*. Built-in preset orbs: orb-* (never show as "Logo"-Feld).
    if ($name -match '^(?i)orb-') { return $false }
    return $true
  } catch { return $false }
}

function Get-HudLogoSourceMapPath {
  return (Join-Path $assetsDir 'logo-sources.json')
}

function Get-HudLogoSourceMap {
  $map = @{}
  $p = Get-HudLogoSourceMapPath
  if (-not (Test-HudPath $p)) { return $map }
  try {
    $j = Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $j) { return $map }
    $j.PSObject.Properties | ForEach-Object {
      if (-not [string]::IsNullOrWhiteSpace($_.Name) -and $null -ne $_.Value) {
        $map[([string]$_.Name)] = [string]$_.Value
      }
    }
  } catch { }
  return $map
}

function Set-HudLogoSourceName([string]$storedFileName, [string]$originalName) {
  if ([string]::IsNullOrWhiteSpace($storedFileName)) { return }
  $map = Get-HudLogoSourceMap
  if ([string]::IsNullOrWhiteSpace($originalName)) {
    $map.Remove($storedFileName)
  } else {
    $map[$storedFileName] = $originalName
  }
  $out = @{}
  foreach ($k in @($map.Keys)) { $out[$k] = $map[$k] }
  try {
    if (-not (Test-HudPath $assetsDir)) {
      New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
    }
    $json = ($out | ConvertTo-Json -Compress)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Get-HudLogoSourceMapPath), $json, $utf8NoBom)
  } catch { }
}

function Get-HudLogoSourceName([string]$path) {
  if ([string]::IsNullOrWhiteSpace($path)) { return '' }
  try {
    $bn = [System.IO.Path]::GetFileName($path)
  } catch { return '' }
  $map = Get-HudLogoSourceMap
  if ($map.ContainsKey($bn) -and -not [string]::IsNullOrWhiteSpace([string]$map[$bn])) {
    return [string]$map[$bn]
  }
  try {
    $fromPrefs = [string]$script:prefs.logoSourceName
    if (-not [string]::IsNullOrWhiteSpace($fromPrefs) -and (Test-HudIsUserCustomLogo $path)) {
      return $fromPrefs
    }
  } catch { }
  return ''
}

function Resolve-HudCustomLogoFromLabel([string]$label) {
  if ([string]::IsNullOrWhiteSpace($label)) { return '' }
  $direct = Join-Path $assetsDir $label
  if (Test-HudPath $direct) { return $direct }
  $map = Get-HudLogoSourceMap
  foreach ($k in @($map.Keys)) {
    if ([string]$map[$k] -eq $label) {
      $cand = Join-Path $assetsDir $k
      if (Test-HudPath $cand) { return $cand }
    }
  }
  return ''
}

function Get-HudLogoFieldDisplay([string]$path) {
  if (-not (Test-HudIsUserCustomLogo $path)) { return '' }
  $orig = Get-HudLogoSourceName $path
  if (-not [string]::IsNullOrWhiteSpace($orig)) { return $orig }
  try { return [System.IO.Path]::GetFileName($path) } catch { return [string]$path }
}

function Get-HudPrefsProfileFiles {
  $dir = Join-Path $cursorDir 'ccc-hud-prefs-profiles'
  if (-not (Test-Path -LiteralPath $dir)) { return @() }
  Get-ChildItem -LiteralPath $dir -Filter '*.json' -File -ErrorAction SilentlyContinue
}

function Get-HudLogoBrowseInitialDir {
  $cand = ''
  try { $cand = [string]$script:prefs.logoBrowseDir } catch { $cand = '' }
  if (-not [string]::IsNullOrWhiteSpace($cand) -and (Test-Path -LiteralPath $cand)) {
    return $cand
  }
  $newest = @(Get-HudCustomLogoFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
  if ($newest.Count -gt 0 -and $newest[0]) {
    return [string]$newest[0].DirectoryName
  }
  if (Test-HudPath $assetsDir) { return $assetsDir }
  try {
    return [Environment]::GetFolderPath('MyPictures')
  } catch {
    return $env:USERPROFILE
  }
}

function Invoke-HudNodeJson([string[]]$nodeArgs) {
  try {
    $raw = & node @nodeArgs 2>$null
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return ($raw | ConvertFrom-Json)
  } catch { return $null }
}

function Test-HudLogoAssetFile([string]$path) {
  $cli = Join-Path $script:HudScriptRoot 'validate-logo-asset.mjs'
  if (-not (Test-Path -LiteralPath $cli)) {
    return @{ ok = $true; message = 'OK'; hint = 'PNG/JPG/BMP/GIF/ICO/WebP · max 2 MB · max 2048×2048' }
  }
  $r = Invoke-HudNodeJson @($cli, $path)
  if ($null -eq $r) {
    return @{
      ok = $false
      message = 'Logo-Prüfung fehlgeschlagen (Validator).'
      hint = 'PNG/JPG/BMP/GIF/ICO/WebP · max 2 MB · max 2048×2048'
    }
  }
  return $r
}

function Show-HudLogoReject($result) {
  $hint = if ($result.hint) { [string]$result.hint } else { 'PNG/JPG/BMP/GIF/ICO/WebP · max 2 MB · max 2048×2048' }
  $msg = "$([string]$result.message)`r`n`r`n$hint"
  try {
    [System.Windows.Forms.MessageBox]::Show(
      $msg,
      'CCC Logo',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
  } catch { }
}

function Import-HudPrefsFromFile([string]$path, [string]$tier) {
  $cli = Join-Path $script:HudScriptRoot 'validate-prefs-import.mjs'
  if (-not (Test-Path -LiteralPath $cli)) { return $null }
  return Invoke-HudNodeJson @($cli, $path, $tier)
}
