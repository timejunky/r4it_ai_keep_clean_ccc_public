# Copyright (c) 2026 ready-4-it
# About tab: version, host, logo resolution.

function Get-CccAboutPackageVersion {
  param([string]$HudScriptRoot = '')
  if ([string]::IsNullOrWhiteSpace($HudScriptRoot)) {
    $HudScriptRoot = if ($script:HudScriptRoot) { $script:HudScriptRoot } else { $PSScriptRoot }
  }
  $pick = {
    param([string]$raw)
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    $s = $raw.Trim()
    if ($s.Length -gt 0 -and [int][char]$s[0] -eq 0xFEFF) { $s = $s.Substring(1) }
    if ($s -notmatch '^\d+\.\d+\.\d+') { return $null }
    if ($s -eq '0.0.0') { return $null }
    return $s
  }
  $pkgCandidates = @(
    (Join-Path $HudScriptRoot '..\..\ccc-runtime.json'),
    (Join-Path $HudScriptRoot '..\..\package.json'),
    (Join-Path $HudScriptRoot '..\..\release.json'),
    (Join-Path $HudScriptRoot '..\..\plugin.json'),
    (Join-Path $HudScriptRoot '..\..\.cursor-plugin\plugin.json'),
    (Join-Path $HudScriptRoot '..\..\..\package.json')
  )
  foreach ($pkgPath in $pkgCandidates) {
    if (-not (Test-Path -LiteralPath $pkgPath)) { continue }
    try {
      $pj = (Get-Content -LiteralPath $pkgPath -Raw -Encoding UTF8) | ConvertFrom-Json
      $v = & $pick ([string]$pj.version)
      if ($v) { return $v }
    } catch { }
  }
  try {
    $extRoot = Join-Path $env:USERPROFILE '.vscode\extensions'
    if (Test-Path -LiteralPath $extRoot) {
      $ext = Get-ChildItem -LiteralPath $extRoot -Directory -Filter 'ready-4-it.akc-ccc-vs-*' -ErrorAction SilentlyContinue |
        Sort-Object { [version]($_.Name -replace '^ready-4-it\.akc-ccc-vs-', '') } -Descending |
        Select-Object -First 1
      if ($ext) {
        $pj = (Get-Content -LiteralPath (Join-Path $ext.FullName 'package.json') -Raw -Encoding UTF8) | ConvertFrom-Json
        $v = & $pick ([string]$pj.version)
        if ($v) { return $v }
      }
    }
  } catch { }
  return '0.0.0'
}

function Get-CccAboutHostLabel {
  $hostId = ''
  if ($script:scopeHost -eq 'cursor' -or $script:scopeHost -eq 'vscode') {
    $hostId = [string]$script:scopeHost
  } else {
    try {
      $focusPath = Join-Path $env:USERPROFILE '.cursor\ccc-hud-focus-host.json'
      if (Test-Path -LiteralPath $focusPath) {
        $hostId = [string]((Get-Content -LiteralPath $focusPath -Raw -Encoding UTF8) | ConvertFrom-Json).host
      }
    } catch { }
  }
  if ($hostId -eq 'cursor') {
    $n = Get-HudT 'about.host.cursor'
    return $(if ($n -and $n -ne 'about.host.cursor') { $n } else { 'Cursor' })
  }
  if ($hostId -eq 'vscode' -or $hostId -eq 'vscode-insiders') {
    $n = Get-HudT 'about.host.vscode'
    return $(if ($n -and $n -ne 'about.host.vscode') { $n } else { 'VS Code' })
  }
  $n = Get-HudT 'about.host.unknown'
  return $(if ($n -and $n -ne 'about.host.unknown') { $n } else { 'Host —' })
}

function Get-CccAboutLogoPath {
  param([string]$HudScriptRoot = '')
  if ([string]::IsNullOrWhiteSpace($HudScriptRoot)) {
    $HudScriptRoot = if ($script:HudScriptRoot) { $script:HudScriptRoot } else { $PSScriptRoot }
  }
  $cands = @(
    (Join-Path $HudScriptRoot '..\..\cursor-plugin\assets\logo-marketplace-128.png'),
    (Join-Path $HudScriptRoot '..\..\cursor-plugin\assets\logo.png'),
    (Join-Path $HudScriptRoot '..\..\cursor-plugin\assets\logo-about-32.png'),
    (Join-Path $HudScriptRoot '..\..\4it_ai_keep_clean_ccc_info\imgs\logo\r4it_logo_ccc\vscode_marketplace\r4it_logo_ccc-vscode_marketplace-128.png'),
    (Join-Path $env:USERPROFILE '.cursor\plugins\local\ai-keep-clean-ccc\assets\logo.png'),
    (Join-Path $env:USERPROFILE '.cursor\plugins\local\ai-keep-clean-ccc\assets\logo-marketplace-128.png'),
    (Join-Path $env:USERPROFILE '.cursor\plugins\local\cursor-control-center\assets\logo.png'),
    (Join-Path $env:USERPROFILE '.cursor\plugins\local\cursor-control-center\assets\logo-marketplace-128.png')
  )
  foreach ($c in $cands) {
    try {
      $full = [System.IO.Path]::GetFullPath($c)
      if (Test-Path -LiteralPath $full) { return $full }
    } catch { }
  }
  return $null
}
