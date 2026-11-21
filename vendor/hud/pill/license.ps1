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

function Test-HudUsesLicensedZebra {
  # Public/Free stays on Marketplace and GitHub. Trial and Pro use Zebra.
  return (Test-HudLicenseAccepted)
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

function Format-HudProcessArg([string]$arg) {
  if ($null -eq $arg) { return '""' }
  if ($arg -notmatch '[\s"]') { return $arg }
  return '"' + ($arg.Replace('"', '\"')) + '"'
}

function Invoke-CccActivationCli([string[]]$cliArgs) {
  $cli = Join-Path $script:HudScriptRoot 'ccc-activation.mjs'
  if (-not (Test-Path -LiteralPath $cli)) { return $null }
  $node = $null
  try { $node = (Get-Command node -ErrorAction Stop).Source } catch { return $null }
  try {
    # Exit code 1 = activate rejected; stdout still carries JSON status — do not treat as hard fail.
    # node.exe is a console program. The call operator opens a CMD window from the windowless pill.
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $node
    $parts = New-Object System.Collections.Generic.List[string]
    [void]$parts.Add((Format-HudProcessArg $cli))
    foreach ($a in @($cliArgs)) { [void]$parts.Add((Format-HudProcessArg ([string]$a))) }
    $psi.Arguments = ($parts -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    if ($script:HudScriptRoot) { $psi.WorkingDirectory = [string]$script:HudScriptRoot }
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    if (-not $proc.Start()) { return $null }
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()
    $proc.WaitForExit()
    $raw = $outTask.GetAwaiter().GetResult()
    $null = $errTask.GetAwaiter().GetResult()
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    $line = (@($raw -split '\r?\n') | Where-Object { $_ -and "$_".Trim().StartsWith('{') } | Select-Object -Last 1)
    if (-not $line) { return $null }
    return ($line | ConvertFrom-Json)
  } catch { return $null }
}

function Activate-License([string]$token) {
  $script:lastActivationKeptExisting = $false
  $script:lastActivationMessage = ''
  $g = Invoke-CccActivationCli @('activate', '--token', $token)
  if ($null -eq $g) {
    $script:licenseStatus = 'Aktivierung fehlgeschlagen (CLI)'
    $script:hudStatusText = $script:licenseStatus
    $script:lastActivationMessage = $script:licenseStatus
    Refresh-HudGate
    return $false
  }
  $keptExisting = $false
  try { $keptExisting = [bool]$g.keptExisting } catch { $keptExisting = $false }
  $script:lastActivationKeptExisting = $keptExisting
  if (-not $keptExisting) {
    $script:licenseToken = $token
    Sync-HudLicenseExpiryFromToken $token
  }
  Apply-HudGateFromObject $g
  $rejectMsg = ''
  try { if ($g.rejectStatusText) { $rejectMsg = [string]$g.rejectStatusText } } catch { }
  $script:licenseStatus = if ($g.statusText) { [string]$g.statusText } else { 'Aktivierung' }
  $script:hudStatusText = $script:licenseStatus
  $script:lastActivationMessage = if (-not [string]::IsNullOrWhiteSpace($rejectMsg)) { $rejectMsg } else { $script:licenseStatus }
  if ([bool]$g.ok -or [bool]$g.activated) {
    Reseal-HudPrefsAfterActivation
    Load-Prefs
    return $true
  }
  if (-not $keptExisting) {
    # Rejected token stored for diagnostics only when no active license existed; keep active license untouched otherwise.
    Reseal-HudPrefsAfterActivation
    Load-Prefs
  }
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

function Get-HudGateI18n([string]$key, [string]$fallbackDe, [string]$fallbackEn, [hashtable]$vars = @{}) {
  if (Get-Command Get-HudT -ErrorAction SilentlyContinue) {
    try {
      $val = Get-HudT $key -Vars $vars
      if (-not [string]::IsNullOrWhiteSpace($val) -and $val -ne $key) { return [string]$val }
    } catch { }
  }
  $lang = 'en'
  if (Get-Command Get-HudLang -ErrorAction SilentlyContinue) {
    try { $lang = [string](Get-HudLang) } catch { }
  }
  $tpl = if ($lang -like 'de*') { $fallbackDe } else { $fallbackEn }
  foreach ($k in $vars.Keys) {
    $tpl = $tpl.Replace("{$k}", [string]$vars[$k])
  }
  return $tpl
}

function Test-HudCanOpenActivationTab {
  if ($null -ne $script:hasActivationCli) { return [bool]$script:hasActivationCli }
  if ($script:HudScriptRoot) {
    return (Test-Path -LiteralPath (Join-Path $script:HudScriptRoot 'ccc-activation.mjs'))
  }
  return $false
}

function Open-HudActivationTab {
  if (-not (Test-HudCanOpenActivationTab)) { return }
  if ($script:settingsOpen -and $script:ShowHudSettingsPage) {
    try {
      & $script:ShowHudSettingsPage 'lizenz'
      if ($script:FocusHudActivationToken) { & $script:FocusHudActivationToken }
    } catch { }
    return
  }
  if (Get-Command Open-SettingsPanel -ErrorAction SilentlyContinue) {
    try { Open-SettingsPanel -StartPage 'lizenz' } catch { }
    return
  }
  if (Get-Command Show-SettingsPanel -ErrorAction SilentlyContinue) {
    try { Show-SettingsPanel -StartPage 'lizenz' } catch { }
  }
}

function Show-HudGateDialog([string]$text, [string]$caption, [switch]$AskOpenActivation) {
  $buttons = if ($AskOpenActivation) {
    [System.Windows.Forms.MessageBoxButtons]::YesNo
  } else {
    [System.Windows.Forms.MessageBoxButtons]::OK
  }
  $ans = 'OK'
  try {
    if (Get-Command Show-HudMessageBox -ErrorAction SilentlyContinue) {
      $ans = [string](Show-HudMessageBox -Text $text -Caption $caption -Buttons $buttons -Icon ([System.Windows.Forms.MessageBoxIcon]::Information))
    } else {
      $ans = [string]([System.Windows.Forms.MessageBox]::Show(
        $text,
        $caption,
        $buttons,
        [System.Windows.Forms.MessageBoxIcon]::Information
      ))
    }
  } catch { }
  if ($AskOpenActivation -and $ans -eq 'Yes') {
    Open-HudActivationTab
  }
}

function Test-HudStoredLicenseInvalid {
  $tier = if ($script:hudTier) { [string]$script:hudTier } else { 'none' }
  if ($tier -eq 'trial' -or $tier -eq 'full') { return $false }
  return -not [string]::IsNullOrWhiteSpace([string]$script:licenseToken)
}

function Show-InvalidLicenseBlocker {
  $title = Get-HudGateI18n 'pro.gate.invalidTitle' 'Ungültige Lizenz' 'Invalid license'
  $text = Get-HudGateI18n 'pro.gate.invalidBody' 'Ungültige Lizenz. Bitte die Lizenz korrigieren oder Public installieren.' 'Invalid license. Correct the license, or install Public.'
  Show-HudGateDialog -Text $text -Caption $title
  Open-HudActivationTab
}

function Show-HudCapHint([string]$label, [string]$limitKey, [int]$currentCount) {
  if (Test-HudStoredLicenseInvalid) {
    Show-InvalidLicenseBlocker
    return
  }
  $max = Get-HudNumericLimit $limitKey
  $url = if ($script:hudUpgradeUrl) { [string]$script:hudUpgradeUrl } else { 'https://www.ready-4-it.com/akc_ccc' }
  $tier = if ($script:hudTier) { [string]$script:hudTier } else { 'none' }
  $title = Get-HudGateI18n 'pro.limit.title' 'CCC Limit' 'CCC Limit'
  $lines = [System.Collections.Generic.List[string]]::new()
  $lines.Add((Get-HudGateI18n 'pro.limit.body' 'Limit erreicht: {label} ({current} / max {max}, Stufe: {tier})' 'Limit reached: {label} ({current} / max {max}, tier: {tier})' @{
    label = $label; current = $currentCount; max = $max; tier = $tier
  }))
  $canAct = (Test-HudCanOpenActivationTab) -and ($tier -eq 'none')
  if ($canAct) {
    if (-not [string]::IsNullOrWhiteSpace([string]$script:licenseStatus)) {
      $lines.Add((Get-HudGateI18n 'pro.gate.status' 'Aktueller Status: {status}' 'Current status: {status}' @{ status = [string]$script:licenseStatus }))
    }
    $lines.Add('')
    $lines.Add((Get-HudGateI18n 'pro.gate.openPrompt' 'Jetzt zur Aktivierung wechseln, um den Aktivierungsschlüssel (R4IT…) einzugeben oder zu korrigieren?' 'Open Activation now to enter or correct your activation key (R4IT…)?'))
  } else {
    $lines.Add('')
    $lines.Add((Get-HudGateI18n 'pro.gate.freeBody' 'Pro-Funktion — verfügbar in AKC CCC Pro.' 'Pro feature — available in AKC CCC Pro.'))
  }
  $lines.Add((Get-HudGateI18n 'pro.gate.buy' 'Kauf / Download: {url}' 'Purchase / Download: {url}' @{ url = $url }))
  Show-HudGateDialog -Text ($lines -join "`r`n") -Caption $title -AskOpenActivation:$canAct
}

function Show-ProUpgradeHint([string]$featureLabel) {
  if (Test-HudStoredLicenseInvalid) {
    Show-InvalidLicenseBlocker
    return
  }
  $url = if ($script:hudUpgradeUrl) { [string]$script:hudUpgradeUrl } else { 'https://www.ready-4-it.com/akc_ccc' }
  $title = Get-HudGateI18n 'pro.gate.title' 'AKC CCC Pro' 'AKC CCC Pro'
  $canAct = Test-HudCanOpenActivationTab
  $lines = [System.Collections.Generic.List[string]]::new()
  $lines.Add((Get-HudGateI18n 'pro.gate.feature' 'Pro-Feature: {feature}' 'Pro feature: {feature}' @{ feature = $featureLabel }))
  if ($canAct) {
    $statusVal = if (-not [string]::IsNullOrWhiteSpace([string]$script:hudStatusText)) { [string]$script:hudStatusText } else { [string]$script:licenseStatus }
    if (-not [string]::IsNullOrWhiteSpace($statusVal)) {
      $lines.Add((Get-HudGateI18n 'pro.gate.status' 'Aktueller Status: {status}' 'Current status: {status}' @{ status = $statusVal }))
    }
    $lines.Add('')
    $lines.Add((Get-HudGateI18n 'pro.gate.openPrompt' 'Jetzt zur Aktivierung wechseln, um den Aktivierungsschlüssel (R4IT…) einzugeben oder zu korrigieren?' 'Open Activation now to enter or correct your activation key (R4IT…)?'))
  } else {
    $lines.Add('')
    $lines.Add((Get-HudGateI18n 'pro.gate.freeBody' 'Diese Funktion ist in AKC CCC Pro enthalten.' 'This feature is included in AKC CCC Pro.'))
  }
  $lines.Add((Get-HudGateI18n 'pro.gate.buy' 'Kauf / Download: {url}' 'Purchase / Download: {url}' @{ url = $url }))
  Show-HudGateDialog -Text ($lines -join "`r`n") -Caption $title -AskOpenActivation:$canAct
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
