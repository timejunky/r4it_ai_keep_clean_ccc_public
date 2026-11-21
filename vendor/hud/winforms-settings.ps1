# Copyright (c) 2026 ready-4-it
# AI Keep Clean CCC — HUD settings (dot-sourced from winforms-pill.ps1)
# Defines: Clone-PrefsMap, Show-SettingsPanel (+ settings/_load.ps1 modules)
# IA: Menu Einstellungen | Hilfe | Speicher | Aktivierung | About
# Scope: Global | Projekt (default)

function Clone-PrefsMap($src) {
  $dst = [ordered]@{}
  if ($null -eq $src) { return $dst }
  foreach ($k in @($src.Keys)) { $dst[$k] = $src[$k] }
  return $dst
}

$settingsLoad = Join-Path $PSScriptRoot 'settings\_load.ps1'
if (Test-Path -LiteralPath $settingsLoad) { . $settingsLoad }

function Show-SettingsPanel {
  param(
    [string]$StartPage = ''
  )
  $script:settingsStartPage = if ([string]::IsNullOrWhiteSpace($StartPage)) { '' } else { $StartPage.Trim().ToLowerInvariant() }

  if (Get-Command Stop-HudScrollPageLayouts -ErrorAction SilentlyContinue) { Stop-HudScrollPageLayouts }
  $script:FocusHudActivationToken = $null
  $script:HudPageLayoutState = @{}
  $script:AboutLayoutW = $null
  $script:AboutScrollMinH = $null
  $script:AboutLayoutForce = $false
  $script:LayoutAboutPage = $null
  $script:RequestAboutLayout = $null
  if ($script:settingsOpen) {
    $existing = $script:settingsDlg
    if ($null -ne $existing -and -not $existing.IsDisposed) {
      try {
        if ($script:settingsStartPage -and $script:ShowHudSettingsPage) {
          & $script:ShowHudSettingsPage $script:settingsStartPage
        }
      } catch { }
      return
    }
    $script:settingsOpen = $false
  }
  $now = [Environment]::TickCount64
  $cooldown = 400
  if ($script:settingsOpenCooldownMs -is [int] -and [int]$script:settingsOpenCooldownMs -gt 0) {
    $cooldown = [int]$script:settingsOpenCooldownMs
  }
  $lastTick = [int64]$script:lastSettingsOpenTick
  if ($lastTick -gt 0 -and ($now - $lastTick) -lt [int64]$cooldown) { return }
  $script:settingsOpen = $true
  $script:AboutLayoutSettleRemaining = 0  # legacy; layout state lives in Get-HudPageLayoutState
  # Parent pill sets $scale; harden so a missing/null scale cannot leave the lock stuck.
  if ($null -eq $scale -or [double]$scale -le 0) { $scale = 1.0 }

  try {
  $themePath = Join-Path $PSScriptRoot 'winforms-theme.ps1'
  if (-not (Test-Path -LiteralPath $themePath)) {
    throw "HUD-Dateien fehlen ($themePath). Die Pill lief noch, nachdem die Installation entfernt wurde. Pill schließen und aus der aktuellen Installation neu starten."
  }
  . $themePath
  if (-not (Get-Command Get-HudTheme -ErrorAction SilentlyContinue)) {
    throw "Get-HudTheme fehlt nach $themePath. Pill schließen und neu starten."
  }
  $script:HudTheme = Get-HudTheme
    if ($null -eq $script:HudTheme) { throw 'CCC HUD theme initialization failed.' }

  $i18nPath = Join-Path $PSScriptRoot 'i18n\winforms-i18n.ps1'
  if (-not (Get-Command Initialize-HudI18n -ErrorAction SilentlyContinue)) {
    if (Test-Path -LiteralPath $i18nPath) { . $i18nPath }
  }
  if (-not (Get-Command Initialize-HudI18n -ErrorAction SilentlyContinue)) {
    throw "Initialize-HudI18n missing ($i18nPath)"
  }
  $memPath = Join-Path $PSScriptRoot 'winforms-memory.ps1'
  if (Test-Path -LiteralPath $memPath) { . $memPath }
  $langPref = if ([string]::IsNullOrWhiteSpace([string]$script:uiLanguage)) { 'auto' } else { [string]$script:uiLanguage }
  if ([string]::IsNullOrWhiteSpace([string]$script:uiLanguage)) { $script:uiLanguage = 'auto' }
  [void](Initialize-HudI18n $langPref)

  # Free Marketplace / castrated VSIX: no ccc-activation.mjs → no Pro unlock UI/copy surface
  $script:hasActivationCli = Test-Path -LiteralPath (Join-Path $PSScriptRoot 'ccc-activation.mjs')

  if ([string]::IsNullOrWhiteSpace([string]$script:currentWorkspaceId) -and $statePath -and (Test-Path -LiteralPath $statePath)) {
    try {
      $stInit = (Get-Content -LiteralPath $statePath -Raw) | ConvertFrom-Json
      if ($stInit -and -not [string]::IsNullOrWhiteSpace([string]$stInit.workspaceId)) {
        Apply-WorkspacePrefs ([string]$stInit.workspaceId)
      }
    } catch { }
  }
  if (-not (Test-HudFeature 'hud.scope.project')) {
    $script:editScope = 'global'
  } elseif ([string]::IsNullOrWhiteSpace([string]$script:editScope)) {
    $script:editScope = 'project'
  }
  $script:prefs = Get-PrefsForEdit $script:editScope
  $script:prefsSnapshot = Clone-PrefsMap $script:prefs
  $script:scopeSnapshot = [string]$script:editScope
  $script:dlgMarkerEmoji = [string]$script:prefs.markerEmoji
  if ([string]::IsNullOrWhiteSpace($script:dlgMarkerEmoji)) { $script:dlgMarkerEmoji = '🔵' }

  $pkgVer = if (Get-Command Get-CccAboutPackageVersion -ErrorAction SilentlyContinue) {
    Get-CccAboutPackageVersion -HudScriptRoot $PSScriptRoot
  } else {
    ''
  }

  $ui = @{
    applied         = $false
    syncing         = $false
    selectedLayer   = 'border'
    pageEinst       = $null; pageSpeicher = $null; pageHilfe = $null; pageLizenz = $null; pageAbout = $null
    miniPreview     = $null
    topBar          = $null; bottomBar = $null
    themePanel      = $null
    themeRadios     = (New-Object System.Collections.ArrayList)
    formRadios      = (New-Object System.Collections.ArrayList)
    colorRadios     = (New-Object System.Collections.ArrayList)
    formChips       = (New-Object System.Collections.ArrayList)
    themes          = (New-Object System.Collections.ArrayList)
    themeOptions    = (New-Object System.Collections.ArrayList)
    themeCategories = (New-Object System.Collections.ArrayList)
    themeArtImages  = (New-Object System.Collections.ArrayList)
    presetMode      = $false
    iconLogoMode    = $false
    selectedThemeId = ''
    selectedOrbId   = ''
    orbRadios       = (New-Object System.Collections.ArrayList)
    orbPanel        = $null
    orbHost         = $null
    chkOverwriteLogo = $null
    btnIconLogo     = $null
    leftPane        = $null; boxHost = $null; boxFrame = $null; lblBox = $null
    inspHost        = $null; iconHost = $null; iconCard = $null
    btnApply        = $null; btnClose = $null; btnPreset = $null
    lblScopeHint    = $null
    rbProject       = $null; rbGlobal = $null
    pnlMargin       = $null; pnlBorder = $null; pnlPadding = $null; pnlContent = $null; lblContent = $null
    lblInsp         = $null
    numMargin       = $null; numPad = $null; numBorderW = $null; numFontSz = $null
    txtBorderC      = $null; txtFill = $null; txtTextC = $null; txtMarkC = $null; txtLogo = $null
    cmbFont         = $null; cmbMode = $null; cmbPat = $null
    inspCtrls       = (New-Object System.Collections.ArrayList)
    colMargin       = [System.Drawing.Color]::FromArgb(32, 160, 150)
    colBorder       = [System.Drawing.Color]::FromArgb(70, 140, 220)
    colPadding      = [System.Drawing.Color]::FromArgb(90, 180, 100)
    colContent      = [System.Drawing.Color]::FromArgb(245, 248, 252)
    colMarginDim    = [System.Drawing.Color]::FromArgb(24, 110, 105)
    colBorderDim    = [System.Drawing.Color]::FromArgb(45, 95, 150)
    colPaddingDim   = [System.Drawing.Color]::FromArgb(60, 125, 70)
    colContentDim   = [System.Drawing.Color]::FromArgb(210, 218, 228)
  }

  $dlg = New-Object System.Windows.Forms.Form
  $script:settingsDlg = $dlg
  $dlg.Text = Get-HudT 'app.title'
  $dlg.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
  $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
  $dlg.MaximizeBox = $true; $dlg.MinimizeBox = $true
  $dlg.ShowInTaskbar = $true; $dlg.TopMost = $true
  $dlg.Add_Shown({
    param($sender, $e)
    try {
      [CccHudWin]::ShowUnownedTopMost($sender.Handle)
      $sender.TopMost = $true
      $sender.BringToFront()
      [void]$sender.Activate()
    } catch { }
  })
  $dlg.MinimumSize = New-Object System.Drawing.Size(([int](960 * $scale)), ([int](700 * $scale)))
  $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
  $wantW = [Math]::Min(([int](1180 * $scale)), [Math]::Max(([int](1000 * $scale)), [int]($wa.Width * 0.72)))
  $wantH = [Math]::Min(([int](900 * $scale)), [Math]::Max(([int](760 * $scale)), [int]($wa.Height * 0.82)))
  $dlg.Size = New-Object System.Drawing.Size($wantW, $wantH)
  Apply-HudDialogShell -Form $dlg -Scale $scale -Theme $script:HudTheme
  $dlg.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi

  function New-FlatBtn([string]$text, [int]$w, [int]$h, $bg, [switch]$FixedWidth) {
    # Prefer Gemini metal template; primary (cyan metal) for accent/success CTAs.
    $primary = $false
    $hex = '{0:X2}{1:X2}{2:X2}' -f $bg.R, $bg.G, $bg.B
    if ($hex -match '^(285A78|2D7896|28785A|28705A|466E8C)') { $primary = $true }
    return (New-HudMetalButton -Text $text -Width $w -Height $h -Theme $script:HudTheme -AccentGlow:$primary -Primary:$primary -FixedWidth:$FixedWidth)
  }
  function New-DarkText([int]$w) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Width = $w
    $t.BackColor = [System.Drawing.Color]::FromArgb(28, 34, 44)
    $t.ForeColor = [System.Drawing.Color]::FromArgb(240, 244, 250)
    $t.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    return $t
  }
  function New-DarkCombo([int]$w, [string[]]$items) {
    $c = New-Object System.Windows.Forms.ComboBox
    $c.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $c.Width = $w
    $c.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $c.BackColor = [System.Drawing.Color]::FromArgb(28, 34, 44)
    $c.ForeColor = [System.Drawing.Color]::FromArgb(240, 244, 250)
    [void]$c.Items.AddRange($items)
    return $c
  }

  # WinForms Disabled = system gray-on-dark (unreadable). Gate visually; clicks still run Test-HudFeature.
  $script:hudFgOn = [System.Drawing.Color]::FromArgb(240, 244, 250)
  $script:hudFgLocked = [System.Drawing.Color]::FromArgb(190, 200, 215)
  $script:hudBgLocked = [System.Drawing.Color]::FromArgb(42, 48, 60)
  $script:hudBorderOn = [System.Drawing.Color]::FromArgb(100, 112, 132)
  $script:hudBorderLocked = [System.Drawing.Color]::FromArgb(72, 82, 98)

  function Set-HudGatedButton($btn, [bool]$allowed, $bgAllowed) {
    if (-not $btn) { return }
    $btn.Enabled = $true
    $btn.UseVisualStyleBackColor = $false
    if ($btn.Tag -is [hashtable] -and $btn.Tag.ContainsKey('Theme')) {
      $btn.BackColor = [System.Drawing.Color]::Transparent
      $btn.Tag.Locked = (-not $allowed)
      $btn.Invalidate()
      return
    }
    if ($allowed) {
      $btn.BackColor = $bgAllowed
      $btn.ForeColor = $script:hudFgOn
      $btn.FlatAppearance.BorderColor = $script:hudBorderOn
    } else {
      $btn.BackColor = $script:hudBgLocked
      $btn.ForeColor = $script:hudFgLocked
      $btn.FlatAppearance.BorderColor = $script:hudBorderLocked
    }
  }

  function Set-HudGatedField($ctrl, [bool]$allowed) {
    if (-not $ctrl) { return }
    if ($ctrl -is [System.Windows.Forms.TextBox]) {
      $ctrl.Enabled = $true
      $ctrl.ReadOnly = -not $allowed
      $ctrl.BackColor = [System.Drawing.Color]::FromArgb(28, 34, 44)
      $ctrl.ForeColor = if ($allowed) { $script:hudFgOn } else { $script:hudFgLocked }
      return
    }
    if ($ctrl -is [System.Windows.Forms.ComboBox]) {
      $ctrl.Enabled = $true
      $ctrl.BackColor = [System.Drawing.Color]::FromArgb(28, 34, 44)
      $ctrl.ForeColor = if ($allowed) { $script:hudFgOn } else { $script:hudFgLocked }
      return
    }
    if ($ctrl -is [System.Windows.Forms.CheckBox]) {
      $ctrl.Enabled = $true
      $ctrl.ForeColor = if ($allowed) { $script:hudFgOn } else { $script:hudFgLocked }
    }
  }

  function Show-Page([string]$name) {
    $invalidLicense = $false
    if (Get-Command Test-HudStoredLicenseInvalid -ErrorAction SilentlyContinue) {
      try { $invalidLicense = [bool](Test-HudStoredLicenseInvalid) } catch { $invalidLicense = $false }
    }
    if ($invalidLicense -and ($name -eq 'einst' -or $name -eq 'speicher')) {
      $name = 'lizenz'
      if (-not $script:hudInvalidLicensePromptBusy) {
        $script:hudInvalidLicensePromptBusy = $true
        $promptInvalid = {
          try { Show-InvalidLicenseBlocker } catch { }
          finally { $script:hudInvalidLicensePromptBusy = $false }
        }
        try {
          if ($dlg.IsHandleCreated) {
            [void]$dlg.BeginInvoke([System.Windows.Forms.MethodInvoker]$promptInvalid)
          } else {
            & $promptInvalid
          }
        } catch {
          & $promptInvalid
        }
      }
    }
    $pages.SuspendLayout()
    try {
      $ui.pageEinst.Visible = ($name -eq 'einst')
      if ($ui.pageSpeicher) { $ui.pageSpeicher.Visible = ($name -eq 'speicher') }
      $ui.pageHilfe.Visible = ($name -eq 'hilfe')
      $ui.pageLizenz.Visible = ($name -eq 'lizenz')
      $ui.pageAbout.Visible = ($name -eq 'about')
      if ($ui.navButtons -and $script:SetHudNavActive) { & $script:SetHudNavActive $name }
    } finally {
      $pages.ResumeLayout($true)
    }
    # Layout after page is visible + sized (debounced for About).
    if ($name -eq 'einst') {
      Apply-SettingsLayout
    }
    if ($name -eq 'about' -and $script:RequestAboutLayout) {
      & $script:RequestAboutLayout
    }
    if ($name -eq 'speicher' -and $script:RefreshStoragePage) {
      & $script:RefreshStoragePage
    }
    if ($name -eq 'hilfe' -and $script:RequestHelpLayout) {
      & $script:RequestHelpLayout
    }
    if ($name -eq 'lizenz' -and $script:LayoutActivationPage) {
      (Get-HudPageLayoutState 'activation').LayoutW = $null
      & $script:LayoutActivationPage
    }
    $script:hudSettingsPage = $name
    if (Get-Command Sync-HudHelpDrawer -ErrorAction SilentlyContinue) { Sync-HudHelpDrawer }
  }

  function Apply-StylePreset([string]$id) {
    $keepLogo = Test-HudHasActiveImageMarker
    $savedImg = [string]$script:prefs.imagePath
    $savedSrc = [string]$script:prefs.logoSourceName
    $savedDir = [string]$script:prefs.logoBrowseDir
    $savedOv = $false
    try { $savedOv = [bool]$script:prefs.overwriteCustomLogo } catch { $savedOv = $false }
    switch ($id) {
      'minimal' {
        $script:prefs.fillColor = '#161c26'; $script:prefs.textColor = '#c8d0dc'
        $script:prefs.borderWidth = 1; $script:prefs.padding = 4; $script:prefs.margin = 2
        $script:prefs.borderColor = ''
        if (-not $keepLogo) {
          $script:prefs.markerMode = 'emoji'
          if ([string]::IsNullOrWhiteSpace([string]$script:prefs.markerEmoji) -or [string]$script:prefs.markerEmoji -eq '⬛') {
            $script:prefs.markerEmoji = '⚪'
          }
          $script:dlgMarkerEmoji = [string]$script:prefs.markerEmoji
        }
      }
      'hc' {
        $script:prefs.fillColor = '#000000'; $script:prefs.textColor = '#ffffff'
        $script:prefs.borderColor = '#ffffff'; $script:prefs.borderWidth = 3
        $script:prefs.padding = 6; $script:prefs.margin = 4
        $script:prefs.markerColor = '#ffffff'
        if (-not $keepLogo) {
          $script:prefs.markerMode = 'emoji'
          if ([string]::IsNullOrWhiteSpace([string]$script:prefs.markerEmoji) -or [string]$script:prefs.markerEmoji -eq '⬛') {
            $script:prefs.markerEmoji = '⚪'
          }
          $script:dlgMarkerEmoji = [string]$script:prefs.markerEmoji
        }
      }
      'stripes' {
        if (-not (Test-HudFeature 'hud.marker.pattern')) {
          Show-ProUpgradeHint 'Muster (Pattern)'
          return
        }
        if ($keepLogo) {
          $askMsg = Get-HudT 'settings.style.stripes.confirmLogo'
          if ([string]::IsNullOrWhiteSpace($askMsg) -or $askMsg -eq 'settings.style.stripes.confirmLogo') {
            $askMsg = 'Ein aktives Logo ist gesetzt. Soll es durch das Streifen-Muster ersetzt werden?'
          }
          $ans = 'No'
          if (Get-Command Show-HudMessageBox -ErrorAction SilentlyContinue) {
            $ans = Show-HudMessageBox -Text $askMsg -Caption (Get-HudT 'app.title') -Buttons ([System.Windows.Forms.MessageBoxButtons]::YesNo) -Icon ([System.Windows.Forms.MessageBoxIcon]::Question)
          }
          if ($ans -ne 'Yes') { return }
          Clear-OrbPick
        }
        $script:prefs.markerMode = 'pattern'; $script:prefs.pattern = 'stripes'
        $script:prefs.fillColor = '#161c26'; $script:prefs.textColor = '#ffffff'
        $script:prefs.borderWidth = 2; $script:prefs.padding = 6; $script:prefs.margin = 4
      }
      default {
        foreach ($k in @($script:defaultPrefs.Keys)) { $script:prefs[$k] = $script:defaultPrefs[$k] }
        $script:prefs.logoBrowseDir = $savedDir
        $script:prefs.overwriteCustomLogo = $savedOv
        if ($keepLogo) {
          $script:prefs.markerMode = 'image'
          $script:prefs.imagePath = $savedImg
          $script:prefs.logoSourceName = $savedSrc
        }
        $script:dlgMarkerEmoji = [string]$script:prefs.markerEmoji
      }
    }
  }

  function Get-HudPresetsPath {
    $candidates = @(
      (Join-Path $PSScriptRoot '..\ccc\hud-presets.json'),
      (Join-Path $PSScriptRoot '..\..\.ccc\hud-presets.json'),
      (Join-Path $PSScriptRoot '..\..\vendor\ccc\hud-presets.json'),
      (Join-Path $PSScriptRoot '..\..\defaults\hud-presets.json'),
      (Join-Path $PSScriptRoot '..\..\..\.ccc\hud-presets.json'),
      (Join-Path $PSScriptRoot '..\..\..\..\.ccc\hud-presets.json'),
      (Join-Path $env:USERPROFILE '.cursor\plugins\local\ai-keep-clean-ccc\vendor\ccc\hud-presets.json'),
      (Join-Path $env:USERPROFILE '.cursor\plugins\local\cursor-control-center\vendor\ccc\hud-presets.json'),
      (Join-Path $env:USERPROFILE '.cursor\ccc-hud-presets.json')
    )
    foreach ($c in $candidates) {
      try {
        $full = [System.IO.Path]::GetFullPath($c)
        if (Test-Path -LiteralPath $full) { return $full }
      } catch { }
    }
    return $null
  }

  function Load-HudPresetCatalog {
    $path = Get-HudPresetsPath
    if (-not $path) { return $null }
    try { return (Get-Content -LiteralPath $path -Raw -Encoding UTF8) | ConvertFrom-Json } catch { return $null }
  }

  function Get-SugVal($sug, [string]$key) {
    if ($null -eq $sug) { return $null }
    $v = $null
    if ($sug -is [hashtable] -or $sug -is [System.Collections.IDictionary]) {
      if ($sug.Contains($key)) { $v = $sug[$key] }
      elseif ($sug.ContainsKey($key)) { $v = $sug[$key] }
    } else {
      try { $v = $sug.$key } catch { $v = $null }
    }
    if ($null -eq $v) { return $null }
    $s = [string]$v
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    return $s
  }

  function Test-HudWantsOverwriteCustomLogo {
    if ($ui.chkOverwriteLogo) { return [bool]$ui.chkOverwriteLogo.Checked }
    try { return [bool]$script:prefs.overwriteCustomLogo } catch { return $false }
  }

  function Show-LogoOverwriteBlocked {
    $msg = Get-HudT 'settings.logo.overwrite.blocked'
    try {
      if (Get-Command Show-HudMessageBox -ErrorAction SilentlyContinue) {
        Show-HudMessageBox $msg | Out-Null
        return
      }
    } catch { }
    try {
      [System.Windows.Forms.MessageBox]::Show(
        $msg,
        (Get-HudT 'app.title'),
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
      ) | Out-Null
    } catch { }
  }

  function Apply-LookColors($sug) {
    if ($null -eq $sug) { return }
    $mc = Get-SugVal $sug 'markerColor'
    $bc = Get-SugVal $sug 'borderColor'
    $fc = Get-SugVal $sug 'fillColor'
    $tc = Get-SugVal $sug 'textColor'
    if ($mc) { $script:prefs.markerColor = $mc }
    if ($bc) { $script:prefs.borderColor = $bc }
    if ($fc) { $script:prefs.fillColor = $fc }
    if ($tc) { $script:prefs.textColor = $tc }
  }

  function Get-HudLookFxFromSug($sug) {
    if ($null -eq $sug) { return '' }
    if (-not (Get-Command Get-HudLookFxName -ErrorAction SilentlyContinue)) { return '' }
    $explicit = Get-SugVal $sug 'lookFx'
    if ($explicit) { return Get-HudLookFxName $explicit }
    $id = Get-SugVal $sug 'id'
    if ($id) { return Get-HudLookFxName $id }
    return ''
  }

  function Apply-LookSuggestion($sug) {
    if ($null -eq $sug) { return }
    # Color vibe only. Form (lookFx) stays as chosen.
    Apply-LookColors $sug
    $id = Get-SugVal $sug 'id'
    if ($id) { $script:prefs.lookId = $id }
  }

  function Get-HudFormOptionId {
    $fx = ''
    if (Get-Command Get-HudLookFxName -ErrorAction SilentlyContinue) {
      $fx = Get-HudLookFxName ([string]$script:prefs.lookFx)
    }
    if ([string]::IsNullOrWhiteSpace($fx)) { return 'form-none' }
    foreach ($cat in @($ui.themeCategories)) {
      $isForm = ([string]$cat.kind -eq 'form' -or [string]$cat.id -eq '3d')
      if (-not $isForm) { continue }
      foreach ($opt in @($cat.options)) {
        $optFx = ''
        if (Get-Command Get-HudLookFxName -ErrorAction SilentlyContinue) {
          $optFx = Get-HudLookFxName ([string]$opt.lookFx)
        }
        if ($optFx -eq $fx) { return [string]$opt.id }
      }
    }
    return 'form-none'
  }

  function Convert-LegacyLookBundle {
    $id = [string]$script:prefs.lookId
    $bundle = @{
      '3d-ice'   = @{ fx = 'cube';    color = 'studio-eis' }
      '3d-depth' = @{ fx = 'extrude'; color = 'studio-tiefe' }
      '3d-glass' = @{ fx = 'glass';   color = 'studio-klar' }
      '3d-orb'   = @{ fx = 'sphere';  color = 'studio-violett' }
    }
    if (-not $bundle.ContainsKey($id)) { return }
    $hit = $bundle[$id]
    if ([string]::IsNullOrWhiteSpace([string]$script:prefs.lookFx)) {
      $script:prefs.lookFx = [string]$hit.fx
    }
    $script:prefs.lookId = [string]$hit.color
  }

  function Test-HudHasActiveImageMarker {
    return ([string]$script:prefs.markerMode -eq 'image') -and (Test-HudPath ([string]$script:prefs.imagePath))
  }

  function Apply-OrbMarker($sug) {
    if ($null -eq $sug) { return $false }
    $img = Get-SugVal $sug 'imagePath'
    if (-not (Test-HudPath $img)) { return $false }
    if (-not (Test-HudFeature 'hud.marker.image')) {
      Show-ProUpgradeHint 'Icon / Logo (Orb)'
      return $false
    }
    if ((Test-HudIsUserCustomLogo ([string]$script:prefs.imagePath)) -and -not (Test-HudWantsOverwriteCustomLogo)) {
      Show-LogoOverwriteBlocked
      return $false
    }
    $script:prefs.markerMode = 'image'
    $script:prefs.imagePath = $img
    $script:prefs.logoSourceName = ''
    return $true
  }

  function Persist-SelectedOrb {
    $oid = [string]$ui.selectedOrbId
    if ([string]::IsNullOrWhiteSpace($oid)) { return }
    $sel = Get-ThemeById $oid
    if ($null -eq $sel) { return }
    if ([string](Get-SugVal $sel 'kind') -ne 'image') { return }
    $srcImg = Get-SugVal $sel 'imagePath'
    if (-not (Test-HudPath $srcImg)) { return }
    if (-not (Test-HudFeature 'hud.marker.image')) { return }
    if ((Test-HudIsUserCustomLogo ([string]$script:prefs.imagePath)) -and -not (Test-HudWantsOverwriteCustomLogo)) {
      return
    }
    if ([string]$script:prefs.markerMode -ne 'image') { return }
    try {
      if (-not (Test-HudPath $assetsDir)) {
        New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
      }
      $dest = Join-Path $assetsDir ("orb-$($sel.id)$([IO.Path]::GetExtension($srcImg))")
      $check = Test-HudLogoAssetFile $srcImg
      if (-not [bool]$check.ok) {
        Show-HudLogoReject $check
        return
      }
      Copy-Item -LiteralPath $srcImg -Destination $dest -Force
      $script:prefs.imagePath = $dest
      $script:prefs.markerMode = 'image'
    } catch {
      $script:prefs.imagePath = $srcImg
      $script:prefs.markerMode = 'image'
    }
  }

  function Update-FormChips {
    if (-not $ui.formChips) { return }
    foreach ($chip in @($ui.formChips)) {
      $box = $chip.box
      if ($null -eq $box) { continue }
      $fx = [string]$chip.fx
      $fillC = Parse-HexColor ([string]$script:prefs.fillColor)
      if ($null -eq $fillC) { $fillC = [System.Drawing.Color]::FromArgb(22, 28, 38) }
      $accC = Parse-HexColor ([string]$script:prefs.markerColor)
      if ($null -eq $accC) { $accC = Parse-HexColor ([string]$script:prefs.borderColor) }
      if ($null -eq $accC) { $accC = [System.Drawing.Color]::FromArgb(90, 209, 232) }
      $bordC = Parse-HexColor ([string]$script:prefs.borderColor)
      if ($null -eq $bordC) { $bordC = $accC }
      $bmp = $null
      try {
        if ($fx -and ('HudLookFx' -as [type])) {
          $textC = Parse-HexColor ([string]$script:prefs.textColor)
          if ($null -eq $textC) { $textC = [System.Drawing.Color]::White }
          $bmp = [HudLookFx]::Chip($box.Width, $box.Height, $fx, $fillC, $accC, $bordC, $textC)
        } else {
          $bmp = New-Object System.Drawing.Bitmap $box.Width, $box.Height
          $g = [System.Drawing.Graphics]::FromImage($bmp)
          try {
            $g.Clear($fillC)
            $pen = New-Object System.Drawing.Pen $bordC, 2
            try { $g.DrawRectangle($pen, 1, 1, ($box.Width - 3), ($box.Height - 3)) } finally { $pen.Dispose() }
          } finally { $g.Dispose() }
        }
      } catch { $bmp = $null }
      if ($null -eq $bmp) { continue }
      $old = $null
      try { $old = $box.Image } catch { }
      $box.Image = $bmp
      if ($null -ne $old) { try { $old.Dispose() } catch { } }
    }
  }

  function Sync-LookRadios {
    $colorId = [string]$script:prefs.lookId
    $formId = Get-HudFormOptionId
    $prevSync = [bool]$ui.syncing
    $ui.syncing = $true
    try {
      foreach ($rb in @($ui.colorRadios)) { $rb.Checked = ([string]$rb.Tag -eq $colorId) }
      foreach ($rb in @($ui.formRadios)) { $rb.Checked = ([string]$rb.Tag -eq $formId) }
    } finally { $ui.syncing = $prevSync }
  }

  function Select-ColorOption([string]$id) {
    if ([string]::IsNullOrWhiteSpace($id)) { return }
    $sel = Get-ThemeById $id
    if ($null -eq $sel) { return }
    $ui.selectedThemeId = $id
    $ui.syncing = $true
    try {
      foreach ($rb in @($ui.colorRadios)) { $rb.Checked = ([string]$rb.Tag -eq $id) }
    } finally { $ui.syncing = $false }
    Apply-LookSuggestion $sel
    Show-ThemeSwatchesOnBox $sel
    Update-FormChips
    Load-InspectorFromPrefs
    Preview-DialogOnly
  }

  function Select-FormOption([string]$id) {
    if ([string]::IsNullOrWhiteSpace($id)) { return }
    $sel = Get-ThemeById $id
    if ($null -eq $sel) { return }
    $fx = Get-SugVal $sel 'lookFx'
    $script:prefs.lookFx = if ($fx) { [string]$fx } else { '' }
    $ui.syncing = $true
    try {
      foreach ($rb in @($ui.formRadios)) { $rb.Checked = ([string]$rb.Tag -eq $id) }
    } finally { $ui.syncing = $false }
    $color = Get-ThemeById ([string]$script:prefs.lookId)
    if ($null -ne $color) { Show-ThemeSwatchesOnBox $color } else { Update-BoxLookFxImage }
    Update-FormChips
    Preview-DialogOnly
  }

  function Select-ThemeOption([string]$id) {
    if ([string]::IsNullOrWhiteSpace($id)) { return }
    $sel = Get-ThemeById $id
    if ($null -eq $sel) { return }
    $kind = [string](Get-SugVal $sel 'kind')
    if ($kind -eq 'image') {
      Select-OrbOption $id
      return
    }
    if ($kind -eq 'form') {
      Select-FormOption $id
      return
    }
    Select-ColorOption $id
  }

  function Clear-OrbPick {
    $ui.selectedOrbId = ''
    if (-not $ui.orbRadios) { return }
    $prevSync = [bool]$ui.syncing
    $ui.syncing = $true
    try {
      foreach ($rb in $ui.orbRadios) { $rb.Checked = $false }
    } finally { $ui.syncing = $prevSync }
  }

  function Select-OrbOption([string]$id) {
    if ([string]::IsNullOrWhiteSpace($id)) { return }
    $sel = Get-ThemeById $id
    if ($null -eq $sel) { return }
    $ok = Apply-OrbMarker $sel
    $ui.syncing = $true
    try {
      foreach ($rb in $ui.orbRadios) {
        $rb.Checked = $ok -and ([string]$rb.Tag -eq $id)
      }
    } finally { $ui.syncing = $false }
    if (-not $ok) { return }
    $ui.selectedOrbId = $id
    Load-InspectorFromPrefs
    Preview-DialogOnly
  }

  function Commit-DialogPrefsToPill {
    # Block Leave→Sync races while committing; keep fillColor from Look-Preset
    $ui.syncing = $true
    $commitSnap = $null
    try {
      Enforce-FreeMarkerPrefs
      if ($ui.chkOverwriteLogo) {
        $script:prefs.overwriteCustomLogo = [bool]$ui.chkOverwriteLogo.Checked
      }
      $sel = $null
      if (-not [string]::IsNullOrWhiteSpace([string]$ui.selectedThemeId)) {
        $sel = Get-ThemeById ([string]$ui.selectedThemeId)
      }
      if (-not $ui.presetMode) {
        $ui.syncing = $false
        Sync-FromInspector
        $ui.syncing = $true
        if ($null -ne $sel) {
          $need = [string]::IsNullOrWhiteSpace([string]$script:prefs.fillColor) -or
                  [string]::IsNullOrWhiteSpace([string]$script:prefs.borderColor) -or
                  [string]::IsNullOrWhiteSpace([string]$script:prefs.textColor) -or
                  [string]::IsNullOrWhiteSpace([string]$script:prefs.markerColor)
          if ($need) { Apply-LookSuggestion $sel }
        }
      }
      Persist-SelectedOrb

      # Snapshot exact colors before any store/reload round-trip
      $commitSnap = @{
        fillColor   = [string]$script:prefs.fillColor
        borderColor = [string]$script:prefs.borderColor
        textColor   = [string]$script:prefs.textColor
        markerColor = [string]$script:prefs.markerColor
        markerEmoji = [string]$script:prefs.markerEmoji
        markerMode  = [string]$script:prefs.markerMode
        imagePath   = [string]$script:prefs.imagePath
        logoSourceName = [string]$script:prefs.logoSourceName
        overwriteCustomLogo = [bool]$script:prefs.overwriteCustomLogo
        lookFx      = [string]$script:prefs.lookFx
        lookId      = [string]$script:prefs.lookId
      }

      Save-PrefsToStore $script:editScope $script:prefs
      Save-Prefs
      $script:prefs = Get-PrefsForEdit $script:editScope

      # Restore commit snapshot if merge/reload dropped Innenfarbe or related keys
      $restored = $false
      foreach ($ck in @('fillColor', 'borderColor', 'textColor', 'markerColor', 'markerEmoji', 'markerMode', 'imagePath', 'logoSourceName', 'overwriteCustomLogo', 'lookFx', 'lookId')) {
        $want = [string]$commitSnap[$ck]
        $got = [string]$script:prefs[$ck]
        $keep = ($ck -eq 'lookFx' -or $ck -eq 'lookId' -or $ck -eq 'imagePath' -or $ck -eq 'logoSourceName') -or (-not [string]::IsNullOrWhiteSpace($want))
        if ($keep -and $got -ne $want) {
          $script:prefs[$ck] = $commitSnap[$ck]
          $restored = $true
        }
      }
      if ($restored) {
        Save-PrefsToStore $script:editScope $script:prefs
        Save-Prefs
      }
    } finally {
      $ui.syncing = $false
    }
    $script:prefsSnapshot = Clone-PrefsMap $script:prefs
    $script:scopeSnapshot = [string]$script:editScope
    $ui.applied = $true
    $script:forceVisual = $true
    Apply-PrefsVisual
    Apply-StateFile -FromSettingsCommit
    Apply-HudAutostart
    try {
      if ($form -and -not $form.IsDisposed) {
        $form.Invalidate($true)
        $form.Update()
      }
    } catch { }
  }

  function Get-ThemeById([string]$id) {
    foreach ($opt in $ui.themeOptions) {
      if ([string]$opt.id -eq $id) { return $opt }
    }
    return $null
  }

  function Fit-BoxModelContentLabel([string]$raw) {
    if (-not $ui.lblContent -or -not $ui.pnlContent) { return }
    if ($script:fittingBoxLabel) { return }
    $script:fittingBoxLabel = $true
    try {
      $markW = 0
      if ($ui.boxMarker) { $markW = [int]$ui.boxMarker.Width }
      $labelW = 0
      try { $labelW = [int]$ui.lblContent.ClientSize.Width } catch { $labelW = 0 }
      if ($labelW -lt 20) { $labelW = [int]$ui.pnlContent.ClientSize.Width - $markW }
      $cw = [Math]::Max(20, $labelW - 4)
      $ch = [Math]::Max(14, $ui.pnlContent.ClientSize.Height - 2)
      # Tall content + long unbroken names wrap mid-word; keep one line via font + ellipsis.
      $fs = [float][Math]::Min(([double](9.0 * $scale)), [Math]::Max(6.5, ([double]$ch - 6)))
      if ($fs -lt 6.0) { $fs = 6.0 }
      $txt = if ([string]::IsNullOrWhiteSpace($raw)) { 'Content' } else { $raw }
      $needNewFont = $true
      try {
        if ($ui.lblContent.Font -and [Math]::Abs(([double]$ui.lblContent.Font.Size) - $fs) -lt 0.05) {
          $needNewFont = $false
        }
      } catch { }
      if ($needNewFont) {
        try { $fnt = New-Object System.Drawing.Font('Segoe UI Semibold', $fs, [System.Drawing.FontStyle]::Regular) }
        catch { $fnt = New-Object System.Drawing.Font('Segoe UI', $fs, [System.Drawing.FontStyle]::Regular) }
        # Do not Dispose the previous Font — paint may still hold it (GDI+ "Parameter is not valid").
        $ui.lblContent.Font = $fnt
      }
      $ui.lblContent.AutoSize = $false
      $ui.lblContent.AutoEllipsis = $true
      $ui.lblContent.UseCompatibleTextRendering = $false
      $ui.lblContent.Padding = New-Object System.Windows.Forms.Padding(1)
      try {
        $ui.lblContent.Text = (Get-HudEllipsisText -Text $txt -Font $ui.lblContent.Font -MaxWidth $cw)
      } catch {
        $ui.lblContent.Text = $txt
      }
    } finally {
      $script:fittingBoxLabel = $false
    }
  }

  function Show-ThemeSwatchesOnBox($theme) {
    $sw = @()
    if ($null -ne $theme -and $theme.swatches) { $sw = @($theme.swatches) }
    while ($sw.Count -lt 4) { $sw += '#888888' }
    $c0 = Parse-HexColor ([string]$sw[0]); if ($null -eq $c0) { $c0 = $ui.colMargin }
    $c1 = Parse-HexColor ([string]$sw[1]); if ($null -eq $c1) { $c1 = $ui.colBorder }
    $c2 = Parse-HexColor ([string]$sw[2]); if ($null -eq $c2) { $c2 = $ui.colPadding }
    $c3 = Parse-HexColor ([string]$sw[3]); if ($null -eq $c3) { $c3 = $ui.colContent }
    $ui.pnlMargin.BackColor = $c0
    $ui.pnlBorder.BackColor = $c1
    $ui.pnlPadding.BackColor = $c2
    $ui.pnlContent.BackColor = $c3
    $name = if ($theme -and $theme.label) { [string]$theme.label } else { Get-HudT 'settings.lookPreset' }
    Fit-BoxModelContentLabel $name
    $tcBox = Parse-HexColor (Get-SugVal $theme 'textColor')
    if ($null -eq $tcBox) { $tcBox = [System.Drawing.Color]::FromArgb(20, 24, 32) }
    $ui.lblContent.ForeColor = $tcBox
    Update-BoxLookFxImage
  }

  function Update-BoxLookFxImage {
    # The nested box stays a layer model. The rendered form lives in the mini preview.
    $lbl = $ui.lblContent
    if ($null -eq $lbl) { return }
    if (Get-Command Dispose-HudLookFxImage -ErrorAction SilentlyContinue) {
      Dispose-HudLookFxImage $lbl 'Image'
    } elseif ($lbl.Image) {
      try { $old = $lbl.Image; $lbl.Image = $null; $old.Dispose() } catch { }
    }
    try { $lbl.UseCompatibleTextRendering = $false } catch { }
    try { $lbl.BackColor = $ui.pnlContent.BackColor } catch { }
    $authored = Parse-HexColor ([string]$script:prefs.textColor)
    if ($null -eq $authored) { $authored = $lbl.ForeColor }
    if (Get-Command Resolve-HudReadableTextColor -ErrorAction SilentlyContinue) {
      $lbl.ForeColor = Resolve-HudReadableTextColor -Text $authored -Background $ui.pnlContent.BackColor
    }
  }

  function Preview-DialogOnly {
    # Dialog preview only — live pill / icon edit stay until Uebernehmen
    Layout-BoxModel
    Render-MiniPreview
  }

  function Enter-PresetMode {
    Exit-IconLogoModeIfNeeded
    $ui.presetMode = $true
    $ui.iconLogoMode = $false
    $ui.selectedLayer = 'preset'
    foreach ($c in $ui.inspCtrls) { $c.Visible = $false }
    if ($ui.themePanel) { $ui.themePanel.Visible = $true; $ui.themePanel.BringToFront() }
    if ($ui.orbPanel) { $ui.orbPanel.Visible = $false }
    if ($ui.iconHost) { $ui.iconHost.Visible = $false }
    if ($ui.iconCard) { $ui.iconCard.Visible = $false }
    $ui.lblInsp.Text = Get-HudT 'settings.inspector.preset'
    Update-LookPresetButtonChrome
    Convert-LegacyLookBundle
    $ui.selectedThemeId = [string]$script:prefs.lookId
    Sync-LookRadios
    $th = Get-ThemeById ([string]$script:prefs.lookId)
    if ($null -ne $th -and [string](Get-SugVal $th 'kind') -ne 'form') {
      Show-ThemeSwatchesOnBox $th
    } else {
      Update-BoxLookFxImage
    }
    Update-FormChips
    Load-InspectorFromPrefs
    Preview-DialogOnly
    Apply-SettingsLayout
    if (Get-Command Sync-HudHelpDrawer -ErrorAction SilentlyContinue) { Sync-HudHelpDrawer }
  }

  function Exit-PresetModeIfNeeded {
    if (-not $ui.presetMode) { return }
    $ui.presetMode = $false
    if ($ui.themePanel) { $ui.themePanel.Visible = $false }
    if (-not $ui.iconLogoMode) {
      if ($ui.iconCard) { $ui.iconCard.Visible = $true }
      if ($ui.iconHost) { $ui.iconHost.Visible = $true }
    }
    Load-InspectorFromPrefs
    Update-LookPresetButtonChrome
  }

  function Enter-IconLogoMode {
    Exit-PresetModeIfNeeded
    $ui.iconLogoMode = $true
    if ($ui.iconCard) { $ui.iconCard.Visible = $true }
    if ($ui.iconHost) { $ui.iconHost.Visible = $true }
    Update-LookPresetButtonChrome
    Apply-SettingsLayout
    if (Get-Command Sync-HudHelpDrawer -ErrorAction SilentlyContinue) { Sync-HudHelpDrawer }
    if ($ui.orbHost -and $ui.iconHost) {
      try {
        $ui.iconHost.ScrollControlIntoView($ui.orbHost)
      } catch { }
    }
  }

  function Exit-IconLogoModeIfNeeded {
    if (-not $ui.iconLogoMode) { return }
    $ui.iconLogoMode = $false
    if ($ui.orbPanel) { $ui.orbPanel.Visible = $false }
    if (-not $ui.presetMode) {
      if ($ui.iconCard) { $ui.iconCard.Visible = $true }
      if ($ui.iconHost) { $ui.iconHost.Visible = $true }
    }
    Update-LookPresetButtonChrome
  }

  function Update-LookPresetButtonChrome {
    if ($ui.btnPreset) {
      $rawP = if ($ui.presetMode) { Get-HudT 'settings.lookPreset.back' } else { Get-HudT 'settings.lookPreset' }
      $ui.btnPreset.Text = Convert-HudUiUpper $rawP
      if ($ui.btnPreset.Tag -is [hashtable]) {
        $ui.btnPreset.Tag.Primary = $true
        $ui.btnPreset.Tag.AccentGlow = [bool]$ui.presetMode
      }
      $ui.btnPreset.Invalidate()
    }
    if ($ui.btnIconLogo) {
      $rawI = if ($ui.iconLogoMode) { Get-HudT 'settings.iconLogo.back' } else { Get-HudT 'settings.iconLogo' }
      $ui.btnIconLogo.Text = Convert-HudUiUpper $rawI
      if ($ui.btnIconLogo.Tag -is [hashtable]) {
        $ui.btnIconLogo.Tag.Primary = $true
        $ui.btnIconLogo.Tag.AccentGlow = [bool]$ui.iconLogoMode
      }
      $ui.btnIconLogo.Invalidate()
    }
  }

  function Return-ToStartInspector {
    Highlight-Layer 'border'
  }

  function Update-BoxModelMarker {
    $pb = $ui.boxMarker
    if ($null -eq $pb -or $script:fittingBoxMarker) { return }
    if (-not (Get-Command New-HudDialogMarkerBitmap -ErrorAction SilentlyContinue)) { return }
    $script:fittingBoxMarker = $true
    try {
      $ch = 28
      $cw = 80
      if ($ui.pnlContent) {
        $ch = [Math]::Max(18, [int]$ui.pnlContent.ClientSize.Height)
        $cw = [Math]::Max(48, [int]$ui.pnlContent.ClientSize.Width)
      }
      $side = [Math]::Max(18, [Math]::Min(48, ($ch - 6)))
      $side = [Math]::Min($side, [int]($cw * 0.36))
      if ([int]$pb.Width -ne $side) { $pb.Width = $side }
      try { if ($ui.pnlContent) { $pb.BackColor = $ui.pnlContent.BackColor } } catch { }
      $bmp = New-HudDialogMarkerBitmap -Size $side
      if ($null -eq $bmp) { return }
      $old = $pb.Image
      $pb.Image = $bmp
      if ($null -ne $old -and -not [object]::ReferenceEquals($old, $bmp)) {
        try { $old.Dispose() } catch { }
      }
      # Dock-Fill is painted after Dock-Left and, after a second layout, covers the logo.
      $hostW = [Math]::Max($side, [int]$ui.pnlContent.ClientSize.Width)
      $hostH = [Math]::Max($side, [int]$ui.pnlContent.ClientSize.Height)
      $pb.Dock = [System.Windows.Forms.DockStyle]::None
      $pb.SetBounds(0, 0, $side, $hostH)
      if ($ui.lblContent) {
        $ui.lblContent.Dock = [System.Windows.Forms.DockStyle]::None
        $ui.lblContent.SetBounds($side, 0, [Math]::Max(8, ($hostW - $side)), $hostH)
      }
      try { $pb.BringToFront() } catch { }
      try { $pb.Invalidate() } catch { }
    } finally { $script:fittingBoxMarker = $false }
  }

  function Layout-BoxModel {
    # Cap nested chrome so the green content cell always fits one label line (esp. Size L).
    $frameW = if ($ui.boxFrame) { [Math]::Max(80, $ui.boxFrame.ClientSize.Width) } else { 160 }
    $frameH = if ($ui.boxFrame) { [Math]::Max(60, $ui.boxFrame.ClientSize.Height) } else { 120 }
    $maxSide = [Math]::Max(4, [int](($frameW - 56) / 6))
    $maxVert = [Math]::Max(4, [int](($frameH - 28) / 6))
    $cap = [Math]::Min($maxSide, $maxVert)
    $m = [Math]::Max(4, [Math]::Min($cap, [Math]::Min(10, 4 + [int]$script:prefs.margin)))
    $b = [Math]::Max(3, [Math]::Min($cap, [Math]::Min(8, 3 + [int]$script:prefs.borderWidth)))
    $p = [Math]::Max(4, [Math]::Min($cap, [Math]::Min(9, 4 + [int]$script:prefs.padding)))
    $ui.pnlMargin.Padding = New-Object System.Windows.Forms.Padding($m)
    $ui.pnlBorder.Padding = New-Object System.Windows.Forms.Padding($b)
    $ui.pnlPadding.Padding = New-Object System.Windows.Forms.Padding($p)
    if ($ui.presetMode) {
      $tid = [string]$ui.selectedThemeId
      $th = Get-ThemeById $tid
      $name = if ($th -and $th.label) { [string]$th.label } else { Get-HudT 'settings.lookPreset' }
      Fit-BoxModelContentLabel $name
    } else {
      $core = if ($script:lastLabelCore) { [string]$script:lastLabelCore } else { 'Content' }
      Fit-BoxModelContentLabel $core
    }
    Update-BoxModelMarker
  }

  function Update-ScopeHint {
    if ($script:editScope -eq 'global') {
      $ui.lblScopeHint.Text = Get-HudT 'settings.scope.hint.global'
    } else {
      $ui.lblScopeHint.Text = Get-HudT 'settings.scope.hint.project'
    }
  }

  function Apply-SettingsLayout {
    if (-not $ui.pageEinst) { return }
    $cw = [Math]::Max(([int](520 * $scale)), $ui.pageEinst.ClientSize.Width)
    $ch = [Math]::Max(([int](380 * $scale)), $ui.pageEinst.ClientSize.Height)
    $pad = [int](14 * $scale)
    $gap = [int](12 * $scale)

    $ui.pageEinst.SuspendLayout()
    try {
      if ($ui.topBar) {
        $ui.topBar.Left = $pad
        $ui.topBar.Top = $pad
        $ui.topBar.Width = [Math]::Max(([int](400 * $scale)), ($cw - (2 * $pad)))
        if ($script:LayoutTopBarChrome) { & $script:LayoutTopBarChrome }
      }

      $bottomH = [int](48 * $scale)
      if ($ui.bottomBar) {
        $ui.bottomBar.SetBounds($pad, ($ch - $pad - $bottomH), [Math]::Max(([int](400 * $scale)), ($cw - (2 * $pad))), $bottomH)
        $btnY = [Math]::Max(0, [int](($bottomH - $ui.btnClose.Height) / 2))
        if ($btnReset) { $btnReset.Location = New-Object System.Drawing.Point(0, $btnY) }
        if ($ui.btnApply -and $ui.btnClose) {
          $copyClear = [int](26 * $scale)
          $ui.btnClose.Location = New-Object System.Drawing.Point(([Math]::Max(([int](180 * $scale)), ($ui.bottomBar.ClientSize.Width - $ui.btnClose.Width - $copyClear))), $btnY)
          $ui.btnApply.Location = New-Object System.Drawing.Point(($ui.btnClose.Left - $ui.btnApply.Width - ([int](10 * $scale))), $btnY)
        }
      }

      $bodyTop = if ($ui.topBar) { $ui.topBar.Bottom + $gap } else { $pad }
      $bodyBottom = if ($ui.bottomBar) { $ui.bottomBar.Top - $gap } else { ($ch - $pad) }
      $bodyH = [Math]::Max(([int](180 * $scale)), ($bodyBottom - $bodyTop))

      $leftW = [int](248 * $scale)
      if ($ui.leftPane) {
        $ui.leftPane.SetBounds($pad, $bodyTop, $leftW, $bodyH)
        $bPad = [int](16 * $scale)
        if ($ui.lblBox) {
          $ui.lblBox.Location = New-Object System.Drawing.Point($bPad, $bPad)
        }
        $lblBottom = if ($ui.lblBox) { $ui.lblBox.Bottom } else { $bPad }
        $availBoxH = [Math]::Max(([int](150 * $scale)), ($bodyH - $lblBottom - $bPad - ([int](10 * $scale))))
        $miniH = [Math]::Min(([int](88 * $scale)), [Math]::Max(([int](60 * $scale)), [int]($availBoxH * 0.28)))
        $frameMaxH = [Math]::Max(([int](92 * $scale)), ($availBoxH - $miniH - ([int](14 * $scale))))
        $bh = [Math]::Min(([int](164 * $scale)), $frameMaxH)
        $bw = [Math]::Max(([int](140 * $scale)), ($leftW - (2 * $bPad)))
        if ($ui.boxFrame) {
          $ui.boxFrame.SetBounds($bPad, ($lblBottom + ([int](10 * $scale))), $bw, $bh)
          Layout-BoxModel
        }
        if ($ui.miniPreview -and $ui.boxFrame) {
          $ui.miniPreview.SetBounds($bPad, ($ui.boxFrame.Bottom + ([int](14 * $scale))), $bw, $miniH)
        }
      }

      $rx = $pad + $leftW + $gap
      $rw = [Math]::Max(([int](260 * $scale)), ($cw - $rx - $pad))

      if ($ui.iconLogoMode) {
        if ($ui.inspHost) {
          $ui.inspHost.Visible = $false
          $ui.inspHost.Height = 0
        }
        if ($ui.iconCard) {
          $ui.iconCard.Visible = $true
          $ui.iconCard.SetBounds($rx, $bodyTop, $rw, $bodyH)
        }
        if ($ui.iconHost) { $ui.iconHost.Visible = $true }
      } elseif ($ui.presetMode) {
        if ($ui.iconCard) { $ui.iconCard.Visible = $false }
        if ($ui.iconHost) { $ui.iconHost.Visible = $false }
        if ($ui.inspHost) {
          $ui.inspHost.Visible = $true
          $ui.inspHost.SetBounds($rx, $bodyTop, $rw, $bodyH)
          if ($ui.themePanel) {
            $tpPad = [int](14 * $scale)
            $tpTop = if ($ui.lblInsp) { $ui.lblInsp.Bottom + ([int](8 * $scale)) } else { [int](40 * $scale) }
            $ui.themePanel.SetBounds($tpPad, $tpTop, [Math]::Max(80, ($rw - (2 * $tpPad))), [Math]::Max(80, ($bodyH - $tpTop - $tpPad)))
          }
        }
      } else {
        $wantInspH = if ($ui.selectedLayer -eq 'content') { [int](184 * $scale) } else { [int](148 * $scale) }
        $inspH = [Math]::Min($wantInspH, [Math]::Max(([int](116 * $scale)), ($bodyH - ([int](130 * $scale)) - $gap)))
        if ($ui.inspHost) {
          $ui.inspHost.Visible = $true
          $ui.inspHost.SetBounds($rx, $bodyTop, $rw, $inspH)
          if ($ui.lblInspPurpose) {
            $ipPad = [int](16 * $scale)
            $ui.lblInspPurpose.Location = New-Object System.Drawing.Point($ipPad, ([int](106 * $scale)))
            $ui.lblInspPurpose.Size = New-Object System.Drawing.Size([Math]::Max(80, ($rw - (2 * $ipPad))), ([int](32 * $scale)))
          }
        }
        $iconTop = if ($ui.inspHost) { $ui.inspHost.Bottom + $gap } else { $bodyTop }
        $iconH = [Math]::Max(([int](100 * $scale)), ($bodyBottom - $iconTop))
        if ($ui.iconCard) {
          $ui.iconCard.Visible = $true
          $ui.iconCard.SetBounds($rx, $iconTop, $rw, $iconH)
        }
        if ($ui.iconHost) { $ui.iconHost.Visible = $true }
      }

      if ($ui.iconCard -and $ui.iconHost -and $ui.iconCard.Visible) {
        $ui.iconHost.SetBounds(3, 3, [Math]::Max(40, ($ui.iconCard.ClientSize.Width - 6)), [Math]::Max(40, ($ui.iconCard.ClientSize.Height - 6)))
        if ($script:LayoutIconBlock) { & $script:LayoutIconBlock }
      }
    } finally {
      $ui.pageEinst.ResumeLayout($false)
    }
    Render-MiniPreview
  }

  function Set-InspVisible([string]$layer) {
    if ($layer -eq 'preset') {
      Enter-PresetMode
      return
    }
    Exit-PresetModeIfNeeded
    foreach ($c in $ui.inspCtrls) { $c.Visible = $false }
    $show = @()
    switch ($layer) {
      'margin'  { $show = @('lMargin', 'numMargin', 'lblInspPurpose'); $ui.lblInsp.Text = Get-HudT 'settings.inspector.margin' }
      'border'  { $show = @('lBorderC', 'txtBorderC', 'btnBorderC', 'lBorderW', 'numBorderW', 'lblInspPurpose'); $ui.lblInsp.Text = Get-HudT 'settings.inspector.border' }
      'padding' { $show = @('lPad', 'numPad', 'lblInspPurpose'); $ui.lblInsp.Text = Get-HudT 'settings.inspector.padding' }
      default   {
        $show = @('lFont', 'cmbFont', 'lFontSz', 'numFontSz', 'lFill', 'txtFill', 'btnFill', 'lTextC', 'txtTextC', 'btnTextC')
        $ui.lblInsp.Text = Get-HudT 'settings.inspector.content'
      }
    }
    if ($ui.lblInspPurpose) {
      $purposeKey = switch ($layer) {
        'margin'  { 'settings.inspector.margin.purpose' }
        'border'  { 'settings.inspector.border.purpose' }
        'padding' { 'settings.inspector.padding.purpose' }
        default   { 'settings.inspector.content.purpose' }
      }
      $ui.lblInspPurpose.Text = Get-HudT $purposeKey
    }
    foreach ($c in $ui.inspCtrls) {
      if ($show -contains (Get-HudCtrlId $c)) {
        $c.Visible = $true
        $c.BringToFront()
      }
    }
    Apply-SettingsLayout
  }

  function Highlight-Layer([string]$layer) {
    if ($layer -eq 'preset') {
      Enter-PresetMode
      return
    }
    $leavingOverlay = [bool]$ui.presetMode -or [bool]$ui.iconLogoMode
    Exit-PresetModeIfNeeded
    Exit-IconLogoModeIfNeeded
    $ui.selectedLayer = $layer
    $ui.pnlMargin.BackColor = $ui.colMarginDim
    $ui.pnlBorder.BackColor = $ui.colBorderDim
    $ui.pnlPadding.BackColor = $ui.colPaddingDim
    $ui.pnlContent.BackColor = $ui.colContentDim
    switch ($layer) {
      'margin'  { $ui.pnlMargin.BackColor = $ui.colMargin }
      'border'  { $ui.pnlBorder.BackColor = $ui.colBorder }
      'padding' { $ui.pnlPadding.BackColor = $ui.colPadding }
      default   { $ui.pnlContent.BackColor = $ui.colContent }
    }
    Set-InspVisible $layer
    # Critical: push Look-Preset colors into textboxes before any Sync/Leave
    if ($leavingOverlay) { Load-InspectorFromPrefs }
    if (Get-Command Sync-HudHelpDrawer -ErrorAction SilentlyContinue) { Sync-HudHelpDrawer }
    Layout-BoxModel
    if ($ui.presetMode) {
      Update-BoxLookFxImage
    } elseif ($ui.lblContent -and $ui.lblContent.Image) {
      try { $oldBx = $ui.lblContent.Image; $ui.lblContent.Image = $null; $oldBx.Dispose() } catch { }
      try { $ui.lblContent.UseCompatibleTextRendering = $false } catch { }
      try { $ui.lblContent.ForeColor = [System.Drawing.Color]::FromArgb(30, 36, 48) } catch { }
    }
  }

  function Load-InspectorFromPrefs {
    $prevSync = [bool]$ui.syncing
    $ui.syncing = $true
    try {
      $ui.numMargin.Value = [Math]::Max(0, [Math]::Min(24, [decimal][int]$script:prefs.margin))
      $ui.numPad.Value = [Math]::Max(0, [Math]::Min(24, [decimal][int]$script:prefs.padding))
      $ui.numBorderW.Value = [Math]::Max(1, [Math]::Min(8, [decimal][int]$script:prefs.borderWidth))
      $ui.numFontSz.Value = [Math]::Max(8, [Math]::Min(28, [decimal][int]$script:prefs.fontSize))
      $ui.txtBorderC.Text = [string]$script:prefs.borderColor
      $ui.txtFill.Text = [string]$script:prefs.fillColor
      $ui.txtTextC.Text = [string]$script:prefs.textColor
      $ui.txtMarkC.Text = [string]$script:prefs.markerColor
      $ui.txtLogo.Text = Get-HudLogoFieldDisplay ([string]$script:prefs.imagePath)
      $ui.txtLogo.Tag = [string]$script:prefs.imagePath
      if (Get-Command Sync-OrbRadioFromPath -ErrorAction SilentlyContinue) { Sync-OrbRadioFromPath }
      if ($ui.cmbLogoRecent) { Refresh-LogoRecentCombo }
      if ($ui.lblLogoHint -and $script:hasActivationCli) {
        $theme = if ($script:HudTheme) { $script:HudTheme } else { Get-HudTheme }
        $p = [string]$script:prefs.imagePath
        $inRepo = (Get-Command Test-HudLogoInProjectRepo -ErrorAction SilentlyContinue) -and (Test-HudLogoInProjectRepo $p)
        if ($inRepo) {
          $ui.lblLogoHint.Text = Get-HudT 'settings.logo.hint.repo'
          $ui.lblLogoHint.ForeColor = $theme.AccentCyanDim
        } elseif ((Get-Command Test-HudIsUserCustomLogo -ErrorAction SilentlyContinue) -and (Test-HudIsUserCustomLogo $p)) {
          $ui.lblLogoHint.Text = Get-HudT 'settings.logo.hint.custom'
          $ui.lblLogoHint.ForeColor = $theme.AccentCyanDim
        } elseif (-not [string]::IsNullOrWhiteSpace($p) -and (Test-HudPath $p)) {
          $ui.lblLogoHint.Text = Get-HudT 'settings.logo.hint.orb'
          $ui.lblLogoHint.ForeColor = $theme.TextMuted
        } else {
          $ui.lblLogoHint.Text = Get-HudT 'settings.logo.hint.empty'
          $ui.lblLogoHint.ForeColor = $theme.TextMuted
        }
      }
      $fam = [string]$script:prefs.fontFamily
      if ($ui.cmbFont.Items.Contains($fam)) { $ui.cmbFont.SelectedItem = $fam } else { $ui.cmbFont.SelectedIndex = 0 }
      $mode = [string]$script:prefs.markerMode
      if ($ui.cmbMode.Items.Contains($mode)) { $ui.cmbMode.SelectedItem = $mode } else { $ui.cmbMode.SelectedIndex = 0 }
      $pat = [string]$script:prefs.pattern
      if ($ui.cmbPat.Items.Contains($pat)) { $ui.cmbPat.SelectedItem = $pat } else { $ui.cmbPat.SelectedIndex = 0 }
      $script:dlgMarkerEmoji = [string]$script:prefs.markerEmoji
      if ($ui.chkOverwriteLogo) {
        $ov = $false
        try { $ov = [bool]$script:prefs.overwriteCustomLogo } catch { $ov = $false }
        $ui.chkOverwriteLogo.Checked = $ov
      }
      if ($ui.chkAutostart) {
        $ui.chkAutostart.Checked = [bool]$script:prefs.autostart -and (Test-HudFeature 'hud.autostart')
      }
    } finally { $ui.syncing = $prevSync }
  }

  function Sync-FromInspector {
    if ($ui.syncing) { return }
    $script:prefs.margin = [int]$ui.numMargin.Value
    $script:prefs.padding = [int]$ui.numPad.Value
    $script:prefs.borderWidth = [int]$ui.numBorderW.Value
    $script:prefs.fontSize = [int]$ui.numFontSz.Value
    $script:prefs.borderColor = [string]$ui.txtBorderC.Text.Trim()
    $script:prefs.fillColor = [string]$ui.txtFill.Text.Trim()
    $script:prefs.textColor = [string]$ui.txtTextC.Text.Trim()
    $script:prefs.markerColor = [string]$ui.txtMarkC.Text.Trim()
    if ($ui.chkOverwriteLogo) {
      $script:prefs.overwriteCustomLogo = [bool]$ui.chkOverwriteLogo.Checked
    }
    if ($null -ne $ui.cmbFont.SelectedItem) { $script:prefs.fontFamily = [string]$ui.cmbFont.SelectedItem }
    if ($null -ne $ui.cmbMode.SelectedItem) { $script:prefs.markerMode = [string]$ui.cmbMode.SelectedItem }
    if ($null -ne $ui.cmbPat.SelectedItem) { $script:prefs.pattern = [string]$ui.cmbPat.SelectedItem }
    $typedLogo = [string]$ui.txtLogo.Text.Trim()
    $curImg = [string]$script:prefs.imagePath
    $curDisp = Get-HudLogoFieldDisplay $curImg
    if ([string]::IsNullOrWhiteSpace($typedLogo)) {
      if (Test-HudIsUserCustomLogo $curImg) {
        $script:prefs.imagePath = ''
        $script:prefs.logoSourceName = ''
        $ui.txtLogo.Tag = ''
      }
    } elseif ($typedLogo -eq $curDisp -and (Test-HudPath $curImg)) {
      # Unchanged display label — preserve exact $script:prefs.imagePath
    } elseif ([System.IO.Path]::IsPathRooted($typedLogo) -and (Test-HudPath $typedLogo)) {
      $script:prefs.imagePath = [System.IO.Path]::GetFullPath($typedLogo)
      $script:prefs.logoSourceName = [System.IO.Path]::GetFileName($typedLogo)
      $script:prefs.markerMode = 'image'
      $ui.txtLogo.Tag = $script:prefs.imagePath
      Clear-OrbPick
      $ui.syncing = $true
      try { $ui.cmbMode.SelectedItem = 'image' } finally { $ui.syncing = $false }
    } else {
      $resolved = Resolve-HudCustomLogoFromLabel $typedLogo
      if ($resolved) {
        $script:prefs.imagePath = $resolved
        $script:prefs.logoSourceName = Get-HudLogoSourceName $resolved
        if ([string]::IsNullOrWhiteSpace([string]$script:prefs.logoSourceName)) {
          $script:prefs.logoSourceName = $typedLogo
        }
        $script:prefs.markerMode = 'image'
        $ui.txtLogo.Tag = $resolved
        Clear-OrbPick
        $ui.syncing = $true
        try { $ui.cmbMode.SelectedItem = 'image' } finally { $ui.syncing = $false }
      } elseif (Test-HudIsUserCustomLogo $curImg) {
        $script:prefs.logoSourceName = $typedLogo
      }
    }
    if ($ui.chkAutostart) {
      if (Test-HudFeature 'hud.autostart') {
        $script:prefs.autostart = [bool]$ui.chkAutostart.Checked
      } else {
        $script:prefs.autostart = $false
        $ui.chkAutostart.Checked = $false
      }
    }
    if (-not [string]::IsNullOrWhiteSpace($script:dlgMarkerEmoji)) {
      $script:prefs.markerEmoji = $script:dlgMarkerEmoji
    }
    Preview-DialogOnly
  }

  function Refresh-AfterPreset {
    Load-InspectorFromPrefs
    Preview-DialogOnly
  }

  function Paint-BoxFromPrefs {
    $fill = Parse-HexColor ([string]$script:prefs.fillColor)
    if ($null -eq $fill) { $fill = $ui.colContent }
    $border = Parse-HexColor ([string]$script:prefs.borderColor)
    if ($null -eq $border) { $border = $ui.colBorder }
    $mark = Parse-HexColor ([string]$script:prefs.markerColor)
    if ($null -eq $mark) { $mark = $border }
    $ui.pnlMargin.BackColor = $mark
    $ui.pnlBorder.BackColor = $border
    $pad = $fill
    try {
      $pad = [System.Drawing.Color]::FromArgb(
        255,
        [Math]::Min(255, ($fill.R + 36)),
        [Math]::Min(255, ($fill.G + 36)),
        [Math]::Min(255, ($fill.B + 36))
      )
    } catch { }
    $ui.pnlPadding.BackColor = $pad
    $ui.pnlContent.BackColor = $fill
    try { $ui.lblContent.BackColor = $fill } catch { }
    $th = Get-ThemeById ([string]$script:prefs.lookId)
    $name = if ($th -and $th.label) { [string]$th.label } else { 'Content' }
    Fit-BoxModelContentLabel $name
    $tc = Parse-HexColor ([string]$script:prefs.textColor)
    if ($null -ne $tc) { $ui.lblContent.ForeColor = $tc }
    Update-BoxModelMarker
  }

  function Update-SizeButtonChrome {
    if (-not $ui.sizeBtns) { return }
    $cur = [string]$script:prefs.sizePreset
    if ([string]::IsNullOrWhiteSpace($cur)) { $cur = 'M' }
    $cur = $cur.ToUpperInvariant()
    foreach ($btn in @($ui.sizeBtns)) {
      $id = ''
      try { $id = [string](Get-HudMetalButtonPayload $btn) } catch { $id = [string]$btn.Text }
      $on = ($id.ToUpperInvariant() -eq $cur)
      if ($btn.Tag -is [hashtable]) {
        $btn.Tag.Primary = $on
        $btn.Tag.AccentGlow = $on
        $btn.Invalidate()
      } else {
        $btn.BackColor = if ($on) { [System.Drawing.Color]::FromArgb(78, 118, 148) } else { $bgBtn }
      }
    }
  }

  function Show-HudPrefsLoaded([string]$title, [string]$path, $validated) {
    Convert-LegacyLookBundle
    $fixedOrb = Resolve-HudMissingOrbFile ([string]$script:prefs.imagePath)
    if ($fixedOrb) { $script:prefs.imagePath = $fixedOrb }
    Sync-OrbRadioFromPath
    $ui.selectedThemeId = [string]$script:prefs.lookId
    Sync-LookRadios
    Update-FormChips
    Update-SizeButtonChrome
    $script:dlgMarkerEmoji = [string]$script:prefs.markerEmoji
    Refresh-AfterPreset
    Paint-BoxFromPrefs
    $name = [IO.Path]::GetFileName($path)
    $msg = Get-HudT 'settings.prefs.loaded' -Vars @{ name = $name; scope = [string]$script:editScope }
    if ($validated -and $validated.stripped -and @($validated.stripped).Count -gt 0) {
      $msg += "`r`n" + ((@($validated.stripped) -join ', '))
    }
    Suspend-HudSettingsTopMost
    try {
      [System.Windows.Forms.MessageBox]::Show(
        $dlg,
        $msg,
        $title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
      ) | Out-Null
    } finally {
      Resume-HudSettingsTopMost
    }
  }

  function Refresh-LogoRecentCombo {
    if (-not $ui.cmbLogoRecent) { return }
    $prevSync = [bool]$ui.syncing
    $ui.syncing = $true
    try {
      $ui.cmbLogoRecent.Items.Clear()
      [void]$ui.cmbLogoRecent.Items.Add((Get-HudT 'settings.logo.recent.pick'))
      $files = @(Get-HudCustomLogoFiles | Sort-Object LastWriteTime -Descending)
      foreach ($f in $files) {
        $label = Get-HudLogoSourceName ([string]$f.FullName)
        if ([string]::IsNullOrWhiteSpace($label)) { $label = [string]$f.Name }
        [void]$ui.cmbLogoRecent.Items.Add($label)
      }
      $cur = [string]$script:prefs.imagePath
      $idx = 0
      if (Test-HudIsUserCustomLogo $cur) {
        $want = Get-HudLogoFieldDisplay $cur
        $found = $ui.cmbLogoRecent.Items.IndexOf($want)
        if ($found -lt 0) { $found = $ui.cmbLogoRecent.Items.IndexOf([System.IO.Path]::GetFileName($cur)) }
        if ($found -ge 0) { $idx = $found }
      }
      if ($ui.cmbLogoRecent.Items.Count -gt 0) {
        $ui.cmbLogoRecent.SelectedIndex = [Math]::Min($idx, $ui.cmbLogoRecent.Items.Count - 1)
      }
    } finally { $ui.syncing = $prevSync }
  }

  function Apply-LogoRecentSelection {
    if (-not $ui.cmbLogoRecent -or $ui.syncing) { return }
    if ($ui.cmbLogoRecent.SelectedIndex -lt 0) { return }
    $sel = [string]$ui.cmbLogoRecent.SelectedItem
    $path = ''
    if ($ui.cmbLogoRecent.SelectedIndex -eq 0) {
      $newest = @(Get-HudCustomLogoFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
      if ($newest.Count -gt 0 -and $newest[0]) { $path = [string]$newest[0].FullName }
    } elseif (-not [string]::IsNullOrWhiteSpace($sel)) {
      $path = Resolve-HudCustomLogoFromLabel $sel
    }
    if ([string]::IsNullOrWhiteSpace($path)) { return }
    if (-not (Test-HudFeature 'hud.marker.image')) {
      Show-ProUpgradeHint 'Custom-Logo'
      return
    }
    $script:prefs.imagePath = $path
    $script:prefs.logoSourceName = Get-HudLogoSourceName $path
    $ui.txtLogo.Text = Get-HudLogoFieldDisplay $path
    $ui.txtLogo.Tag = $path
    if ($ui.lblLogoHint) {
      $themeHint = if ($script:HudTheme) { $script:HudTheme } else { Get-HudTheme }
      $ui.lblLogoHint.Text = Get-HudT 'settings.logo.hint.custom'
      $ui.lblLogoHint.ForeColor = $themeHint.AccentCyanDim
    }
    $script:prefs.markerMode = 'image'
    Clear-OrbPick
    $ui.syncing = $true
    try { $ui.cmbMode.SelectedItem = 'image' } finally { $ui.syncing = $false }
    Sync-FromInspector
  }

  function Switch-EditScope([string]$scope) {
    if ($scope -ne 'global' -and -not (Test-HudFeature 'hud.scope.project')) {
      $script:editScope = 'global'
      if ($ui.rbGlobal) {
        $ui.syncing = $true
        try { $ui.rbGlobal.Checked = $true } finally { $ui.syncing = $false }
      }
      if ($script:hasActivationCli) { Show-ProUpgradeHint (Get-HudT 'settings.scope.project') }
      return
    }
    Sync-FromInspector
    # stash current dialog edits into memory map only (not disk)
    $script:editScope = $scope
    $script:prefs = Get-PrefsForEdit $scope
    $script:dlgMarkerEmoji = [string]$script:prefs.markerEmoji
    Update-ScopeHint
    Refresh-AfterPreset
  }

  function Render-MiniPreview {
    $pb = $ui.miniPreview
    if ($null -eq $pb) { return }
    # Paint at the preview box size. The live pill is a thin bar; zooming that
    # bitmap hides pattern and logo changes inside a few pixels.
    $w = [Math]::Max(160, [int]$pb.ClientSize.Width)
    $h = [Math]::Max(64, [int]$pb.ClientSize.Height)
    if ($pb.ClientSize.Width -lt 40 -or $pb.ClientSize.Height -lt 24) {
      $w = [int](210 * $scale)
      $h = [int](78 * $scale)
    }
    $fill = Parse-HexColor ([string]$script:prefs.fillColor)
    if ($null -eq $fill) { $fill = [System.Drawing.Color]::FromArgb(22, 28, 38) }
    $bc = Parse-HexColor ([string]$script:prefs.borderColor)
    if ($null -eq $bc) { $bc = $script:accentColor }
    $tc = Parse-HexColor ([string]$script:prefs.textColor)
    if ($null -eq $tc) { $tc = [System.Drawing.Color]::White }
    $fxPrev = ''
    if ((Test-HudFeature 'hud.lookPresets') -and (Get-Command Get-HudLookFxName -ErrorAction SilentlyContinue)) {
      $fxPrev = Get-HudLookFxName ([string]$script:prefs.lookFx)
    }
    $showVer = $false
    try { $showVer = [bool](Test-HudFeature 'hud.chrome.version') } catch { $showVer = $false }
    $band = 12
    try { if ([int]$scopeLabel.Height -gt 0) { $band = [int]$scopeLabel.Height } } catch { }
    $verBand = 0
    $verTxt = ''
    if ($showVer) {
      $verBand = $band
      try { if ([int]$tierLabel.Height -gt 0) { $verBand = [int]$tierLabel.Height } } catch { }
      try { $verTxt = [string]$tierLabel.Text } catch { $verTxt = '' }
      if ([string]::IsNullOrWhiteSpace($verTxt)) {
        $verTxt = 'akc ccc pro'
        try {
          if (Get-Command Get-CccVersion -ErrorAction SilentlyContinue) {
            $verTxt = "akc ccc pro version $(Get-CccVersion)"
          }
        } catch { }
      }
    }
    $scopeTxt = 'Scope: —'
    try {
      if ($scopeLabel -and -not [string]::IsNullOrWhiteSpace([string]$scopeLabel.Text)) {
        $scopeTxt = [string]$scopeLabel.Text
      }
    } catch { }
    $maxBand = [int][Math]::Max(12, [Math]::Floor($h * 0.2))
    if ($verBand -gt $maxBand) { $verBand = $maxBand }
    if ($band -gt $maxBand) { $band = $maxBand }
    $bodyH = [Math]::Max(28, ($h - $verBand - $band))
    $mw = [Math]::Max(28, [Math]::Min(($bodyH - 6), [int][Math]::Round($bodyH * 0.78)))
    $markBmp = $null
    if (Get-Command New-HudDialogMarkerBitmap -ErrorAction SilentlyContinue) {
      $markBmp = New-HudDialogMarkerBitmap -Size $mw
    }
    $rawTxt = if ($script:lastLabelCore) { [string]$script:lastLabelCore } else { 'preview' }
    $fnt = $null
    $fBand = $null
    $ownFnt = $false
    $ownBand = $false
    try { if ($label -and $label.Font) { $fnt = $label.Font } } catch { }
    try { if ($scopeLabel -and $scopeLabel.Font) { $fBand = $scopeLabel.Font } } catch { }
    if ($null -eq $fnt) {
      $fs = [float][Math]::Max(7, [Math]::Min(11, [int]$script:prefs.fontSize * 0.75))
      $famPreview = [string]$script:prefs.fontFamily
      if ([string]::IsNullOrWhiteSpace($famPreview) -or $famPreview -match '(?i)emoji|seguiemj') { $famPreview = 'Segoe UI' }
      try { $fnt = New-Object System.Drawing.Font($famPreview, $fs, [System.Drawing.FontStyle]::Regular) }
      catch { $fnt = New-Object System.Drawing.Font('Segoe UI', $fs, [System.Drawing.FontStyle]::Regular) }
      $ownFnt = $true
    }
    if ($null -eq $fBand) {
      try { $fBand = New-Object System.Drawing.Font('Segoe UI', 6.0, [System.Drawing.FontStyle]::Regular) }
      catch { $fBand = New-Object System.Drawing.Font('Segoe UI', 6.0) }
      $ownBand = $true
    }
    $bmp = $null
    if (Get-Command New-HudLookFxFullBitmap -ErrorAction SilentlyContinue) {
      $bmp = New-HudLookFxFullBitmap -Width $w -Height $h -Fx $fxPrev -Fill $fill -Border $bc -Text $tc `
        -VersionText $verTxt -NameText $rawTxt -ScopeText $scopeTxt -Marker $markBmp `
        -NameFont $fnt -BandFont $fBand -VersionBand $verBand -ScopeBand $band
    }
    if ($null -ne $bmp) {
      # Snapshot pixels before the source logo bitmap is released.
      try {
        $shot = New-Object System.Drawing.Bitmap $bmp.Width, $bmp.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $sg = [System.Drawing.Graphics]::FromImage($shot)
        try { $sg.DrawImage($bmp, 0, 0, $bmp.Width, $bmp.Height); $sg.Flush() } finally { $sg.Dispose() }
        $prevBmp = $bmp
        $bmp = $shot
        $prevBmp.Dispose()
      } catch { }
    }
    if ($null -ne $markBmp) { try { $markBmp.Dispose() } catch { } }
    if ($ownFnt) { try { $fnt.Dispose() } catch { } }
    if ($ownBand) { try { $fBand.Dispose() } catch { } }
    if ($null -eq $bmp) { return }
    if ($pb.Image) { try { $old = $pb.Image; $pb.Image = $null; $old.Dispose() } catch { } }
    $pb.Image = $bmp
    try {
      $oldReg = $pb.Region
      $pb.Region = $null
      if ($null -ne $oldReg) { try { $oldReg.Dispose() } catch { } }
    } catch { }
  }

  function Pick-ColorInto($tb) {
    $cd = New-Object System.Windows.Forms.ColorDialog
    $cd.FullOpen = $true
    $cur = Parse-HexColor ([string]$tb.Text)
    if ($null -ne $cur) { $cd.Color = $cur }
    if ((Invoke-HudOwnedFileDialog -Dialog $cd -Owner $dlg) -eq [System.Windows.Forms.DialogResult]::OK) {
      $tb.Text = Color-ToHex $cd.Color
      Sync-FromInspector
    }
    $cd.Dispose()
  }

  # ===== chrome (Gemini glass / metal) =====
  $th = if ($script:HudTheme) { $script:HudTheme } else { Get-HudTheme }
  if ($null -eq $th) { throw 'CCC HUD theme initialization failed.' }
  $bgBtn = $th.MetalBot
  # Page chrome stays Transparent so every tab shares the same glass paint
  # (Settings used to fill GlassDeep / GlassPanelAlt and looked unlike Help/About).

  # Glass shell. MenuStrip/Dock siblings still overlapped content — use TableLayout
  # with an Absolute menu row so the first content line can never sit under the nav.
  $glass = New-HudMetalGlassHost -Parent $dlg -Theme $th -Scale $scale -Slim

  $menuRowH = [Math]::Max(40, [int](44 * $scale))
  $chromeRoot = New-Object System.Windows.Forms.TableLayoutPanel
  $chromeRoot.Dock = [System.Windows.Forms.DockStyle]::Fill
  $chromeRoot.ColumnCount = 1
  $chromeRoot.RowCount = 2
  $chromeRoot.BackColor = [System.Drawing.Color]::Transparent
  [void]$chromeRoot.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100.0)))
  [void]$chromeRoot.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, [float]$menuRowH)))
  [void]$chromeRoot.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100.0)))
  $glass.Controls.Add($chromeRoot)

  $menuBand = New-Object System.Windows.Forms.Panel
  $menuBand.Dock = [System.Windows.Forms.DockStyle]::Fill
  $menuBand.Margin = New-Object System.Windows.Forms.Padding(0)
  $menuBand.BackColor = $th.MenuBar
  Enable-HudDoubleBuffer -Control $menuBand
  # CSS .ccc-menu-bar metal gradient
  $menuBand.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $r = $s.ClientRectangle
    if ($r.Width -lt 2 -or $r.Height -lt 2) { return }
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
      $r,
      [System.Drawing.Color]::FromArgb(224, 228, 232),
      [System.Drawing.Color]::FromArgb(155, 160, 166),
      [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
    )
    $g.FillRectangle($br, $r)
    $br.Dispose()
    $penHi = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 255, 255, 255), 1)
    $penLo = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 18, 20, 24), 2)
    $g.DrawLine($penHi, 0, 0, $r.Width, 0)
    $g.DrawLine($penLo, 0, ($r.Height - 1), $r.Width, ($r.Height - 1))
    $penHi.Dispose(); $penLo.Dispose()
  })
  $chromeRoot.Controls.Add($menuBand, 0, 0)

  $pages = New-Object System.Windows.Forms.Panel
  $pages.Dock = [System.Windows.Forms.DockStyle]::Fill
  $pages.Margin = New-Object System.Windows.Forms.Padding(0)
  $pages.BackColor = [System.Drawing.Color]::Transparent
  Enable-HudDoubleBuffer -Control $pages
  $chromeRoot.Controls.Add($pages, 0, 1)

  function New-Page {
    $p = New-Object System.Windows.Forms.Panel
    $p.Dock = [System.Windows.Forms.DockStyle]::Fill
    $p.BackColor = [System.Drawing.Color]::Transparent
    $p.Visible = $false
    Enable-HudDoubleBuffer -Control $p
    $pages.Controls.Add($p)
    return $p
  }

  $ui.pageEinst = New-Page
  $ui.pageSpeicher = New-Page
  $ui.pageHilfe = New-Page
  $ui.pageLizenz = New-Page
  $ui.pageAbout = New-Page
  $openOnLicense = $false
  if (Get-Command Test-HudStoredLicenseInvalid -ErrorAction SilentlyContinue) {
    try { $openOnLicense = [bool](Test-HudStoredLicenseInvalid) } catch { $openOnLicense = $false }
  }
  if ($openOnLicense) { $ui.pageLizenz.Visible = $true } else { $ui.pageEinst.Visible = $true }

  # Explicit nav tabs (no MenuStrip — it painted over content and hid page titles)
  $storTabsPath = Join-Path $PSScriptRoot 'winforms-storage-tabs.ps1'
  $showStorageTab = ($script:hasActivationCli -or (Test-HudFeature 'storage.core')) -and (Test-Path -LiteralPath $storTabsPath)
  $navLizenzLabel = if ($script:hasActivationCli) {
    (Get-HudT 'nav.activation')
  } else {
    (Get-HudT 'about.pro.shop')
  }
  $navList = New-Object System.Collections.ArrayList
  [void]$navList.Add(@{ Key = 'einst'; Text = (Get-HudT 'nav.settings'); Ctrl = $null })
  if ($showStorageTab) {
    [void]$navList.Add(@{ Key = 'speicher'; Text = (Get-HudT 'nav.storage'); Ctrl = $null })
  }
  [void]$navList.Add(@{ Key = 'lizenz'; Text = $navLizenzLabel; Ctrl = $null })
  [void]$navList.Add(@{ Key = 'hilfe'; Text = (Get-HudT 'nav.help'); Ctrl = $null })
  [void]$navList.Add(@{ Key = 'about'; Text = (Get-HudT 'nav.about'); Ctrl = $null })
  $navItems = @($navList)
  $ui.navButtons = @{}
  $navX = [int](12 * $scale)
  $navY = [int](6 * $scale)
  $navH = [Math]::Max(28, ($menuRowH - (2 * $navY)))
  foreach ($item in $navItems) {
    $b = New-Object System.Windows.Forms.Button
    $b.UseMnemonic = $false
    $b.Text = $item.Text
    $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $b.FlatAppearance.BorderSize = 0
    $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(40, 0, 0, 0)
    $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(60, 0, 0, 0)
    $b.UseVisualStyleBackColor = $false
    $b.BackColor = [System.Drawing.Color]::Transparent
    $b.ForeColor = $th.MenuText
    $b.Font = New-HudFont 'Segoe UI Semibold' ([float](9 * $scale)) ([System.Drawing.FontStyle]::Bold)
    $b.Height = $navH
    $tw = [System.Windows.Forms.TextRenderer]::MeasureText($item.Text, $b.Font).Width
    $b.Width = [Math]::Max(([int](88 * $scale)), ($tw + ([int](28 * $scale))))
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $b.TabStop = $false
    $b.Location = New-Object System.Drawing.Point($navX, $navY)
    $b.Tag = $item.Key
    $menuBand.Controls.Add($b)
    $ui.navButtons[$item.Key] = $b
    $navX = $b.Right + ([int](4 * $scale))
    $b.Add_Click({
      param($s, $e)
      Show-Page ([string]$s.Tag)
    })
  }

  function Set-HudNavActive([string]$name) {
    foreach ($k in @($ui.navButtons.Keys)) {
      $btn = $ui.navButtons[$k]
      if (-not $btn) { continue }
      $on = ($k -eq $name)
      if ($on) {
        $btn.BackColor = [System.Drawing.Color]::FromArgb(60, 74, 107, 140)
        $btn.ForeColor = [System.Drawing.Color]::White
      } else {
        $btn.BackColor = [System.Drawing.Color]::Transparent
        $menuInk = [System.Drawing.Color]::FromArgb(26, 28, 32)
        if ($script:HudTheme -and ($script:HudTheme.MenuText -is [System.Drawing.Color])) {
          $menuInk = $script:HudTheme.MenuText
        }
        $btn.ForeColor = $menuInk
      }
      $btn.Invalidate()
    }
    $invalidNav = $false
    if (Get-Command Test-HudStoredLicenseInvalid -ErrorAction SilentlyContinue) {
      try { $invalidNav = [bool](Test-HudStoredLicenseInvalid) } catch { $invalidNav = $false }
    }
    foreach ($lockedKey in @('einst', 'speicher')) {
      $lockedBtn = $ui.navButtons[$lockedKey]
      if (-not $lockedBtn) { continue }
      if ($invalidNav) {
        $lockedBtn.ForeColor = [System.Drawing.Color]::FromArgb(128, 132, 138)
        $lockedBtn.Cursor = [System.Windows.Forms.Cursors]::No
      } else {
        $lockedBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
      }
      $lockedBtn.Invalidate()
    }
  }
  $script:SetHudNavActive = { param([string]$n) Set-HudNavActive $n }
  $script:ShowHudSettingsPage = { param([string]$n) Show-Page $n }
  Set-HudNavActive 'einst'

  # Language switcher — always visible in menu bar. Default pref = auto (System GUI).
  $ui.langCodes = @('auto') + @(Get-HudSupportedLangs)
  $langItems = @($ui.langCodes | ForEach-Object { Get-HudLangLabel $_ })
  $cmbLang = New-Object System.Windows.Forms.ComboBox
  $cmbLang.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
  $cmbLang.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $cmbLang.Width = [int](154 * $scale)
  $cmbLang.Font = New-HudFont 'Segoe UI Semibold' ([float](8.5 * $scale))
  $cmbLang.BackColor = [System.Drawing.Color]::FromArgb(214, 218, 222)
  $cmbLang.ForeColor = $th.MenuText
  $cmbLang.IntegralHeight = $false
  $cmbLang.ItemHeight = [Math]::Max(16, [int](18 * $scale))
  [void]$cmbLang.Items.AddRange([string[]]$langItems)
  $cmbLang.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
  $menuBand.Controls.Add($cmbLang)
  $ui.cmbLang = $cmbLang

  $script:LayoutMenuLang = {
    if (-not $ui.cmbLang) { return }
    $padR = [int](10 * $scale)
    $ui.cmbLang.Left = [Math]::Max(([int](8 * $scale)), ($menuBand.ClientSize.Width - $ui.cmbLang.Width - $padR))
    $ui.cmbLang.Top = [Math]::Max(0, [int](($menuBand.ClientSize.Height - $ui.cmbLang.Height) / 2))
    $ui.cmbLang.BringToFront()
  }
  $menuBand.Add_Resize({ if ($script:LayoutMenuLang) { & $script:LayoutMenuLang } })
  & $script:LayoutMenuLang

  $curLangIdx = [Array]::IndexOf([string[]]$ui.langCodes, [string]$langPref)
  if ($curLangIdx -lt 0) { $curLangIdx = 0 }
  $ui.syncing = $true
  try { $ui.cmbLang.SelectedIndex = $curLangIdx } finally { $ui.syncing = $false }

  $ui.cmbLang.Add_SelectedIndexChanged({
    if ($ui.syncing) { return }
    $idx = $ui.cmbLang.SelectedIndex
    if ($idx -lt 0 -or $idx -ge $ui.langCodes.Count) { return }
    $newLang = [string]$ui.langCodes[$idx]
    if ($newLang -eq [string]$script:uiLanguage) { return }
    $script:uiLanguage = $newLang
    if (Get-Command Save-Prefs -ErrorAction SilentlyContinue) { Save-Prefs }
    [void](Initialize-HudI18n $newLang)
    $script:reopenSettingsAfterLang = $true
    $script:settingsOpen = $false
    $dlg.Close()
  })

  # ========== EINSTELLUNGEN (Gemini Glass / Metal cards) ==========
  $__einstInit = if ($script:HudSettingsRoot) {
    Join-Path $script:HudSettingsRoot 'einst\init.ps1'
  } else {
    Join-Path $PSScriptRoot 'settings\einst\init.ps1'
  }
  if (-not (Test-Path -LiteralPath $__einstInit)) {
    throw "settings\einst\init.ps1 missing: $__einstInit"
  }
  . $__einstInit

  function Apply-HudFeatureGatesToUi {
    $allowPat = Test-HudFeature 'hud.marker.pattern'
    $allowImg = Test-HudFeature 'hud.marker.image'
    $allowExport = Test-HudFeature 'hud.prefs.export'
    $allowImport = Test-HudFeature 'hud.prefs.import'
    $allowAuto = Test-HudFeature 'hud.autostart'
    $logoMax = Get-HudNumericLimit 'maxCustomLogos'
    $profMax = Get-HudNumericLimit 'maxSavedPrefsProfiles'
    $logoCount = @(Get-HudCustomLogoFiles).Count
    $profCount = @(Get-HudPrefsProfileFiles).Count
    Set-HudGatedField $ui.cmbPat $allowPat
    Set-HudGatedButton $ui.btnLogo $allowImg $bgBtn
    Set-HudGatedField $ui.txtLogo $allowImg
    if ($ui.cmbLogoRecent) { Set-HudGatedField $ui.cmbLogoRecent $allowImg }
    if ($ui.chkOverwriteLogo) { Set-HudGatedField $ui.chkOverwriteLogo $allowImg }
    foreach ($rb in $ui.orbRadios) { Set-HudGatedField $rb $allowImg }
    Set-HudGatedButton $ui.btnExportPrefs $allowExport $bgBtn
    Set-HudGatedButton $ui.btnImportPrefs $allowImport $bgBtn
    Set-HudGatedButton $ui.btnSaveProfile $allowExport $bgBtn
    Set-HudGatedButton $ui.btnLoadProfile $allowImport $bgBtn
    if ($ui.chkAutostart) {
      Set-HudGatedField $ui.chkAutostart $allowAuto
      if (-not $allowAuto) {
        $ui.chkAutostart.Checked = $false
        $script:prefs.autostart = $false
      }
    }
    if (-not $allowPat -or -not $allowImg -or -not $allowExport -or -not $allowAuto) {
      $ui.lblProIcon.Text = Get-HudT 'settings.pro.line' -Vars @{ logos = $logoCount; logoMax = $logoMax; profiles = $profCount; profMax = $profMax }
    } else {
      $ui.lblProIcon.Text = "Logos $logoCount/$logoMax · Profile $profCount/$profMax"
    }
    # Do not rewrite markerMode in prefs — Free only hides Pro modes at display time.
    if ($script:SetHudNavActive) {
      $cur = if ($script:hudSettingsPage) { [string]$script:hudSettingsPage } else { 'einst' }
      & $script:SetHudNavActive $cur
    }
  }

  # ========== SPEICHER / STORAGE (tabs + ? help drawer — Pro only; stripped in Public) ==========
  if ($showStorageTab -and (Test-Path -LiteralPath $storTabsPath)) {
    . $storTabsPath
  }

  # ========== HILFE / AKTIVIERUNG / ABOUT (settings/* — skip if not shipped) ==========
  foreach ($rel in @('help\init.ps1', 'activation\init.ps1', 'about\init.ps1')) {
    $part = if ($script:HudSettingsRoot) { Join-Path $script:HudSettingsRoot $rel } else { '' }
    if ($part -and (Test-Path -LiteralPath $part)) { . $part }
  }

  # Wire events (skip missing controls — do not abort the dialog)
  $onChange = { Sync-FromInspector }
  if ($null -ne $ui.numMargin) { $ui.numMargin.Add_ValueChanged($onChange) }
  if ($null -ne $ui.numPad) { $ui.numPad.Add_ValueChanged($onChange) }
  if ($null -ne $ui.numBorderW) { $ui.numBorderW.Add_ValueChanged($onChange) }
  if ($null -ne $ui.numFontSz) { $ui.numFontSz.Add_ValueChanged($onChange) }
  if ($null -ne $ui.txtBorderC) { $ui.txtBorderC.Add_Leave($onChange) }
  if ($null -ne $ui.txtFill) { $ui.txtFill.Add_Leave($onChange) }
  if ($null -ne $ui.txtTextC) { $ui.txtTextC.Add_Leave($onChange) }
  if ($null -ne $ui.txtMarkC) { $ui.txtMarkC.Add_Leave($onChange) }
  if ($null -ne $ui.txtLogo) { $ui.txtLogo.Add_Leave($onChange) }
  if ($null -ne $ui.cmbFont) { $ui.cmbFont.Add_SelectionChangeCommitted($onChange) }
  if ($null -ne $ui.cmbMode) { $ui.cmbMode.Add_SelectionChangeCommitted({
    if ($ui.syncing) { return }
    $sel = [string]$ui.cmbMode.SelectedItem
    if ($sel -eq 'pattern' -and -not (Test-HudFeature 'hud.marker.pattern')) {
      Show-ProUpgradeHint 'Muster (Pattern)'
      $ui.syncing = $true
      try { $ui.cmbMode.SelectedItem = 'emoji' } finally { $ui.syncing = $false }
      $script:prefs.markerMode = 'emoji'
      Clear-OrbPick
      Sync-FromInspector
      return
    }
    if ($sel -eq 'image' -and -not (Test-HudFeature 'hud.marker.image')) {
      Show-ProUpgradeHint 'Custom-Logo'
      $ui.syncing = $true
      try { $ui.cmbMode.SelectedItem = 'emoji' } finally { $ui.syncing = $false }
      $script:prefs.markerMode = 'emoji'
      Clear-OrbPick
      Sync-FromInspector
      return
    }
    if ($sel -ne 'image') { Clear-OrbPick }
    Sync-FromInspector
  }) }
  if ($null -ne $ui.cmbPat) { $ui.cmbPat.Add_SelectionChangeCommitted({
    if ($ui.syncing) { return }
    if (-not (Test-HudFeature 'hud.marker.pattern')) {
      Show-ProUpgradeHint 'Muster (Pattern)'
      return
    }
    $script:prefs.markerMode = 'pattern'
    Clear-OrbPick
    $ui.syncing = $true
    try { $ui.cmbMode.SelectedItem = 'pattern' } finally { $ui.syncing = $false }
    Sync-FromInspector
  }) }

  if ($null -ne $btnBorderC) { $btnBorderC.Add_Click({ Pick-ColorInto $ui.txtBorderC }) }
  if ($null -ne $btnFill) { $btnFill.Add_Click({ Pick-ColorInto $ui.txtFill }) }
  if ($null -ne $btnTextC) { $btnTextC.Add_Click({ Pick-ColorInto $ui.txtTextC }) }
  if ($null -ne $btnMarkC) { $btnMarkC.Add_Click({ Pick-ColorInto $ui.txtMarkC }) }

  if ($null -ne $btnLogo) { $btnLogo.Add_Click({
    if (-not (Test-HudFeature 'hud.marker.image')) {
      Show-ProUpgradeHint 'Custom-Logo'
      return
    }
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = 'CCC Logo (PNG/JPG/BMP/GIF/ICO/WebP)|*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.ico;*.webp|Alle|*.*'
    $ofd.Title = 'Logo wählen — PNG/JPG/BMP/GIF/ICO/WebP · max 2 MB · max 2048×2048'
    $initDir = Get-HudLogoBrowseInitialDir
    if (-not [string]::IsNullOrWhiteSpace($initDir) -and (Test-Path -LiteralPath $initDir)) {
      $ofd.InitialDirectory = $initDir
    }
    if ((Invoke-HudOwnedFileDialog -Dialog $ofd -Owner $dlg) -eq [System.Windows.Forms.DialogResult]::OK) {
      $src = [string]$ofd.FileName
      if ([string]::IsNullOrWhiteSpace($src)) { $ofd.Dispose(); return }
      $check = Test-HudLogoAssetFile $src
      if (-not [bool]$check.ok) {
        Show-HudLogoReject $check
        $ofd.Dispose()
        return
      }
      try {
        $stored = ''
        $fromRepo = (Get-Command Test-HudLogoInProjectRepo -ErrorAction SilentlyContinue) -and (Test-HudLogoInProjectRepo $src)
        $alreadyHome = Test-HudPathUnderAssets $src
        if ($fromRepo -or $alreadyHome) {
          $stored = [System.IO.Path]::GetFullPath($src)
        } else {
          if (-not (Test-HudPath $assetsDir)) {
            New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
          }
          $stamp = Get-Date -Format 'yyyyMMddHHmmssfff'
          $stored = Join-Path $assetsDir ("custom-$stamp$([IO.Path]::GetExtension($src))")
          $existing = @(Get-HudCustomLogoFiles)
          if (-not (Test-HudNumericCap 'maxCustomLogos' $existing.Count)) {
            Show-HudCapHint 'Eigene Logos' 'maxCustomLogos' $existing.Count
            $ofd.Dispose()
            return
          }
          Copy-Item -LiteralPath $src -Destination $stored -Force
          Set-HudLogoSourceName ([System.IO.Path]::GetFileName($stored)) ([System.IO.Path]::GetFileName($src))
        }
        try { $script:prefs.logoBrowseDir = [System.IO.Path]::GetDirectoryName($src) } catch { }
        $script:prefs.logoSourceName = [System.IO.Path]::GetFileName($src)
        $script:prefs.imagePath = $stored
        $ui.txtLogo.Text = Get-HudLogoFieldDisplay $stored
        $ui.txtLogo.Tag = $stored
        if ($ui.lblLogoHint) {
          $hintKey = if ($fromRepo) { 'settings.logo.hint.repo' } else { 'settings.logo.hint.custom' }
          $ui.lblLogoHint.Text = Get-HudT $hintKey
          $ui.lblLogoHint.ForeColor = $th.AccentCyanDim
        }
        Refresh-LogoRecentCombo
      } catch {
        [System.Windows.Forms.MessageBox]::Show(
          "Logo konnte nicht übernommen werden: $($_.Exception.Message)",
          'CCC Logo',
          [System.Windows.Forms.MessageBoxButtons]::OK,
          [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        $ofd.Dispose()
        return
      }
      $script:prefs.markerMode = 'image'
      Clear-OrbPick
      $ui.syncing = $true
      try { $ui.cmbMode.SelectedItem = 'image' } finally { $ui.syncing = $false }
      Sync-FromInspector
      if (Get-Command Apply-HudFeatureGatesToUi -ErrorAction SilentlyContinue) { Apply-HudFeatureGatesToUi }
    }
    $ofd.Dispose()
  }) }

  if ($null -ne $ui.cmbLogoRecent) {
    $ui.cmbLogoRecent.Add_SelectionChangeCommitted({
      if ($ui.syncing) { return }
      Apply-LogoRecentSelection
    })
  }

  if ($null -ne $ui.btnExportPrefs) { $ui.btnExportPrefs.Add_Click({
    if (-not (Test-HudFeature 'hud.prefs.export')) {
      Show-ProUpgradeHint 'Prefs exportieren'
      return
    }
    Sync-FromInspector
    $sfd = New-Object System.Windows.Forms.SaveFileDialog
    $sfd.Filter = 'JSON|*.json|Alle|*.*'
    $sfd.Title = 'CCC Prefs exportieren'
    $sfd.FileName = 'ccc-hud-prefs-export.json'
    if ((Invoke-HudOwnedFileDialog -Dialog $sfd -Owner $dlg) -ne [System.Windows.Forms.DialogResult]::OK) {
      $sfd.Dispose(); return
    }
    try {
      $prefsObj = [ordered]@{}
      foreach ($k in @($script:prefs.Keys)) { $prefsObj[$k] = $script:prefs[$k] }
      $payload = [ordered]@{
        format     = 'ccc-hud-prefs'
        version    = 2
        product    = 'ccc'
        cccVersion = [string]$pkgVer
        exportedAt = (Get-Date).ToUniversalTime().ToString('o')
        hudTier    = [string]$script:hudTier
        scope      = [string]$script:editScope
        prefs      = $prefsObj
      }
      ($payload | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $sfd.FileName -Encoding utf8
      if (Get-Command Seal-HudPrefsExportFile -ErrorAction SilentlyContinue) {
        Seal-HudPrefsExportFile ([string]$sfd.FileName)
      }
      if (Get-Command Copy-HudLogoBesidePrefs -ErrorAction SilentlyContinue) {
        Copy-HudLogoBesidePrefs ([string]$sfd.FileName)
      }
    } catch {
      [System.Windows.Forms.MessageBox]::Show(
        "Export fehlgeschlagen: $($_.Exception.Message)",
        'CCC Prefs',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
      ) | Out-Null
    }
    $sfd.Dispose()
  }) }

  if ($null -ne $ui.btnImportPrefs) { $ui.btnImportPrefs.Add_Click({
    if (-not (Test-HudFeature 'hud.prefs.import')) {
      Show-ProUpgradeHint 'Prefs importieren'
      return
    }
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = 'CCC Prefs JSON|*.json|Alle|*.*'
    $ofd.Title = 'CCC Prefs importieren (format ccc-hud-prefs + cccVersion)'
    if ((Invoke-HudOwnedFileDialog -Dialog $ofd -Owner $dlg) -ne [System.Windows.Forms.DialogResult]::OK) {
      $ofd.Dispose(); return
    }
    try {
      $tier = if ($script:hudTier) { [string]$script:hudTier } else { 'none' }
      $validated = Import-HudPrefsFromFile ([string]$ofd.FileName) $tier
      if ($null -eq $validated -or -not [bool]$validated.ok) {
        $detail = if ($validated -and $validated.message) { [string]$validated.message } else { 'Unbekannter Importfehler.' }
        $meta = ''
        if ($validated -and $validated.cccVersion) { $meta += " cccVersion=$($validated.cccVersion)" }
        if ($validated -and $validated.schemaVersion) { $meta += " schema=$($validated.schemaVersion)" }
        if ($validated -and $validated.payload -and $validated.payload.cccVersion) {
          $meta += " cccVersion=$($validated.payload.cccVersion)"
        }
        throw ($detail + $meta).Trim()
      }
      $src = $validated.payload.prefs
      Merge-PrefsInto $script:prefs $src
      $logoBack = ''
      if (Get-Command Install-HudLogoBesidePrefs -ErrorAction SilentlyContinue) {
        $logoBack = Install-HudLogoBesidePrefs ([string]$ofd.FileName) ([string]$script:prefs.imagePath)
      }
      if ($logoBack) { $script:prefs.imagePath = $logoBack }
      Enforce-FreeMarkerPrefs
      if (-not (Test-HudFeature 'hud.autostart')) { $script:prefs.autostart = $false }
      Show-HudPrefsLoaded 'CCC Prefs' ([string]$ofd.FileName) $validated
    } catch {
      Suspend-HudSettingsTopMost
      try {
      [System.Windows.Forms.MessageBox]::Show(
        $dlg,
        "Import fehlgeschlagen: $($_.Exception.Message)",
        'CCC Prefs',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
      ) | Out-Null
      } finally { Resume-HudSettingsTopMost }
    }
    $ofd.Dispose()
  }) }

  if ($null -ne $ui.btnSaveProfile) { $ui.btnSaveProfile.Add_Click({
    if (-not (Test-HudFeature 'hud.prefs.export')) {
      Show-ProUpgradeHint 'Prefs-Profil speichern'
      return
    }
    Sync-FromInspector
    $profilesDir = Join-Path $cursorDir 'ccc-hud-prefs-profiles'
    if (-not (Test-Path -LiteralPath $profilesDir)) {
      New-Item -ItemType Directory -Path $profilesDir -Force | Out-Null
    }
    $sfd = New-Object System.Windows.Forms.SaveFileDialog
    $sfd.InitialDirectory = $profilesDir
    $sfd.Filter = 'CCC Prefs-Profil|*.json|Alle|*.*'
    $sfd.Title = 'Prefs-Profil speichern (zählt gegen Tier-Limit)'
    $sfd.FileName = ('profile-' + (Get-Date -Format 'yyyyMMdd-HHmm') + '.json')
    if ((Invoke-HudOwnedFileDialog -Dialog $sfd -Owner $dlg) -ne [System.Windows.Forms.DialogResult]::OK) {
      $sfd.Dispose(); return
    }
    $dest = [string]$sfd.FileName
    $existing = @(Get-HudPrefsProfileFiles)
    $replacing = Test-Path -LiteralPath $dest
    # If saving outside profiles dir, still count only library profiles for cap;
    # when saving into library, enforce cap.
    $inLibrary = $dest.StartsWith($profilesDir, [System.StringComparison]::OrdinalIgnoreCase)
    if ($inLibrary -and -not (Test-HudNumericCap 'maxSavedPrefsProfiles' $existing.Count -ReplacingExisting:$replacing)) {
      Show-HudCapHint 'Prefs-Profile' 'maxSavedPrefsProfiles' $existing.Count
      $sfd.Dispose()
      return
    }
    try {
      $prefsObj = [ordered]@{}
      foreach ($k in @($script:prefs.Keys)) { $prefsObj[$k] = $script:prefs[$k] }
      $payload = [ordered]@{
        format     = 'ccc-hud-prefs'
        version    = 2
        product    = 'ccc'
        cccVersion = [string]$pkgVer
        profile    = [IO.Path]::GetFileNameWithoutExtension($dest)
        savedAt    = (Get-Date).ToUniversalTime().ToString('o')
        exportedAt = (Get-Date).ToUniversalTime().ToString('o')
        hudTier    = [string]$script:hudTier
        scope      = [string]$script:editScope
        prefs      = $prefsObj
      }
      ($payload | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $dest -Encoding utf8
      if (Get-Command Seal-HudPrefsExportFile -ErrorAction SilentlyContinue) {
        Seal-HudPrefsExportFile $dest
      }
      if (Get-Command Copy-HudLogoBesidePrefs -ErrorAction SilentlyContinue) {
        Copy-HudLogoBesidePrefs $dest
      }
      if (Get-Command Apply-HudFeatureGatesToUi -ErrorAction SilentlyContinue) { Apply-HudFeatureGatesToUi }
    } catch {
      [System.Windows.Forms.MessageBox]::Show(
        "Profil speichern fehlgeschlagen: $($_.Exception.Message)",
        'CCC Prefs',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
      ) | Out-Null
    }
    $sfd.Dispose()
  }) }

  if ($null -ne $ui.btnLoadProfile) { $ui.btnLoadProfile.Add_Click({
    if (-not (Test-HudFeature 'hud.prefs.import')) {
      Show-ProUpgradeHint 'Prefs-Profil laden'
      return
    }
    $profilesDir = Join-Path $cursorDir 'ccc-hud-prefs-profiles'
    if (-not (Test-Path -LiteralPath $profilesDir)) {
      New-Item -ItemType Directory -Path $profilesDir -Force | Out-Null
    }
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.InitialDirectory = $profilesDir
    $ofd.Filter = 'CCC Prefs-Profil|*.json|Alle|*.*'
    $ofd.Title = 'Prefs-Profil laden (format ccc-hud-prefs + cccVersion)'
    if ((Invoke-HudOwnedFileDialog -Dialog $ofd -Owner $dlg) -ne [System.Windows.Forms.DialogResult]::OK) {
      $ofd.Dispose(); return
    }
    try {
      $tier = if ($script:hudTier) { [string]$script:hudTier } else { 'none' }
      $validated = Import-HudPrefsFromFile ([string]$ofd.FileName) $tier
      if ($null -eq $validated -or -not [bool]$validated.ok) {
        $detail = if ($validated -and $validated.message) { [string]$validated.message } else { 'Unbekannter Importfehler.' }
        $meta = ''
        if ($validated -and $validated.cccVersion) { $meta += " cccVersion=$($validated.cccVersion)" }
        if ($validated -and $validated.schemaVersion) { $meta += " schema=$($validated.schemaVersion)" }
        if ($validated -and $validated.payload -and $validated.payload.cccVersion) {
          $meta += " cccVersion=$($validated.payload.cccVersion)"
        }
        throw ($detail + $meta).Trim()
      }
      $src = $validated.payload.prefs
      Merge-PrefsInto $script:prefs $src
      $logoBack = ''
      if (Get-Command Install-HudLogoBesidePrefs -ErrorAction SilentlyContinue) {
        $logoBack = Install-HudLogoBesidePrefs ([string]$ofd.FileName) ([string]$script:prefs.imagePath)
      }
      if ($logoBack) { $script:prefs.imagePath = $logoBack }
      Enforce-FreeMarkerPrefs
      if (-not (Test-HudFeature 'hud.autostart')) { $script:prefs.autostart = $false }
      if (Get-Command Apply-HudFeatureGatesToUi -ErrorAction SilentlyContinue) { Apply-HudFeatureGatesToUi }
      Show-HudPrefsLoaded 'CCC Prefs' ([string]$ofd.FileName) $validated
    } catch {
      Suspend-HudSettingsTopMost
      try {
      [System.Windows.Forms.MessageBox]::Show(
        $dlg,
        "Profil laden fehlgeschlagen: $($_.Exception.Message)",
        'CCC Prefs',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
      ) | Out-Null
      } finally { Resume-HudSettingsTopMost }
    }
    $ofd.Dispose()
  }) }

  if ($null -ne $ui.chkAutostart) { $ui.chkAutostart.Add_CheckedChanged({
    if ($ui.syncing) { return }
    if (-not (Test-HudFeature 'hud.autostart')) {
      if ($ui.chkAutostart.Checked) {
        Show-ProUpgradeHint 'Autostart'
        $ui.syncing = $true
        try { $ui.chkAutostart.Checked = $false } finally { $ui.syncing = $false }
      }
      $script:prefs.autostart = $false
      return
    }
    $script:prefs.autostart = [bool]$ui.chkAutostart.Checked
  }) }

  if ($null -ne $ui.chkZebraConsent) { $ui.chkZebraConsent.Add_CheckedChanged({
    if ($ui.syncing) { return }
    $hudRoot = if ($script:HudScriptRoot) { [string]$script:HudScriptRoot } else { Split-Path $PSScriptRoot -Parent }
    $cli = Join-Path $hudRoot 'ccc-zebra-update-check.mjs'
    if ($ui.chkZebraConsent.Checked) {
      if ((Get-Command Test-HudZebraNetworkConsent -ErrorAction SilentlyContinue) -and (Test-HudZebraNetworkConsent)) { return }
      $accepted = $false
      if (Get-Command Show-HudZebraNetworkConsentDialog -ErrorAction SilentlyContinue) {
        $accepted = [bool](Show-HudZebraNetworkConsentDialog -Owner $dlg)
      }
      if (-not $accepted) {
        $ui.syncing = $true
        try { $ui.chkZebraConsent.Checked = $false } finally { $ui.syncing = $false }
        return
      }
      if (Get-Command Grant-HudZebraNetworkConsent -ErrorAction SilentlyContinue) { Grant-HudZebraNetworkConsent }
      if (Test-Path -LiteralPath $cli) { & node $cli --grant-consent 2>$null | Out-Null }
    } else {
      if (Get-Command Revoke-HudZebraNetworkConsent -ErrorAction SilentlyContinue) { Revoke-HudZebraNetworkConsent }
      if (Test-Path -LiteralPath $cli) { & node $cli --revoke-consent 2>$null | Out-Null }
    }
  }) }

  if ($null -ne $btnReset) { $btnReset.Add_Click({
    foreach ($k in @($script:defaultPrefs.Keys)) { $script:prefs[$k] = $script:defaultPrefs[$k] }
    Clear-OrbPick
    $script:dlgMarkerEmoji = [string]$script:prefs.markerEmoji
    Refresh-AfterPreset
  }) }

  if ($null -ne $btnApply) { $btnApply.Add_Click({
    Commit-DialogPrefsToPill
  }) }

  if ($null -ne $btnClose) { $btnClose.Add_Click({
    if (-not $ui.applied) {
      $script:editScope = $script:scopeSnapshot
      $script:prefs = Get-EffectivePrefs $script:currentWorkspaceId
      $script:forceVisual = $true
      Apply-PrefsVisual
      Apply-StateFile -FromSettingsCommit
    } elseif ($script:editScope -eq 'global') {
      $script:prefs = Get-EffectivePrefs $script:currentWorkspaceId
      $script:forceVisual = $true
      Apply-PrefsVisual
      Apply-StateFile -FromSettingsCommit
    }
    $dlg.Close()
  }) }

  $dlg.Add_FormClosed({
    try {
      if ($script:HudAsyncNodeTimer) {
        $script:HudAsyncNodeTimer.Stop()
        $script:HudAsyncNodeTimer.Dispose()
        $script:HudAsyncNodeTimer = $null
      }
      if ($script:HudAsyncNodeProc) {
        try {
          if ($script:HudAsyncNodeProc.Proc -and -not $script:HudAsyncNodeProc.Proc.HasExited) {
            $script:HudAsyncNodeProc.Proc.Kill()
          }
        } catch { }
        $script:HudAsyncNodeProc = $null
      }
      if (Get-Command Stop-HudScrollPageLayouts -ErrorAction SilentlyContinue) { Stop-HudScrollPageLayouts }
      $script:LayoutAboutPage = $null
      $script:RequestAboutLayout = $null
      if ($script:ActivationLayoutTimer) {
        try { $script:ActivationLayoutTimer.Stop(); $script:ActivationLayoutTimer.Dispose() } catch { }
        $script:ActivationLayoutTimer = $null
      }
    } catch { }
    $wasApplied = [bool]$ui.applied
    $closedScope = [string]$script:editScope
    $script:settingsOpen = $false
    $script:settingsDlg = $null
    if (-not $wasApplied) {
      $script:editScope = $script:scopeSnapshot
      $script:prefs = Get-EffectivePrefs $script:currentWorkspaceId
      $script:forceVisual = $true
      try { Apply-PrefsVisual } catch { }
      try { Apply-StateFile } catch { }
    } elseif ($closedScope -eq 'global') {
      $script:prefs = Get-EffectivePrefs $script:currentWorkspaceId
      $script:forceVisual = $true
      try { Apply-PrefsVisual } catch { }
      try { Apply-StateFile } catch { }
    }
    if (Get-Command Set-HudTickInterval -ErrorAction SilentlyContinue) {
      try { Set-HudTickInterval 400 } catch { }
    }
    if ($ui.miniPreview -and $ui.miniPreview.Image) {
      try { $old = $ui.miniPreview.Image; $ui.miniPreview.Image = $null; $old.Dispose() } catch { }
    }
    if ($ui.boxMarker -and $ui.boxMarker.Image) {
      try { $oldMk = $ui.boxMarker.Image; $ui.boxMarker.Image = $null; $oldMk.Dispose() } catch { }
    }
    foreach ($img in @($ui.themeArtImages)) {
      try { if ($null -ne $img) { $img.Dispose() } } catch { }
    }
    if ($ui.aboutLogoImage) {
      try { $ui.aboutLogoImage.Dispose() } catch { }
      $ui.aboutLogoImage = $null
    }
  })

  $dlg.Add_Resize({ Apply-SettingsLayout })

  $dlg.Add_Shown({
    try {
    $page = [string]$script:settingsStartPage
    if ([string]::IsNullOrWhiteSpace($page)) { $page = 'einst' }
    Show-Page $page
    Apply-SettingsLayout
    Refresh-HudGate
    if ($ui.lblDhVal -and $script:deviceHashShort) { $ui.lblDhVal.Text = [string]$script:deviceHashShort }
    Apply-HudFeatureGatesToUi
    Enforce-FreeMarkerPrefs
    Load-InspectorFromPrefs
    Layout-BoxModel
    Highlight-Layer 'border'
    Render-MiniPreview
    Update-ScopeHint
    # Do not Apply-PrefsVisual here: the pill is already laid out. A rebuild while
    # the form is hidden/parked resets marker/label (name under the orb).
    try {
      [void]$dlg.BeginInvoke([System.Windows.Forms.MethodInvoker]{
        Apply-SettingsLayout
        if ($page -eq 'lizenz' -and $script:FocusHudActivationToken) {
          try { & $script:FocusHudActivationToken } catch { }
        }
      })
    } catch { Apply-SettingsLayout }
    } catch { }
  })

  if (Get-Command Add-HudScopeCopyChrome -ErrorAction SilentlyContinue) { Add-HudScopeCopyChrome }
  # Keep $pages Transparent over New-HudMetalGlassHost; each page / scroll surface paints the shared 3-stop glass gradient.
  if (Get-Command Set-HudSolidType -ErrorAction SilentlyContinue) { Set-HudSolidType $dlg }
  $script:lastSettingsOpenTick = [Environment]::TickCount64
  # ShowDialog(null) owners GetActiveWindow() = Cursor Agents, so Settings
  # opens behind the IDE. Park on a hidden unowned form instead of the pill.
  $park = New-Object System.Windows.Forms.Form
  $script:settingsParkForm = $park
  $park.ShowInTaskbar = $false
  $park.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
  $park.Size = New-Object System.Drawing.Size(1, 1)
  $park.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
  $park.Location = New-Object System.Drawing.Point(-32000, -32000)
  $park.Opacity = 0
  [void]$park.Show()
  try { [CccHudWin]::ShowUnownedTopMost($park.Handle) } catch { }
  # Keep the pill visible and laid out. Hiding it (Opacity 0 / -32000) plus
  # ShowDialog's layout pass is what put the name under the logo after close.
  try {
    [void]$dlg.ShowDialog($park)
  } finally {
    try { $park.Close(); $park.Dispose() } catch { }
    $script:settingsParkForm = $null
  }
  try { $dlg.Dispose() } catch { }
  } catch {
    if (Get-Command Show-HudSettingsFailed -ErrorAction SilentlyContinue) {
      Show-HudSettingsFailed $_
    } else {
      $msg = $_.Exception.Message
      if ([string]::IsNullOrWhiteSpace($msg)) { $msg = [string]$_ }
      try {
        [void][System.Windows.Forms.MessageBox]::Show(
          ("CCC HUD settings failed:`n$msg"),
          'AI Keep Clean CCC',
          [System.Windows.Forms.MessageBoxButtons]::OK,
          [System.Windows.Forms.MessageBoxIcon]::Warning
        )
      } catch { }
    }
  } finally {
    $script:settingsOpen = $false
    $script:settingsDlg = $null
    $script:FocusHudActivationToken = $null
  }
  if ($script:reopenSettingsAfterLang) {
    $script:reopenSettingsAfterLang = $false
    Show-SettingsPanel
  }
}
