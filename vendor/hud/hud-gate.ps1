# Copyright (c) 2026 ready-4-it
# License gate snapshot — shared by pill + settings (settings reload must not depend on pill boot scope).

function Apply-HudGateFromObject($g) {
  if ($null -eq $g) { return }
  if ($g.tier) { $script:hudTier = [string]$g.tier }
  if ($g.reason) { $script:hudGateReason = [string]$g.reason }
  if ($g.statusText) { $script:hudStatusText = [string]$g.statusText }
  if ($g.limits) { $script:hudLimits = $g.limits }
  if ($g.upgradeUrl) { $script:hudUpgradeUrl = [string]$g.upgradeUrl }
  if ($g.upgradeHint) { $script:hudUpgradeHint = [string]$g.upgradeHint }
  if ($g.activationUrl) { $script:activationUrl = [string]$g.activationUrl }
  if ($g.deviceHashShort) { $script:deviceHashShort = [string]$g.deviceHashShort }
  if ($null -ne $g.isActivatedOnThisDevice) {
    $script:isActivatedOnThisDevice = [bool]$g.isActivatedOnThisDevice
  }
}

function Refresh-HudGate {
  $script:hudTier = 'none'
  $script:hudGateReason = 'missing-token'
  $script:hudStatusText = 'kein Aktivierungsschlüssel'
  $script:hudLimits = $null
  $script:hudUpgradeUrl = 'https://www.ready-4-it.com/akc_ccc'
  $script:hudUpgradeHint = 'CCC Pro: Kauf → Pro-Paket downloaden/installieren → Website (Lizenzschlüssel) → hier Aktivierungsschlüssel — ready-4-it.com/akc_ccc'
  $script:activationUrl = 'https://www.ready-4-it.com/de/license/activate#p=ccc'
  $script:deviceHashShort = ''
  $script:isActivatedOnThisDevice = $false
  $assess = Join-Path $PSScriptRoot 'assess-hud-tier.mjs'
  if (-not (Test-Path -LiteralPath $assess)) { return }
  try {
    $raw = & node $assess 2>$null
    if ([string]::IsNullOrWhiteSpace($raw)) { return }
    $g = $raw | ConvertFrom-Json
    Apply-HudGateFromObject $g
  } catch { }
}
