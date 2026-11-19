# Copyright (c) 2026 ready-4-it
# About controls (children of $aboutPad).

  $picLogo = New-Object System.Windows.Forms.PictureBox
  $picLogo.Size = New-Object System.Drawing.Size(([int](96 * $scale)), ([int](96 * $scale)))
  $picLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
  $picLogo.BackColor = [System.Drawing.Color]::Transparent
  $hudRoot = if ($script:HudScriptRoot) { [string]$script:HudScriptRoot } else { Split-Path $PSScriptRoot -Parent }
  $logoPath = Get-CccAboutLogoPath -HudScriptRoot $hudRoot
  if ($logoPath) {
    try {
      $bytes = [System.IO.File]::ReadAllBytes($logoPath)
      $ms = New-Object System.IO.MemoryStream(,$bytes)
      $picLogo.Image = [System.Drawing.Image]::FromStream($ms)
      $ui.aboutLogoImage = $picLogo.Image
    } catch { }
  }
  $aboutPad.Controls.Add($picLogo)

  $lblBrand = New-HudLabel -Text (Get-HudT 'about.brand') -Fore $th.TextPrimary -Font (New-HudFont 'Segoe UI Semibold' ([float](20 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
  $aboutPad.Controls.Add($lblBrand)

  $secProduct = New-HudSectionPanel -X 0 -Y 0 -Width ([int](520 * $scale)) -Height ([int](168 * $scale)) -Theme $th
  $aboutPad.Controls.Add($secProduct)

  $lblProduct = New-HudLabel -Text (Get-HudT 'about.product') -Fore $th.AccentCyan -Font (New-HudFont 'Segoe UI Semibold' ([float](11 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
  $secProduct.Controls.Add($lblProduct)

  $lblMeta = New-HudLabel -Text (Get-HudT 'about.meta' -Vars @{ version = $pkgVer; edition = $editionLabel; host = $hostLabel }) -Fore $th.AccentCyanDim -Font (New-HudFont 'Segoe UI' ([float](9 * $scale))) -AutoSize
  $secProduct.Controls.Add($lblMeta)

  $lblUpdate = New-HudLabel -Text (Get-HudT 'about.update') -Fore $th.TextPrimary -Font (New-HudFont 'Segoe UI' ([float](9 * $scale)))
  $lblUpdate.AutoSize = $false
  $secProduct.Controls.Add($lblUpdate)

  $btnAboutUpdate = New-HudMetalButton -Text (Get-HudT 'about.update.check') -Width ([int](200 * $scale)) -Height ([int](36 * $scale)) -Theme $th -AccentGlow
  $secProduct.Controls.Add($btnAboutUpdate)
  $ui.chkZebraConsent = New-Object System.Windows.Forms.CheckBox
  $ui.chkZebraConsent.Text = Get-HudT 'settings.zebra.consent'
  $ui.chkZebraConsent.AutoSize = $true
  $ui.chkZebraConsent.BackColor = [System.Drawing.Color]::Transparent
  $ui.chkZebraConsent.ForeColor = $th.TextPrimary
  $ui.chkZebraConsent.Font = New-HudFont 'Segoe UI' ([float](9 * $scale))
  $ui.chkZebraConsent.Checked = (Get-Command Test-HudZebraNetworkConsent -ErrorAction SilentlyContinue) -and (Test-HudZebraNetworkConsent)
  $secProduct.Controls.Add($ui.chkZebraConsent)

  . (Join-Path $PSScriptRoot 'update-wire.ps1')

  $secPro = New-HudSectionPanel -X 0 -Y 0 -Width ([int](520 * $scale)) -Height ([int](104 * $scale)) -Theme $th
  $aboutPad.Controls.Add($secPro)

  $lblProHead = New-HudLabel -Text (Get-HudT 'about.pro.title') -Fore $th.ProGold -Font (New-HudFont 'Segoe UI Semibold' ([float](11 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
  $secPro.Controls.Add($lblProHead)

  $lblProBody = New-HudLabel -Text (Get-HudT 'about.pro.body') -Fore $th.TextPrimary -Font (New-HudFont 'Segoe UI' ([float](9 * $scale)))
  $lblProBody.AutoSize = $false
  $secPro.Controls.Add($lblProBody)

  $lnkPro = New-Object System.Windows.Forms.LinkLabel
  $lnkPro.AutoSize = $true
  $lnkPro.BackColor = [System.Drawing.Color]::Transparent
  $lnkPro.LinkColor = $th.AccentCyan
  $lnkPro.ActiveLinkColor = $th.TextPrimary
  $lnkPro.VisitedLinkColor = $th.AccentCyan
  $lnkPro.Font = New-HudFont 'Segoe UI' ([float](9.5 * $scale))
  $lnkPro.Text = $proUrl
  $lnkPro.Tag = $proUrl
  $lnkPro.Add_LinkClicked({
    param($s, $e)
    $u = [string]$s.Tag
    if ([string]::IsNullOrWhiteSpace($u)) { $u = 'https://www.ready-4-it.com/akc_ccc' }
    try { Start-Process $u } catch { }
  })
  $secPro.Controls.Add($lnkPro)

  $termsUrl = 'https://www.streamingzebra.com/terms'
  $privacyUrl = 'https://www.ready-4-it.com/privacy'

  $secLegal = New-HudSectionPanel -X 0 -Y 0 -Width ([int](520 * $scale)) -Height ([int](140 * $scale)) -Theme $th
  $aboutPad.Controls.Add($secLegal)

  $lblLegalHead = New-HudLabel -Text (Get-HudT 'about.legal.title') -Fore $th.AccentCyan -Font (New-HudFont 'Segoe UI Semibold' ([float](11 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
  $secLegal.Controls.Add($lblLegalHead)

  $lblFreeware = New-HudLabel -Text (Get-HudT 'about.freeware.notice') -Fore $th.TextPrimary -Font (New-HudFont 'Segoe UI' ([float](9 * $scale)))
  $lblFreeware.AutoSize = $false
  $secLegal.Controls.Add($lblFreeware)

  $lnkTerms = New-Object System.Windows.Forms.LinkLabel
  $lnkTerms.AutoSize = $true
  $lnkTerms.BackColor = [System.Drawing.Color]::Transparent
  $lnkTerms.LinkColor = $th.AccentCyan
  $lnkTerms.ActiveLinkColor = $th.TextPrimary
  $lnkTerms.VisitedLinkColor = $th.AccentCyan
  $lnkTerms.Font = New-HudFont 'Segoe UI' ([float](9 * $scale))
  $lnkTerms.Text = (Get-HudT 'about.legal.terms')
  $lnkTerms.Tag = $termsUrl
  $lnkTerms.Add_LinkClicked({
    param($s, $e)
    try { Start-Process ([string]$s.Tag) } catch { }
  })
  $secLegal.Controls.Add($lnkTerms)

  $lnkPrivacy = New-Object System.Windows.Forms.LinkLabel
  $lnkPrivacy.AutoSize = $true
  $lnkPrivacy.BackColor = [System.Drawing.Color]::Transparent
  $lnkPrivacy.LinkColor = $th.AccentCyan
  $lnkPrivacy.ActiveLinkColor = $th.TextPrimary
  $lnkPrivacy.VisitedLinkColor = $th.AccentCyan
  $lnkPrivacy.Font = New-HudFont 'Segoe UI' ([float](9 * $scale))
  $lnkPrivacy.Text = (Get-HudT 'about.legal.privacy')
  $lnkPrivacy.Tag = $privacyUrl
  $lnkPrivacy.Add_LinkClicked({
    param($s, $e)
    try { Start-Process ([string]$s.Tag) } catch { }
  })
  $secLegal.Controls.Add($lnkPrivacy)

  $lblLegalMark = New-HudLabel -Text (Get-HudT 'about.legal.trademark') -Fore $th.TextMuted -Font (New-HudFont 'Segoe UI' ([float](8 * $scale)))
  $lblLegalMark.AutoSize = $false
  $secLegal.Controls.Add($lblLegalMark)

  $lblFoot = New-HudLabel -Text (Get-HudT 'about.footer') -Fore $th.TextMuted -Font (New-HudFont 'Segoe UI' ([float](8 * $scale))) -AutoSize
  $aboutPad.Controls.Add($lblFoot)

  $lblBuild = New-HudLabel -Text ("HUD build {0} · {1}" -f $hudBuildLabel, $hudSourceTag) -Fore $th.TextMuted -Font (New-HudFont 'Consolas' ([float](8 * $scale))) -AutoSize
  $aboutPad.Controls.Add($lblBuild)
