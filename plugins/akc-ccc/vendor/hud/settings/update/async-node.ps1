# Copyright (c) 2026 ready-4-it
# Async node CLI runner for settings UI.

function Start-HudAsyncNodeCli {
  param(
    [Parameter(Mandatory)][string]$Cli,
    [string[]]$NodeArgs = @(),
    [Parameter(Mandatory)][scriptblock]$OnComplete,
    [System.Windows.Forms.Control]$BusyControl = $null,
    [string]$BusyText = ''
  )
  if ($script:HudAsyncNodeProc -and $script:HudAsyncNodeProc.Proc -and -not $script:HudAsyncNodeProc.Proc.HasExited) {
    return $false
  }
  if ($script:HudAsyncNodeTimer) {
    try { $script:HudAsyncNodeTimer.Stop(); $script:HudAsyncNodeTimer.Dispose() } catch { }
    $script:HudAsyncNodeTimer = $null
  }
  if (-not (Test-Path -LiteralPath $Cli)) { return $false }
  $busyCtl = $BusyControl
  $prevText = $null
  if ($busyCtl) {
    $busyCtl.Enabled = $false
    if (-not [string]::IsNullOrWhiteSpace($BusyText)) {
      $prevText = [string]$busyCtl.Text
      $busyCtl.Text = $BusyText
    }
  }
  $outFile = Join-Path $env:TEMP ("ccc-hud-node-out-{0}.txt" -f [Guid]::NewGuid().ToString('N'))
  $errFile = Join-Path $env:TEMP ("ccc-hud-node-err-{0}.txt" -f [Guid]::NewGuid().ToString('N'))
  try {
    $argList = @([string]$Cli) + @($NodeArgs)
    $proc = Start-Process -FilePath 'node' -ArgumentList $argList -NoNewWindow -PassThru `
      -RedirectStandardOutput $outFile -RedirectStandardError $errFile
  } catch {
    if ($busyCtl) {
      $busyCtl.Enabled = $true
      if ($null -ne $prevText) { $busyCtl.Text = $prevText }
    }
    return $false
  }
  $script:HudAsyncNodeProc = @{
    Proc       = $proc
    OutFile    = $outFile
    ErrFile    = $errFile
    OnComplete = $OnComplete
    BusyCtl    = $busyCtl
    PrevText   = $prevText
    Done       = $false
  }
  $script:HudAsyncNodeTimer = New-Object System.Windows.Forms.Timer
  $script:HudAsyncNodeTimer.Interval = 200
  $script:HudAsyncNodeTimer.Add_Tick({
    $timer = $script:HudAsyncNodeTimer
    if ($null -eq $timer) { return }
    $state = $script:HudAsyncNodeProc
    if (-not $state -or -not $state.Proc) {
      try { $timer.Stop() } catch { }
      return
    }
    if ($state.Done) { return }
    if (-not $state.Proc.HasExited) { return }
    $state.Done = $true
    try { $timer.Stop() } catch { }
    try { $timer.Dispose() } catch { }
    $script:HudAsyncNodeTimer = $null
    try { $state.Proc.WaitForExit(15000) } catch { }
    $raw = ''
    $err = $null
    try {
      if (Test-Path -LiteralPath $state.ErrFile) {
        $stderr = [string](Get-Content -LiteralPath $state.ErrFile -Raw -Encoding UTF8)
        if (-not [string]::IsNullOrWhiteSpace($stderr)) {
          $trim = $stderr.Trim()
          if ($trim.StartsWith('{') -and $trim.EndsWith('}')) { $raw = $trim } else { $err = $trim }
        }
      }
      if (Test-Path -LiteralPath $state.OutFile) {
        $stdout = [string](Get-Content -LiteralPath $state.OutFile -Raw -Encoding UTF8)
        if (-not [string]::IsNullOrWhiteSpace($stdout)) { $raw = $stdout.Trim() }
      }
    } catch {
      $err = $_.Exception.Message
    }
    try { if (Test-Path -LiteralPath $state.OutFile) { Remove-Item -LiteralPath $state.OutFile -Force } } catch { }
    try { if (Test-Path -LiteralPath $state.ErrFile) { Remove-Item -LiteralPath $state.ErrFile -Force } } catch { }
    $bc = $state.BusyCtl
    if ($bc) {
      $bc.Enabled = $true
      if ($null -ne $state.PrevText) { $bc.Text = [string]$state.PrevText }
    }
    $script:HudAsyncNodeProc = $null
    try {
      if ($state.OnComplete) { & $state.OnComplete $raw $err }
    } catch {
      Show-HudMessageBox (Get-HudT 'about.update.installFail' -Vars @{ error = $_.Exception.Message }) -Icon Error | Out-Null
    }
  })
  $script:HudAsyncNodeTimer.Start()
  return $true
}
