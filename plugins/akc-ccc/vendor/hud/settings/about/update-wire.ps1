# Copyright (c) 2026 ready-4-it
# About update button (async Zebra check).

  $hudRoot = if ($script:HudScriptRoot) { [string]$script:HudScriptRoot } else { Split-Path $PSScriptRoot -Parent }

  $btnAboutUpdate.Add_Click({
    try {
      if ($script:HudAsyncNodeProc -and $script:HudAsyncNodeProc.Proc -and -not $script:HudAsyncNodeProc.Proc.HasExited) { return }
      if ((Get-Command Test-HudNeedsZebraUpdateConsent -ErrorAction SilentlyContinue) -and (Test-HudNeedsZebraUpdateConsent)) {
        if (Get-Command Mark-HudZebraNetworkConsentPrompted -ErrorAction SilentlyContinue) {
          Mark-HudZebraNetworkConsentPrompted
        }
        if (-not (Show-HudZebraNetworkConsentDialog -Owner $dlg)) { return }
        if (Get-Command Grant-HudZebraNetworkConsent -ErrorAction SilentlyContinue) {
          Grant-HudZebraNetworkConsent
        }
        $grantCli = Join-Path $hudRoot 'ccc-zebra-update-check.mjs'
        if (Test-Path -LiteralPath $grantCli) {
          & node $grantCli --grant-consent 2>$null | Out-Null
        }
        if ($ui.chkZebraConsent) {
          $ui.syncing = $true
          try { $ui.chkZebraConsent.Checked = $true } finally { $ui.syncing = $false }
        }
      }
      $focusHostPath = Join-Path $env:USERPROFILE '.cursor\ccc-hud-focus-host.json'
      $hostArgs = @()
      if (Test-Path -LiteralPath $focusHostPath) {
        try {
          $fh = Get-Content -LiteralPath $focusHostPath -Raw -ErrorAction Stop | ConvertFrom-Json
          if ($fh.host) { $hostArgs += @('--host', [string]$fh.host) }
        } catch { }
      }
      $pingCli = Join-Path $hudRoot 'ccc-zebra-usage-ping.mjs'
      if (Test-Path -LiteralPath $pingCli) {
        & node $pingCli @hostArgs 2>$null | Out-Null
      }
      $licensedZebra = (Get-Command Test-HudUsesLicensedZebra -ErrorAction SilentlyContinue) -and (Test-HudUsesLicensedZebra)
      $cli = Join-Path $hudRoot 'ccc-zebra-update-check.mjs'
      $applyCli = Join-Path $hudRoot 'ccc-zebra-apply-update.mjs'
      if (-not $licensedZebra -or -not (Test-Path -LiteralPath $cli)) {
        Show-HudMessageBox (Get-HudT 'about.update.freePingOk') -Icon Information | Out-Null
        return
      }
      $zebraArgs = @($hostArgs)
      $devMarker = Join-Path $env:USERPROFILE '.ccc\zebra-dev'
      $useDevZebra = ($env:CCC_ZEBRA_DEV -eq '1') -or (Test-Path -LiteralPath $devMarker)
      if ($useDevZebra) { $zebraArgs += '--dev' }
      $checkArgs = @($zebraArgs)
      $pluginRoot = Join-Path $env:USERPROFILE '.cursor\plugins\local\ai-keep-clean-ccc'
      $updCtx = @{
        applyCli      = $applyCli
        checkArgs     = $checkArgs
        useDevZebra   = $useDevZebra
        busyBtn       = $btnAboutUpdate
        pluginRoot    = $pluginRoot
        hudScriptRoot = $hudRoot
      }
      $started = Start-HudAsyncNodeCli -Cli $cli -NodeArgs $checkArgs -BusyControl $btnAboutUpdate -BusyText (Get-HudT 'about.update.checking') -OnComplete {
        param($raw, $err)
        Show-HudAboutUpdateCheckResult -Raw $raw -Err $err -Ctx $updCtx
      }
      if (-not $started) {
        Show-HudMessageBox (Get-HudT 'about.update.checkFail') -Icon Warning | Out-Null
      }
    } catch {
      Show-HudMessageBox (Get-HudT 'about.update.installFail' -Vars @{ error = $_.Exception.Message }) -Icon Error | Out-Null
    }
  })
