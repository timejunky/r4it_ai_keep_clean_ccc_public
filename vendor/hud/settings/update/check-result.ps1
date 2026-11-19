# Copyright (c) 2026 ready-4-it
# Zebra update check result handling.

function Show-HudAboutUpdateCheckResult {
  param(
    $Raw,
    $Err,
    [hashtable]$Ctx
  )
  if ($Err) {
    $em = if ($Err -is [System.Exception]) { $Err.Message } else { [string]$Err }
    Show-HudMessageBox (Get-HudT 'about.update.installFail' -Vars @{ error = $em }) -Icon Error | Out-Null
    return
  }
  if ([string]::IsNullOrWhiteSpace([string]$Raw)) {
    Show-HudMessageBox (Get-HudT 'about.update.noReply') -Icon Warning | Out-Null
    return
  }
  try { $j = $Raw | ConvertFrom-Json } catch {
    Show-HudMessageBox (Get-HudT 'about.update.checkFail') -Icon Warning | Out-Null
    return
  }
  if (-not $j.ok) {
    $msg = if ($j.hintKey) { Get-HudT ([string]$j.hintKey) } elseif ($j.message) { [string]$j.message } else { (Get-HudT 'about.update.checkFail') }
    if ([string]$j.error -eq 'zebra_consent_required') { $msg = Get-HudT 'about.update.consent.required' }
    if ([string]$j.error -eq 'invalid_license' -and -not $j.hintKey) { $msg = Get-HudT 'about.update.zebraTokenUnknown' }
    if ([string]$j.error -eq 'wrong_field' -or [string]$j.message -match 'activation_key|Zebra runtime field|wrong_field') {
      $msg = Get-HudT 'about.update.zebraWrongField'
    }
    if ([string]$j.error -eq 'wrong_credential' -or [string]$j.message -match 'payhip_license_key|wrong_credential') {
      $msg = Get-HudT 'about.update.zebraWrongCredential'
    }
    if ([string]$j.error -eq 'release_unavailable') { $msg = Get-HudT 'about.update.releaseUnavailable' }
    if ($Ctx.useDevZebra) { $msg = $msg + "`n`n" + (Get-HudT 'about.update.devHint') }
    Show-HudMessageBox $msg -Icon Information | Out-Null
    return
  }
  if (-not ($j.updateAvailable -and $j.downloadUrl)) {
    $cur = if ($j.currentVersion) { [string]$j.currentVersion } else { '?' }
    Show-HudMessageBox (Get-HudT 'about.update.upToDate' -Vars @{ version = $cur }) -Icon Information | Out-Null
    return
  }
  $latest = [string]$j.latestVersion
  $confirmKey = if ([string]$j.source -eq 'github-public' -or [string]$j.source -eq 'public') {
    'about.update.installConfirmFree'
  } else {
    'about.update.installConfirm'
  }
  $ans = Show-HudMessageBox (Get-HudT $confirmKey -Vars @{ version = $latest }) -Buttons YesNo -Icon Question
  if ($ans -ne 'Yes') { return }
  if (-not (Test-Path -LiteralPath $Ctx.applyCli)) {
    Show-HudMessageBox (Get-HudT 'about.update.missingApply') -Icon Warning | Out-Null
    return
  }
  $applyArgs = @('--url', ([string]$j.downloadUrl))
  if ($latest) { $applyArgs += @('--version', $latest) }
  $updateSource = [string]$j.source
  if ($updateSource -eq 'github-public' -or $updateSource -eq 'public') { $applyArgs += @('--source', 'github-public') }
  if ($Ctx.useDevZebra) { $applyArgs += '--dev' }
  if ($Ctx.checkArgs -contains '--host') {
    $hi = [array]::IndexOf($Ctx.checkArgs, '--host')
    if ($hi -ge 0 -and ($hi + 1) -lt $Ctx.checkArgs.Count) {
      $applyArgs += @('--host', [string]$Ctx.checkArgs[$hi + 1])
    }
  }
  $applyCtx = @{
    applyCli      = $Ctx.applyCli
    applyVersion  = $latest
    pluginRoot    = $Ctx.pluginRoot
    hudScriptRoot = $Ctx.hudScriptRoot
  }
  Start-HudAsyncNodeCli -Cli $Ctx.applyCli -NodeArgs $applyArgs -BusyControl $Ctx.busyBtn -BusyText (Get-HudT 'about.update.checking') -OnComplete {
    param($applyRaw, $applyErr)
    Show-HudAboutUpdateApplyResult -Raw $applyRaw -Err $applyErr -Ctx $applyCtx
  } | Out-Null
}
