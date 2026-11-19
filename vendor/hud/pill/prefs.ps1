# Copyright (c) 2026 ready-4-it
# AI Keep Clean CCC — Prefs store: defaults, load/save, per-project scoping, zebra consent.
# Job: own $script:prefs, $script:prefsStore, and every function that reads/writes them.
# Caller: winforms-pill.ps1 (dot-sourced after $prefsPath / $cursorDir are set).

# --- prefs defaults + scoped store (global / per-project) ---
$script:prefs = [ordered]@{
  fontFamily         = 'Segoe UI'
  fontSize           = 11
  markerMode         = 'emoji'
  markerEmoji        = '🔵'
  markerColor        = ''
  pattern            = 'stripes'
  imagePath          = ''
  logoBrowseDir      = ''
  logoSourceName     = ''
  overwriteCustomLogo = $false
  borderColor        = ''
  borderWidth        = 2
  fillColor          = '#161c26'
  textColor          = '#ffffff'
  lookFx             = ''
  lookId             = ''
  padding            = 8
  margin             = 4
  sizePreset         = 'M'
  showWorkspaceEmoji = $false
  autostart          = $false
}

$script:uiLanguage = 'auto'

$script:defaultPrefs = [ordered]@{}
foreach ($k in @($script:prefs.Keys)) { $script:defaultPrefs[$k] = $script:prefs[$k] }

$script:prefsStore = @{
  global   = $null
  projects = @{}
}
$script:editScope = 'project'   # settings dialog: 'project' | 'global'
$script:currentWorkspaceId = ''

function New-PrefsMap {
  $m = [ordered]@{}
  foreach ($k in @($script:defaultPrefs.Keys)) { $m[$k] = $script:defaultPrefs[$k] }
  return $m
}

function Merge-PrefsInto($target, $src) {
  if ($null -eq $src) { return }
  foreach ($k in @($script:defaultPrefs.Keys)) {
    $v = $null
    if ($src -is [hashtable] -or $src -is [System.Collections.Specialized.OrderedDictionary]) {
      if ($src.Contains($k)) { $v = $src[$k] }
    } else {
      try { $v = $src.$k } catch { $v = $null }
    }
    if ($null -ne $v) { $target[$k] = $v }
  }
}

function Get-PrefsProjectKey([string]$wsId) {
  if (-not [string]::IsNullOrWhiteSpace($wsId)) { return $wsId }
  if (-not [string]::IsNullOrWhiteSpace($script:currentWorkspaceId)) { return $script:currentWorkspaceId }
  return '_unknown'
}

function Get-EffectivePrefs([string]$wsId) {
  $m = New-PrefsMap
  Merge-PrefsInto $m $script:prefsStore.global
  $allowProject = $false
  try { $allowProject = (Test-HudFeature 'hud.scope.project') } catch { $allowProject = $false }
  if ($allowProject) {
    $key = Get-PrefsProjectKey $wsId
    if ($script:prefsStore.projects.ContainsKey($key)) {
      Merge-PrefsInto $m $script:prefsStore.projects[$key]
    }
  }
  return $m
}

function Get-PrefsForEdit([string]$scope) {
  $allowProject = $false
  try { $allowProject = (Test-HudFeature 'hud.scope.project') } catch { $allowProject = $false }
  if ($scope -eq 'global' -or -not $allowProject) {
    $m = New-PrefsMap
    Merge-PrefsInto $m $script:prefsStore.global
    return $m
  }
  $key = Get-PrefsProjectKey $script:currentWorkspaceId
  $m = New-PrefsMap
  Merge-PrefsInto $m $script:prefsStore.global
  if ($script:prefsStore.projects.ContainsKey($key)) {
    Merge-PrefsInto $m $script:prefsStore.projects[$key]
  }
  return $m
}

function Save-PrefsToStore([string]$scope, $map) {
  $copy = [ordered]@{}
  foreach ($k in @($script:defaultPrefs.Keys)) { $copy[$k] = $map[$k] }
  if ($scope -eq 'global') {
    $script:prefsStore.global = $copy
  } else {
    $key = Get-PrefsProjectKey $script:currentWorkspaceId
    $script:prefsStore.projects[$key] = $copy
  }
}

function Merge-HudLegalConsentFromStore($p) {
  if ($null -eq $p) { return }
  if ($p.PSObject.Properties['zebraNetworkConsentAt']) {
    $script:zebraNetworkConsentAt = [string]$p.zebraNetworkConsentAt
  }
  if ($p.PSObject.Properties['zebraNetworkConsentVersion']) {
    $script:zebraNetworkConsentVersion = [string]$p.zebraNetworkConsentVersion
  }
}

function Test-HudZebraNetworkConsent {
  if ([string]::IsNullOrWhiteSpace([string]$script:zebraNetworkConsentAt)) { return $false }
  $ver = if ($script:zebraNetworkConsentVersion) { [string]$script:zebraNetworkConsentVersion } else { '' }
  return ($ver -eq '1')
}

function Test-HudNeedsZebraUpdateConsent {
  if (Test-HudZebraNetworkConsent) { return $false }
  $tier = if ($script:hudTier) { [string]$script:hudTier } else { 'none' }
  if (($tier -eq 'trial' -or $tier -eq 'full') -and $script:isActivatedOnThisDevice) { return $true }
  return $false
}

function Grant-HudZebraNetworkConsent {
  $script:zebraNetworkConsentAt = (Get-Date).ToUniversalTime().ToString('o')
  $script:zebraNetworkConsentVersion = '1'
  try {
    if ($null -eq $script:prefsStore) {
      $script:prefsStore = @{ global = (New-PrefsMap); projects = @{} }
    }
    if (Get-Command Save-Prefs -ErrorAction SilentlyContinue) { Save-Prefs }
  } catch { }
}

function Revoke-HudZebraNetworkConsent {
  $script:zebraNetworkConsentAt = $null
  $script:zebraNetworkConsentVersion = $null
  try {
    if (Get-Command Save-Prefs -ErrorAction SilentlyContinue) { Save-Prefs }
  } catch { }
}

function Import-PrefsStoreFromObj($p) {
  # Merge a parsed prefs store object into $script:prefsStore. Returns $true if it looks like a store.
  if ($null -ne $p.global) {
    $g = New-PrefsMap; Merge-PrefsInto $g $p.global; $script:prefsStore.global = $g
  }
  if ($null -ne $p.projects) {
    foreach ($prop in $p.projects.PSObject.Properties) {
      $pm = New-PrefsMap; Merge-PrefsInto $pm $prop.Value; $script:prefsStore.projects[$prop.Name] = $pm
    }
  }
  if ($p.editScope -eq 'global' -or $p.editScope -eq 'project') { $script:editScope = [string]$p.editScope }
  if ($p.uiLanguage) { $script:uiLanguage = [string]$p.uiLanguage }
  Merge-HudLegalConsentFromStore $p
}

function Load-PrefsFromSealCli([string]$cli) {
  # Returns $true if seal-cli delivered a valid store.
  if (-not ((Test-Path -LiteralPath $cli) -and (Test-Path -LiteralPath $prefsPath))) { return $false }
  try {
    $raw = & node $cli 'load' $prefsPath 2>$null
    if ([string]::IsNullOrWhiteSpace($raw)) { return $false }
    $res = $raw | ConvertFrom-Json
    if (-not ($res.ok -and $res.store)) { return $false }
    Import-PrefsStoreFromObj $res.store
    return $true
  } catch { return $false }
}

function Load-PrefsFromJson {
  if (-not (Test-Path -LiteralPath $prefsPath)) { return }
  try {
    $p = (Get-Content -LiteralPath $prefsPath -Raw) | ConvertFrom-Json
    if ($null -ne $p.global -or $null -ne $p.projects) { Import-PrefsStoreFromObj $p }
    else { $g = New-PrefsMap; Merge-PrefsInto $g $p; $script:prefsStore.global = $g }
  } catch { }
}

function Load-Prefs {
  $script:prefsStore.global = New-PrefsMap
  $script:prefsStore.projects = @{}
  $cli = Join-Path $script:HudScriptRoot 'seal-hud-prefs.mjs'
  if (-not (Load-PrefsFromSealCli $cli)) { Load-PrefsFromJson }
  $script:prefs = Get-EffectivePrefs $script:currentWorkspaceId
}

function Save-Prefs {
  try {
    $projectsObj = [ordered]@{}
    foreach ($k in @($script:prefsStore.projects.Keys)) {
      $projectsObj[$k] = $script:prefsStore.projects[$k]
    }
    $out = [ordered]@{
      version    = 2
      editScope  = $script:editScope
      uiLanguage = $script:uiLanguage
      global     = $script:prefsStore.global
      projects   = $projectsObj
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$script:zebraNetworkConsentAt)) {
      $out.zebraNetworkConsentAt = [string]$script:zebraNetworkConsentAt
      $out.zebraNetworkConsentVersion = if ($script:zebraNetworkConsentVersion) {
        [string]$script:zebraNetworkConsentVersion
      } else {
        '1'
      }
    }
    ($out | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $prefsPath -Encoding utf8
    # Device+license HMAC seal (or Free strip) via Node
    Reseal-HudPrefsAfterActivation
  } catch { }
}

function Reseal-HudPrefsAfterActivation {
  $cli = Join-Path $script:HudScriptRoot 'seal-hud-prefs.mjs'
  if (-not (Test-Path -LiteralPath $cli)) { return }
  try { & node $cli 'reseal' $prefsPath 2>$null | Out-Null } catch { }
}

function Seal-HudPrefsExportFile([string]$exportPath) {
  $cli = Join-Path $script:HudScriptRoot 'seal-hud-prefs.mjs'
  if (-not (Test-Path -LiteralPath $cli)) { return }
  if (-not (Test-Path -LiteralPath $exportPath)) { return }
  try { & node $cli 'seal-export' $exportPath 2>$null | Out-Null } catch { }
}

function Apply-WorkspacePrefs([string]$wsId) {
  $script:currentWorkspaceId = if ($wsId) { $wsId } else { '' }
  Ensure-ProjectIdentityDefaults $script:currentWorkspaceId
  $script:prefs = Get-EffectivePrefs $script:currentWorkspaceId
}

function Get-AutoMarkerEmoji([string]$wsId) {
  $emojis = @(
    '🔵','🟢','🟣','🟠','🟡','🔴','⚪','🟤','💠','🔷',
    '🔶','⭐','🍀','🎯','🧩','🧪','🌙','☀️','🌊','🔥'
  )
  $s = if ($wsId) { $wsId } else { '_unknown' }
  $h = 0
  foreach ($ch in $s.ToCharArray()) {
    $h = (($h * 33) + [int][char]$ch) -band 0x7fffffff
  }
  return $emojis[$h % $emojis.Count]
}

function Ensure-ProjectIdentityDefaults([string]$wsId) {
  if ([string]::IsNullOrWhiteSpace($wsId)) { return }
  $key = Get-PrefsProjectKey $wsId
  if ($script:prefsStore.projects.ContainsKey($key)) { return }
  # First visit: distinct emoji per project (no blocking wizard)
  $script:prefsStore.projects[$key] = [ordered]@{
    markerEmoji  = (Get-AutoMarkerEmoji $key)
    markerMode   = 'emoji'
    _autoIdentity = $true
  }
  Save-Prefs
}
