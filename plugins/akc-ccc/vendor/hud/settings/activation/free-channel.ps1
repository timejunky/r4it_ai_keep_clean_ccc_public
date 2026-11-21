# Copyright (c) 2026 ready-4-it
# Free Marketplace activation stub (shop CTA only).

$shopPad = [int](20 * $scale)
$secShop = New-HudSectionPanel -X $shopPad -Y ([int](24 * $scale)) -Width ([int](720 * $scale)) -Height ([int](140 * $scale)) -Theme $th
$licPad.Controls.Add($secShop)
$lblShopTitle = New-HudLabel -Text (Get-HudT 'about.pro.title') -Fore $th.ProGold -Font (New-HudFont 'Segoe UI Semibold' ([float](13 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
$lblShopTitle.Location = New-Object System.Drawing.Point($shopPad, $shopPad)
$secShop.Controls.Add($lblShopTitle)
$lblShopBody = New-HudLabel -Text (Get-HudT 'about.pro.body') -Fore $th.TextPrimary -Font (New-HudFont 'Segoe UI' ([float](9 * $scale)))
$lblShopBody.AutoSize = $false
$lblShopBody.Location = New-Object System.Drawing.Point($shopPad, ($lblShopTitle.Bottom + ([int](10 * $scale))))
$lblShopBody.Size = New-Object System.Drawing.Size(([int](680 * $scale)), ([int](44 * $scale)))
$secShop.Controls.Add($lblShopBody)
$lnkShopOnly = New-Object System.Windows.Forms.LinkLabel
$lnkShopOnly.AutoSize = $true
$lnkShopOnly.BackColor = [System.Drawing.Color]::Transparent
$lnkShopOnly.LinkColor = $th.AccentCyan
$lnkShopOnly.ActiveLinkColor = $th.TextPrimary
$lnkShopOnly.VisitedLinkColor = $th.AccentCyan
$lnkShopOnly.Font = New-HudFont 'Segoe UI' ([float](9.5 * $scale))
$lnkShopOnly.Text = 'https://www.ready-4-it.com/akc_ccc'
$lnkShopOnly.Location = New-Object System.Drawing.Point($shopPad, ($lblShopBody.Bottom + ([int](8 * $scale))))
$lnkShopOnly.Add_LinkClicked({
  try { Start-Process 'https://www.ready-4-it.com/akc_ccc' } catch { }
})
$secShop.Controls.Add($lnkShopOnly)
$secShop.Height = $lnkShopOnly.Bottom + $shopPad

# Read-only device hash for website activation (same ccc-hud-device.json as Pro + VSIX; no license input)
if ([string]::IsNullOrWhiteSpace($script:deviceHash) -and (Get-Command Refresh-CccDeviceHash -ErrorAction SilentlyContinue)) {
  Refresh-CccDeviceHash
}
$gap = [int](16 * $scale)
$secW = [int](720 * $scale)
$secDevice = New-HudSectionPanel -X $shopPad -Y ($secShop.Bottom + $gap) -Width $secW -Height ([int](130 * $scale)) -Theme $th
$licPad.Controls.Add($secDevice)

$lblDh = New-HudLabel -Text (Get-HudT 'activation.hash') -Fore $th.TextPrimary -Font (New-HudFont 'Segoe UI Semibold' ([float](10 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
$lblDh.Location = New-Object System.Drawing.Point($shopPad, $shopPad)
$secDevice.Controls.Add($lblDh)

$dhFull = if ($script:deviceHash) { [string]$script:deviceHash } elseif ($script:deviceHashShort) { [string]$script:deviceHashShort } else { "($(Get-HudT 'common.ellipsis'))" }
$txtFreeDh = New-HudTextBox -Width ($secW - 2 * $shopPad) -Theme $th -Scale $scale
$txtFreeDh.ReadOnly = $true
$txtFreeDh.Font = New-HudFont 'Consolas' ([float](9 * $scale))
$txtFreeDh.ForeColor = $th.AccentCyan
$txtFreeDh.Text = $dhFull
$txtFreeDh.Location = New-Object System.Drawing.Point($shopPad, ($lblDh.Bottom + ([int](8 * $scale))))
$secDevice.Controls.Add($txtFreeDh)

$copyLabel = if ($script:hudLang -eq 'de') { 'Geräte-Hash kopieren' } else { 'Copy device hash' }
$copiedLabel = if ($script:hudLang -eq 'de') { 'Kopiert.' } else { 'Copied.' }
$btnFreeCopyDh = New-FlatBtn $copyLabel ([int](200 * $scale)) ([int](32 * $scale)) $bgBtn
$btnFreeCopyDh.Location = New-Object System.Drawing.Point($shopPad, ($txtFreeDh.Bottom + ([int](10 * $scale))))
$secDevice.Controls.Add($btnFreeCopyDh)

$btnFreeOpenAct = New-FlatBtn (Get-HudT 'activation.openOnline') ([int](220 * $scale)) ([int](32 * $scale)) ([System.Drawing.Color]::FromArgb(70, 90, 140))
$btnFreeOpenAct.Location = New-Object System.Drawing.Point(($btnFreeCopyDh.Right + ([int](10 * $scale))), $btnFreeCopyDh.Top)
$secDevice.Controls.Add($btnFreeOpenAct)

$lblFreeDhCopied = New-HudLabel -Text '' -Fore $th.AccentCyan -Font (New-HudFont 'Segoe UI' ([float](9 * $scale))) -AutoSize
$lblFreeDhCopied.Location = New-Object System.Drawing.Point(($btnFreeOpenAct.Right + ([int](12 * $scale))), ($btnFreeCopyDh.Top + ([int](7 * $scale))))
$secDevice.Controls.Add($lblFreeDhCopied)

$btnFreeCopyDh.Add_Click({
  $val = [string]$script:deviceHash
  if ([string]::IsNullOrWhiteSpace($val)) { $val = [string]$txtFreeDh.Text }
  if (-not [string]::IsNullOrWhiteSpace($val) -and -not $val.StartsWith('(')) {
    try {
      [System.Windows.Forms.Clipboard]::SetText($val)
      $lblFreeDhCopied.Text = $copiedLabel
    } catch { }
  }
}.GetNewClosure())

$btnFreeOpenAct.Add_Click({
  $val = [string]$script:deviceHash
  if ([string]::IsNullOrWhiteSpace($val)) { $val = [string]$txtFreeDh.Text }
  $langSeg = if ($script:hudLang -eq 'de') { 'de' } else { 'en' }
  $u = if (-not [string]::IsNullOrWhiteSpace($val) -and -not $val.StartsWith('(')) {
    "https://www.ready-4-it.com/$langSeg/license/activate#dh=$([Uri]::EscapeDataString($val))&p=ccc"
  } else {
    "https://www.ready-4-it.com/$langSeg/license/activate#p=ccc"
  }
  try { Start-Process $u } catch { }
}.GetNewClosure())

$secDevice.Height = $btnFreeCopyDh.Bottom + $shopPad
$script:LayoutActivationPage = { }
