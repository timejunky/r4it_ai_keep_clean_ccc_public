# Copyright (c) 2026 ready-4-it
# AI Keep Clean CCC — License/activation, tier feature checks, autostart, display-mode guards.
# Job: own all license state, activation CLI calls, feature-gate helpers, and autostart link.
# Caller: winforms-pill.ps1 (dot-sourced after hud-gate.ps1 so Refresh-HudGate is available).

function Load-LicenseStatus {
  $script:licenseToken = ''
  $script:licenseStatus = 'kein Aktivierungsschlüssel'
  $script:activationUrl = 'https://www.ready-4-it.com/de/license/activate#p=ccc'
  $script:deviceHashShort = ''
  $script:isActivatedOnThisDevice = $false
  $script:licenseIat = $null
  $script:licenseExp = $null
  if (Test-Path -LiteralPath $licensePath) {
    try {
      $L = (Get-Content -LiteralPath $licensePath -Raw) | ConvertFrom-Json
      if ($L.token) {
        $script:licenseToken = [string]$L.token
        $script:licenseStatus = if ($L.status) { [string]$L.status } else { 'gespeichert' }
      }
    } catch { }
  }
  Sync-HudLicenseExpiryFromToken $script:licenseToken
  Refresh-HudGate
  if ($script:hudStatusText) { $script:licenseStatus = [string]$script:hudStatusText }
}

function Get-HudR4itPayload([string]$token) {
  if ([string]::IsNullOrWhiteSpace($token)) { return $null }
  $parts = $token.Trim().Split('.')
  if ($parts.Count -lt 2) { return $null }
  $b64 = [string]$parts[1]
  $b64 = $b64.Replace('-', '+').Replace('_', '/')
  switch ($b64.Length % 4) {
    2 { $b64 += '==' }
    3 { $b64 += '=' }
  }
  try {
    $json = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))
    return ($json | ConvertFrom-Json)
  } catch { return $null }
}

function Sync-HudLicenseExpiryFromToken([string]$token) {
  $script:licenseIat = $null
  $script:licenseExp = $null
  $p = Get-HudR4itPayload $token
  if ($null -eq $p) { return }
  try {
    if ($null -ne $p.iat) { $script:licenseIat = [long]$p.iat }
    if ($null -ne $p.exp) { $script:licenseExp = [long]$p.exp }
  } catch { }
}

function Format-HudMaskedToken([string]$token) {
  if ([string]::IsNullOrWhiteSpace($token)) { return '' }
  $t = $token.Trim()
  if ($t.Length -le 22) {
    $n = [Math]::Min(8, $t.Length)
    return ($t.Substring(0, $n) + '…')
  }
  return ($t.Substring(0, 12) + '…' + $t.Substring($t.Length - 8))
}

function Test-HudLicenseAccepted {
  $tier = if ($script:hudTier) { [string]$script:hudTier } else { 'none' }
  if ($tier -ne 'trial' -and $tier -ne 'full') { return $false }
  return -not [string]::IsNullOrWhiteSpace([string]$script:licenseToken)
}

function Get-HudLicenseExpiryInfo {
  # Returns hashtable: hasExp, fractionLeft (0..1), daysLeft, expDate, expired, iat, exp
  $out = @{
    hasExp       = $false
    fractionLeft = 0.0
    daysLeft     = 0
    expDate      = $null
    expired      = $false
    iat          = $null
    exp          = $null
  }
  if ($null -eq $script:licenseExp) { return $out }
  try {
    $exp = [long]$script:licenseExp
    $iat = if ($null -ne $script:licenseIat) { [long]$script:licenseIat } else { $exp - (86400 * 365) }
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $out.hasExp = $true
    $out.iat = $iat
    $out.exp = $exp
    $out.expDate = [DateTimeOffset]::FromUnixTimeSeconds($exp).ToLocalTime().DateTime
    $span = [double]($exp - $iat)
    if ($span -le 0) { $span = 1.0 }
    $left = [double]($exp - $now)
    $out.daysLeft = [int][Math]::Ceiling($left / 86400.0)
    $out.fractionLeft = [Math]::Max(0.0, [Math]::Min(1.0, $left / $span))
    $out.expired = ($now -gt $exp)
    return $out
  } catch { return $out }
}

function Invoke-CccActivationCli([string[]]$cliArgs) {
  $cli = Join-Path $script:HudScriptRoot 'ccc-activation.mjs'
  if (-not (Test-Path -LiteralPath $cli)) { return $null }
  try {
    # Exit code 1 = activate rejected; stdout still carries JSON status — do not treat as hard fail.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $raw = & node $cli @cliArgs 2>$null
    $ErrorActionPreference = $prevEap
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    $line = (@($raw) | Where-Object { $_ -and "$_".Trim().StartsWith('{') } | Select-Object -Last 1)
    if (-not $line) { return $null }
    return ($line | ConvertFrom-Json)
  } catch { return $null }
}

function Activate-License([string]$token) {
  $g = Invoke-CccActivationCli @('activate', '--token', $token)
  if ($null -eq $g) {
    $script:licenseStatus = 'Aktivierung fehlgeschlagen (CLI)'
    $script:hudStatusText = $script:licenseStatus
    Refresh-HudGate
    return $false
  }
  $script:licenseToken = $token
  Sync-HudLicenseExpiryFromToken $token
  Apply-HudGateFromObject $g
  $script:licenseStatus = if ($g.statusText) { [string]$g.statusText } else { 'Aktivierung' }
  $script:hudStatusText = $script:licenseStatus
  if ([bool]$g.ok -or [bool]$g.activated) {
    Reseal-HudPrefsAfterActivation
    Load-Prefs
    return $true
  }
  # Rejected token still stored for diagnostics; refresh gate from snapshot fields already on $g
  Reseal-HudPrefsAfterActivation
  Load-Prefs
  return $false
}

function Remove-LicenseActivation {
  $g = Invoke-CccActivationCli @('remove')
  if ($null -ne $g) { Apply-HudGateFromObject $g }
  else { Refresh-HudGate }
  $script:licenseToken = ''
  $script:licenseIat = $null
  $script:licenseExp = $null
  $script:licenseStatus = if ($script:hudStatusText) { [string]$script:hudStatusText } else { 'kein Aktivierungsschlüssel' }
  Reseal-HudPrefsAfterActivation
  Load-Prefs
}

function Deactivate-ThisDevice {
  $g = Invoke-CccActivationCli @('deactivate')
  if ($null -ne $g) { Apply-HudGateFromObject $g }
  else { Refresh-HudGate }
  $script:licenseStatus = if ($script:hudStatusText) { [string]$script:hudStatusText } else { 'Gerät deaktiviert' }
  Reseal-HudPrefsAfterActivation
  Load-Prefs
}

# Back-compat alias used by older settings handlers
function Save-License([string]$token) {
  Activate-License $token
}

function Test-HudFeature([string]$featureId) {
  if ($null -eq $script:hudLimits) {
    # Free-tier matrix fallback (parity with hudFeatureLimits.mjs none)
    return @(
      'hud.core', 'hud.drag', 'hud.settings.basic', 'hud.marker.emoji',
      'hud.chrome.cloud'
    ) -contains $featureId
  }
  try {
    $v = $script:hudLimits.$featureId
    if ($null -eq $v) { return $false }
    if ($v -is [bool]) { return [bool]$v }
    # Numeric limit keys are not boolean features
    return $false
  } catch { return $false }
}

function Get-HudNumericLimit([string]$limitKey) {
  $defaults = @{
    maxFreeEmojis = 10
    maxCustomLogos = 0
    maxSavedPrefsProfiles = 0
    maxArchiveRecent = 0
    maxArchiveSearchHits = 0
  }
  if ($null -eq $script:hudLimits) {
    if ($defaults.ContainsKey($limitKey)) { return [int]$defaults[$limitKey] }
    return 0
  }
  try {
    $v = $script:hudLimits.$limitKey
    if ($null -eq $v) {
      if ($defaults.ContainsKey($limitKey)) { return [int]$defaults[$limitKey] }
      return 0
    }
    return [int]$v
  } catch {
    if ($defaults.ContainsKey($limitKey)) { return [int]$defaults[$limitKey] }
    return 0
  }
}

function Test-HudNumericCap([string]$limitKey, [int]$currentCount, [switch]$ReplacingExisting) {
  $max = Get-HudNumericLimit $limitKey
  if ($ReplacingExisting) { return ($currentCount -le $max) }
  return ($currentCount -lt $max)
}

function Show-HudCapHint([string]$label, [string]$limitKey, [int]$currentCount) {
  $max = Get-HudNumericLimit $limitKey
  $msg = "Limit erreicht: $label`r`nAktuell: $currentCount / max $max (Stufe: $script:hudTier)`r`n`r`n$script:hudUpgradeHint`r`nKauf: $script:hudUpgradeUrl"
  try {
    [System.Windows.Forms.MessageBox]::Show(
      $msg,
      'CCC Limit',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
  } catch { }
}

function Show-ProUpgradeHint([string]$featureLabel) {
  $msg = "Pro-Feature: $featureLabel`r`n`r`n$script:hudUpgradeHint`r`n`r`nAktivierung: Einstellungen → Aktivierung`r`nKauf: $script:hudUpgradeUrl"
  try {
    [System.Windows.Forms.MessageBox]::Show(
      $msg,
      'CCC Pro',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
  } catch { }
}

function Get-HudAutostartLinkPath {
  return (Join-Path ([Environment]::GetFolderPath('Startup')) 'AI Keep Clean CCC HUD.lnk')
}

function Remove-HudAutostartLink {
  foreach ($name in @('AI Keep Clean CCC HUD.lnk', 'CCC Project HUD.lnk')) {
    $lnk = Join-Path ([Environment]::GetFolderPath('Startup')) $name
    if (Test-Path -LiteralPath $lnk) {
      try { Remove-Item -LiteralPath $lnk -Force } catch { }
    }
  }
}

function Set-HudAutostartLink {
  $candidates = @(
    (Join-Path $script:HudScriptRoot 'hud-start.mjs'),
    (Join-Path (Split-Path $script:HudScriptRoot) 'hud-start.mjs')
  )
  $hudStart = $null
  foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { $hudStart = $c; break }
  }
  if (-not $hudStart) { return }
  $node = $null
  try { $node = (Get-Command node -ErrorAction Stop).Source } catch { return }
  # Working dir: plugin root (vendor/hud → ../..) or repo root (scripts/hud → ../..)
  $workDir = Split-Path (Split-Path $script:HudScriptRoot)
  if ((Split-Path $hudStart -Leaf) -eq 'hud-start.mjs' -and (Test-Path -LiteralPath (Join-Path $script:HudScriptRoot 'hud-start.mjs'))) {
    # vendored under vendor/hud — plugin root is two levels up from hud
    $workDir = Split-Path (Split-Path $script:HudScriptRoot)
  }
  try {
    # Drop legacy shortcut name if present
    $legacy = Join-Path ([Environment]::GetFolderPath('Startup')) 'CCC Project HUD.lnk'
    if (Test-Path -LiteralPath $legacy) {
      try { Remove-Item -LiteralPath $legacy -Force } catch { }
    }
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut((Get-HudAutostartLinkPath))
    $sc.TargetPath = $node
    $sc.Arguments = "`"$hudStart`""
    $sc.WorkingDirectory = $workDir
    $sc.WindowStyle = 7
    $sc.Description = 'AI Keep Clean Context Control Center — Project HUD'
    $sc.Save()
  } catch { }
}

function Apply-HudAutostart {
  if (-not (Test-HudFeature 'hud.autostart')) {
    $script:prefs.autostart = $false
    Remove-HudAutostartLink
    return
  }
  if ([bool]$script:prefs.autostart) {
    Set-HudAutostartLink
  } else {
    Remove-HudAutostartLink
  }
}

function Get-DisplayMarkerMode {
  # Runtime display only — never mutate stored prefs (Free↔Pro must keep settings).
  $mode = [string]$script:prefs.markerMode
  if ($mode -eq 'pattern' -and -not (Test-HudFeature 'hud.marker.pattern')) { return 'emoji' }
  if ($mode -eq 'image' -and -not (Test-HudFeature 'hud.marker.image')) { return 'emoji' }
  return $mode
}

function Enforce-FreeMarkerPrefs {
  # Kept for call sites; no longer writes over Pro prefs on disk.
}
