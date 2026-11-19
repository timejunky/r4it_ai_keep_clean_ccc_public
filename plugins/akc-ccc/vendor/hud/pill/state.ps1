# Copyright (c) 2026 ready-4-it
# AI Keep Clean CCC — Pill state reader: Apply-StateFile.
# Job: read the JSON state file and update form label/width from it.
# Caller: winforms-pill.ps1 (dot-sourced after form controls, statePath, and Refresh-PillWidth exist).
# --- Apply-StateFile helpers ---

function Get-StateHomeCoreResult($state, [string]$core) {
  if ($core -match '(.+?)\s+·\s+branch:') { $core = $matches[1] }
  $homeId = ''; $homePath = ''
  try { $homeId   = [string]$state.workspaceId   } catch { }
  try { $homePath = [string]$state.workspacePath  } catch { }
  $homeHit = $false
  foreach ($hs in @($core, $homeId, $homePath, [string]$state.label)) {
    if ([string]::IsNullOrWhiteSpace($hs)) { continue }
    if ($hs -match '^(?i)home$' -or $hs -match '(?i)empty-window' -or $hs -match '^\d{10,}$') { $homeHit = $true; break }
  }
  if (-not $homeHit) { return @{ core = $core; tip = '' } }
  $homeText = 'Home is Cursor''s scratchbook: a chat with no project.'
  if (Get-Command Get-HudT -ErrorAction SilentlyContinue) {
    $tHome = Get-HudT 'pill.home'
    if ($tHome -and $tHome -ne 'pill.home') { $homeText = $tHome }
  }
  return @{ core = 'Home'; tip = $homeText }
}

function Read-StateGitCloudInfo($state) {
  $emoji     = if ($state.emoji)     { [string]$state.emoji     } else { '⬜' }
  $gitBranch = if ($state.gitBranch) { [string]$state.gitBranch } else { '' }
  $gitTree   = if ($state.gitTree)   { [string]$state.gitTree   } else { '' }
  $cloud = $false; try { $cloud = [bool]$state.cloud } catch { }
  return @{ emoji = $emoji; gitBranch = $gitBranch; gitTree = $gitTree; cloud = $cloud }
}

function Test-StateDataChanged([string]$stamp,[string]$core,[string]$gitBranch,[string]$gitTree,[bool]$cloud) {
  return ($stamp -ne $script:lastStamp -or $core -ne $script:lastLabelCore -or $gitBranch -ne $script:lastGitBranch -or $gitTree -ne $script:lastGitTree -or $cloud -ne $script:lastCloud)
}

function Get-StateBaseText([string]$modeNow,[string]$emoji,[string]$core) {
  if ($modeNow -eq 'emoji' -or $modeNow -eq 'pattern' -or $modeNow -eq 'image') { return $core }
  if ([bool]$script:prefs.showWorkspaceEmoji) { return "$emoji $core" }
  return $core
}

function Get-StatePreferDe {
  $lang = ''
  try { if ($script:prefs -and $script:prefs.uiLanguage) { $lang = [string]$script:prefs.uiLanguage } } catch { }
  return ($lang -eq 'de' -or $lang -like 'de-*')
}

function Apply-StateAccentColor($state) {
  if (-not $state.accent) { return }
  $ac = Parse-HexColor ([string]$state.accent)
  if ($null -ne $ac) { $script:accentColor = $ac }
}

function Apply-StateWorkspaceId($state) {
  if ($state.workspaceUrl) { $script:workspaceUrl = [string]$state.workspaceUrl } else { $script:workspaceUrl = '' }
  if ($state.workspacePath) { $script:workspacePath = [string]$state.workspacePath } else { $script:workspacePath = '' }
  $wsId = if ($state.workspaceId) { [string]$state.workspaceId } else { '' }
  if ($wsId -ne $script:currentWorkspaceId) { Apply-WorkspacePrefs $wsId; $script:forceVisual = $true }
}

function Resolve-StateStatusMsg($state, [bool]$preferDe, [bool]$quiet) {
  if ($quiet) {
    $m = if ($preferDe) {
      if ($state.identityQuietMessageDe) { [string]$state.identityQuietMessageDe } else { [string]$state.identityQuietMessage }
    } else {
      if ($state.identityQuietMessage) { [string]$state.identityQuietMessage } else { [string]$state.identityQuietMessageDe }
    }
    if ([string]::IsNullOrWhiteSpace($m)) { $m = 'HUD ruht — Identitäts-Abfragen pausiert (Deploy/I/O). Agents-Eingabe sollte nutzbar bleiben.' }
    return $m
  }
  $m = if ($preferDe) {
    if ($state.identityDeferredMessageDe) { [string]$state.identityDeferredMessageDe } else { [string]$state.identityDeferredMessage }
  } else {
    if ($state.identityDeferredMessage) { [string]$state.identityDeferredMessage } else { [string]$state.identityDeferredMessageDe }
  }
  if ([string]::IsNullOrWhiteSpace($m)) { $m = 'Anzeige verzögert — Cursor-DB groß oder beschäftigt. Identity aktualisiert sich nach dem Lesen.' }
  return $m
}

function Set-StateToolTips([bool]$quiet,[bool]$deferred,[string]$tip,[string]$homeTip) {
  if (-not ($script:pillToolTip -and $form)) { return }
  if ($homeTip -and -not $quiet -and -not $deferred) {
    $script:pillTipText = $homeTip
    try { Hide-HudPillTipAbove -Force } catch { }
    foreach ($c in @($form,$label,$scopeLabel,$lookFxCanvas,$border,$tierLabel)) {
      if ($c) { try { $script:pillToolTip.SetToolTip($c, $null) } catch { } }
    }
    return
  }
  $script:pillTipText = ''
  try { Hide-HudPillTipAbove -Force } catch { }
  $script:pillToolTip.SetToolTip($form, $tip); $script:pillToolTip.SetToolTip($label, $tip)
  $script:pillToolTip.SetToolTip($scopeLabel, $tip)
  if ($lookFxCanvas) { $script:pillToolTip.SetToolTip($lookFxCanvas, $tip) }
}

function Apply-StateDeferred($state,[bool]$preferDe,[string]$baseText,[string]$homeTip) {
  $quiet = $false; $deferred = $false
  try { $quiet    = [bool]$state.identityQuiet    } catch { }
  try { $deferred = [bool]$state.identityDeferred } catch { }
  if (-not $quiet -and -not $deferred) {
    try { Set-StateToolTips $false $false $baseText $homeTip } catch { }
    return
  }
  $msg = Resolve-StateStatusMsg $state $preferDe $quiet
  if ($quiet    -and $scopeLabel.Text -notmatch 'Ruhe|quiet')       { $scopeLabel.Text = ($scopeLabel.Text + ' · Ruhe').Trim() }
  elseif ($deferred -and $scopeLabel.Text -notmatch 'verzögert|delayed') { $scopeLabel.Text = ($scopeLabel.Text + ' · verzögert').Trim() }
  try { Set-StateToolTips $quiet $deferred $msg $homeTip } catch { }
}

function Apply-StateFile {
  param([switch]$FromSettingsCommit)
  if ($script:settingsOpen -and -not $FromSettingsCommit) { return }
  if (-not (Test-Path -LiteralPath $statePath)) { $label.Text = '⬜ no state'; Refresh-PillWidth; return }
  try {
    $mtime = (Get-Item -LiteralPath $statePath).LastWriteTimeUtc
    if (-not $script:forceVisual -and $null -ne $script:lastStateMtimeUtc -and $mtime -eq $script:lastStateMtimeUtc) { return }
    $state = (Get-Content -LiteralPath $statePath -Raw) | ConvertFrom-Json
    $script:lastStateMtimeUtc = $mtime
  } catch { return }
  $stamp = [string]$state.updatedAt
  $core  = if ($state.shortLabel) { [string]$state.shortLabel } elseif ($state.label) { [string]$state.label } else { [string]$state.displayLabel }
  $homeResult = Get-StateHomeCoreResult $state $core
  $core = [string]$homeResult.core; $script:homeTip = [string]$homeResult.tip
  $gci  = Read-StateGitCloudInfo $state
  if (-not (Test-StateDataChanged $stamp $core $gci.gitBranch $gci.gitTree $gci.cloud) -and -not $script:forceVisual) { return }
  $script:lastStamp = $stamp; $script:lastLabelCore = $core
  $script:lastGitBranch = $gci.gitBranch; $script:lastGitTree = $gci.gitTree; $script:lastCloud = $gci.cloud
  Apply-StateWorkspaceId $state
  Apply-StateAccentColor $state
  # Marker box already shows emoji/pattern/logo — never duplicate in label text
  $label.Text = Get-StateBaseText (Get-DisplayMarkerMode) $gci.emoji $core
  try { Update-HudLookFxChrome } catch { }
  Update-ScopeCaption
  Apply-StateDeferred $state (Get-StatePreferDe) $label.Text $script:homeTip
  if ([string]::IsNullOrWhiteSpace([string]$script:prefs.borderColor)) { $border.BackColor = $script:accentColor }
  # Full visual rebuild only when prefs/workspace forced it — text-only updates must not steal focus
  if ($script:forceVisual) { Apply-PrefsVisual } else { Refresh-PillWidth }
  $script:forceVisual = $false
  try { $form.Invalidate($true); $form.Update() } catch { }
}