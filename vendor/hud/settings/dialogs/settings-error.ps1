# Copyright (c) 2026 ready-4-it
# Central HUD settings-failure dialog + log (version · Agent|IDE · derivative).

function Write-HudSettingsErrorLog {
  param(
    [string]$Message,
    $ErrorRecord = $null,
    $Identity = $null
  )
  if ($null -eq $Identity) {
    $Identity = if (Get-Command Get-HudRuntimeIdentity -ErrorAction SilentlyContinue) {
      Get-HudRuntimeIdentity
    } else { $null }
  }
  try {
    $logPath = Join-Path $env:USERPROFILE '.cursor\ccc-hud-settings-error.log'
    $pos = ''
    $stack = ''
    if ($ErrorRecord) {
      if ($ErrorRecord.InvocationInfo) { $pos = [string]$ErrorRecord.InvocationInfo.PositionMessage }
      $stack = [string]$ErrorRecord.ScriptStackTrace
    }
    $block = @(
      "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')]"
      "Message: $Message"
      "Footer: $(if ($Identity) { $Identity.Footer } else { '—' })"
      "Version: $(if ($Identity) { $Identity.Version } else { '—' })"
      "Surface: $(if ($Identity) { $Identity.Surface } else { '—' })"
      "Channel: $(if ($Identity) { $Identity.Channel } else { '—' })"
      "Derivative: $(if ($Identity) { $Identity.Derivative } else { '—' })"
      "Tier: $(if ($script:hudTier) { [string]$script:hudTier } else { 'none' })"
      "HasActivationCli: $(if ($null -ne $script:hasActivationCli) { [bool]$script:hasActivationCli } else { 'unset' })"
      "HudScript: $PSScriptRoot"
      "Position: $pos"
      "Stack: $stack"
      ''
    ) -join "`n"
    Add-Content -LiteralPath $logPath -Value $block -Encoding utf8
  } catch { }
}

function Show-HudSettingsFailed {
  param(
    [Parameter(Mandatory)]$ErrorRecord
  )
  $msg = ''
  try { $msg = [string]$ErrorRecord.Exception.Message } catch { }
  if ([string]::IsNullOrWhiteSpace($msg)) { $msg = [string]$ErrorRecord }
  $id = $null
  if (Get-Command Get-HudRuntimeIdentity -ErrorAction SilentlyContinue) {
    try { $id = Get-HudRuntimeIdentity } catch { }
  }
  Write-HudSettingsErrorLog -Message $msg -ErrorRecord $ErrorRecord -Identity $id
  $footer = if ($id -and $id.Footer) { [string]$id.Footer } else { '0.0.0 · ? · Unknown' }
  # Stock MessageBox has no status bar — keep identity in the body as well.
  $text = "CCC HUD settings failed:`n$msg`n`n$footer"
  try {
    if (Get-Command Show-HudMessageBox -ErrorAction SilentlyContinue) {
      [void](Show-HudMessageBox -Text $text -Caption 'AI Keep Clean CCC' -Footer $footer -Icon Warning)
      return
    }
  } catch { }
  try {
    [void][System.Windows.Forms.MessageBox]::Show(
      $text,
      'AI Keep Clean CCC',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Warning
    )
  } catch { }
}
