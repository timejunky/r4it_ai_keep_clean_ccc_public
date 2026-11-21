# Copyright (c) 2026 ready-4-it
# About update button (async Zebra check).

  $hudRoot = if ($script:HudScriptRoot) { [string]$script:HudScriptRoot } else { Split-Path $PSScriptRoot -Parent }

  $btnAboutUpdate.Add_Click({
    try {
      if ($script:HudAsyncNodeProc -and $script:HudAsyncNodeProc.Proc -and -not $script:HudAsyncNodeProc.Proc.HasExited) { return }
      $licensedZebra = (Get-Command Test-HudUsesLicensedZebra -ErrorAction SilentlyContinue) -and (Test-HudUsesLicensedZebra)
      $zebraCli = Join-Path $hudRoot 'ccc-zebra-update-check.mjs'
      $zebraApplyCli = Join-Path $hudRoot 'ccc-zebra-apply-update.mjs'
      $publicCli = Join-Path $hudRoot 'ccc-public-update-check.mjs'
      $publicApplyCli = Join-Path $hudRoot 'ccc-public-apply-update.mjs'
      $useLicensedZebra = $licensedZebra -and (Test-Path -LiteralPath $zebraCli)

      if ($useLicensedZebra -and (Get-Command Test-HudNeedsZebraUpdateConsent -ErrorAction SilentlyContinue) -and (Test-HudNeedsZebraUpdateConsent)) {
        if (Get-Command Mark-HudZebraNetworkConsentPrompted -ErrorAction SilentlyContinue) {
          Mark-HudZebraNetworkConsentPrompted
        }
        if (-not (Show-HudZebraNetworkConsentDialog -Owner $dlg)) { return }
        if (Get-Command Grant-HudZebraNetworkConsent -ErrorAction SilentlyContinue) {
          Grant-HudZebraNetworkConsent
        }
        & node $zebraCli --grant-consent 2>$null | Out-Null
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
      if ($useLicensedZebra) {
        $pingCli = Join-Path $hudRoot 'ccc-zebra-usage-ping.mjs'
        if (Test-Path -LiteralPath $pingCli) {
          & node $pingCli @hostArgs 2>$null | Out-Null
        }
      }

      $pluginRoot = Join-Path $env:USERPROFILE '.cursor\plugins\local\ai-keep-clean-ccc'
      try {
        $candRoot = (Resolve-Path -LiteralPath (Join-Path $hudRoot '..\..') -ErrorAction Stop).Path
        if ((Test-Path -LiteralPath (Join-Path $candRoot '.cursor-plugin\plugin.json')) -or (Test-Path -LiteralPath (Join-Path $candRoot 'plugin.json'))) {
          $pluginRoot = $candRoot
        }
      } catch { }

      if (-not $useLicensedZebra) {
        if (-not (Test-Path -LiteralPath $publicCli)) {
          Show-HudMessageBox (Get-HudT 'about.update.freePingOk') -Icon Information | Out-Null
          return
        }
        $pubCheckArgs = @('--plugin-root', $pluginRoot)
        $updCtx = @{
          applyCli      = $publicApplyCli
          checkArgs     = $pubCheckArgs
          useDevZebra   = $false
          busyBtn       = $btnAboutUpdate
          pluginRoot    = $pluginRoot
          hudScriptRoot = $hudRoot
        }
        $started = Start-HudAsyncNodeCli -Cli $publicCli -NodeArgs $pubCheckArgs -BusyControl $btnAboutUpdate -BusyText (Get-HudT 'about.update.checking') -OnComplete {
          param($raw, $err)
          Show-HudAboutUpdateCheckResult -Raw $raw -Err $err -Ctx $updCtx
        }
        if (-not $started) {
          Show-HudMessageBox (Get-HudT 'about.update.checkFail') -Icon Warning | Out-Null
        }
        return
      }

      $zebraArgs = @($hostArgs)
      $devMarker = Join-Path $env:USERPROFILE '.ccc\zebra-dev'
      $useDevZebra = ($env:CCC_ZEBRA_DEV -eq '1') -or (Test-Path -LiteralPath $devMarker)
      if ($useDevZebra) { $zebraArgs += '--dev' }
      $checkArgs = @($zebraArgs)
      $updCtx = @{
        applyCli      = $zebraApplyCli
        checkArgs     = $checkArgs
        useDevZebra   = $useDevZebra
        busyBtn       = $btnAboutUpdate
        pluginRoot    = $pluginRoot
        hudScriptRoot = $hudRoot
      }
      $started = Start-HudAsyncNodeCli -Cli $zebraCli -NodeArgs $checkArgs -BusyControl $btnAboutUpdate -BusyText (Get-HudT 'about.update.checking') -OnComplete {
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
