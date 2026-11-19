# Copyright (c) 2026 ready-4-it
# Zebra update apply + HUD restart.

function Show-HudAboutUpdateApplyResult {
  param($Raw, $Err, [hashtable]$Ctx)
  if ($Err) {
    $em = if ($Err -is [System.Exception]) { $Err.Message } else { [string]$Err }
    Show-HudMessageBox (Get-HudT 'about.update.installFail' -Vars @{ error = $em }) -Icon Error | Out-Null
    return
  }
  if ([string]::IsNullOrWhiteSpace([string]$Raw)) {
    Show-HudMessageBox (Get-HudT 'about.update.installFail' -Vars @{ error = 'no reply' }) -Icon Error | Out-Null
    return
  }
  try { $aj = $Raw | ConvertFrom-Json } catch {
    Show-HudMessageBox (Get-HudT 'about.update.installFail' -Vars @{ error = 'invalid reply' }) -Icon Error | Out-Null
    return
  }
  if (-not $aj.ok) {
    $em = if ($aj.message) { [string]$aj.message } else { 'install failed' }
    Show-HudMessageBox (Get-HudT 'about.update.installFail' -Vars @{ error = $em }) -Icon Error | Out-Null
    return
  }
  if (-not $aj.applied) {
    $cur = if ($aj.currentVersion) { [string]$aj.currentVersion } else { '?' }
    Show-HudMessageBox (Get-HudT 'about.update.upToDate' -Vars @{ version = $cur }) -Icon Information | Out-Null
    return
  }
  $ver = if ($aj.installedVersion) { [string]$aj.installedVersion } else { [string]$Ctx.applyVersion }
  Show-HudMessageBox (Get-HudT 'about.update.installOk' -Vars @{ version = $ver }) -Icon Information | Out-Null
  if (-not $aj.restartSuggested) { return }
  $restart = Show-HudMessageBox (Get-HudT 'about.update.restartAsk') -Buttons YesNo -Icon Question
  if ($restart -ne 'Yes') { return }
  $pluginRoot = [string]$Ctx.pluginRoot
  $stopCli = Join-Path $pluginRoot 'vendor\hud\hud-stop.mjs'
  $startCli = Join-Path $pluginRoot 'vendor\hud\hud-start.mjs'
  if (-not ((Test-Path -LiteralPath $stopCli) -and (Test-Path -LiteralPath $startCli))) {
    $devHud = Join-Path $Ctx.hudScriptRoot '..\hud-stop.mjs'
    if (Test-Path -LiteralPath $devHud) {
      $stopCli = $devHud
      $startCli = Join-Path $Ctx.hudScriptRoot '..\hud-start.mjs'
      $pluginRoot = (Resolve-Path (Join-Path $Ctx.hudScriptRoot '..\..')).Path
    }
  }
  if (-not ((Test-Path -LiteralPath $stopCli) -and (Test-Path -LiteralPath $startCli))) { return }
  $restartPs1 = Join-Path $env:TEMP 'ccc-hud-restart.ps1'
  $stopEsc = $stopCli.Replace("'", "''")
  $startEsc = $startCli.Replace("'", "''")
  $rootEsc = $pluginRoot.Replace("'", "''")
  @(
    '$ErrorActionPreference = ''Continue'''
    "Set-Location -LiteralPath '$rootEsc'"
    'Start-Sleep -Milliseconds 700'
    "if (Test-Path -LiteralPath '$stopEsc') { & node '$stopEsc' }"
    'Start-Sleep -Milliseconds 900'
    "`$env:CCC_HUD_OPEN_SETTINGS = '1'"
    "if (Test-Path -LiteralPath '$startEsc') { & node '$startEsc' }"
  ) | Set-Content -LiteralPath $restartPs1 -Encoding UTF8
  try {
    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', $restartPs1
    ) -WorkingDirectory $pluginRoot -WindowStyle Hidden | Out-Null
  } catch { }
}
