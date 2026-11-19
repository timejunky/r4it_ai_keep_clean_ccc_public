# Copyright (c) 2026 ready-4-it
# About layout — flat aboutPad closure (0.2.34) + AutoScrollMinSize for glass scroll extent.

  $script:LayoutAboutPage = {
    if (-not $ui.pageAbout.Visible) { return }
    $padX = [int](20 * $scale)
    $padTop = [int](24 * $scale)
    $padBottom = [int](32 * $scale)
    $gapY = [int](16 * $scale)
    $innerPad = [int](20 * $scale)
    $textPad = [int](6 * $scale)
    $w = Get-HudStableContentWidth -ScrollParent $aboutPad -HorizontalPad (2 * $padX) -MinWidth ([int](520 * $scale))

    $relayout = $script:AboutLayoutForce -or ($script:AboutLayoutW -ne $w)
    if (-not $relayout) { return }
    $script:AboutLayoutForce = $false
    $script:AboutLayoutW = $w

    $aboutPad.SuspendLayout()
    try {
      $x = $padX
      $y = $padTop
      $iw = $w - (2 * $innerPad)
      $cx = $x + [int]($w / 2)

      $picLogo.Left = $cx - [int]($picLogo.Width / 2)
      $picLogo.Top = $y
      $y = $picLogo.Bottom + ([int](10 * $scale))

      $lblBrand.Left = $cx - [int]($lblBrand.PreferredWidth / 2)
      $lblBrand.Top = $y
      $y = $lblBrand.Bottom + $gapY

      foreach ($sec in @($secProduct, $secPro, $secLegal)) {
        $sec.Left = $x
        $sec.Width = $w
      }

      $secProduct.Top = $y
      $lblProduct.Location = New-Object System.Drawing.Point($innerPad, $innerPad)
      $lblMeta.Location = New-Object System.Drawing.Point($innerPad, ($lblProduct.Bottom + ([int](8 * $scale))))
      $lblUpdate.Location = New-Object System.Drawing.Point($innerPad, ($lblMeta.Bottom + ([int](12 * $scale))))
      $lblUpdate.Size = New-Object System.Drawing.Size($iw, ((Measure-HudWrap -Text $lblUpdate.Text -Font $lblUpdate.Font -MaxWidth $iw) + $textPad))
      $btnAboutUpdate.Left = $innerPad
      $btnAboutUpdate.Top = $lblUpdate.Bottom + ([int](14 * $scale))
      $secBottom = $btnAboutUpdate.Bottom
      if ($ui.chkZebraConsent) {
        $ui.chkZebraConsent.MaximumSize = New-Object System.Drawing.Size($iw, 0)
        $ui.chkZebraConsent.Location = New-Object System.Drawing.Point($innerPad, ($btnAboutUpdate.Bottom + ([int](10 * $scale))))
        $secBottom = $ui.chkZebraConsent.Bottom
      }
      $secProduct.Height = $secBottom + $innerPad
      $y = $secProduct.Bottom + $gapY

      $secPro.Top = $y
      $lblProHead.Location = New-Object System.Drawing.Point($innerPad, $innerPad)
      $lblProBody.AutoSize = $true
      $lblProBody.MaximumSize = New-Object System.Drawing.Size($iw, 0)
      $lblProBody.Location = New-Object System.Drawing.Point($innerPad, ($lblProHead.Bottom + ([int](10 * $scale))))
      $lnkPro.Left = $innerPad
      $lnkPro.Top = $lblProBody.Bottom + ([int](10 * $scale))
      $secPro.Height = $lnkPro.Bottom + $innerPad
      $y = $secPro.Bottom + $gapY

      $secLegal.Top = $y
      $lblLegalHead.Location = New-Object System.Drawing.Point($innerPad, $innerPad)
      $lblFreeware.Location = New-Object System.Drawing.Point($innerPad, ($lblLegalHead.Bottom + ([int](10 * $scale))))
      $lblFreeware.Size = New-Object System.Drawing.Size($iw, ((Measure-HudWrap -Text $lblFreeware.Text -Font $lblFreeware.Font -MaxWidth $iw) + $textPad))
      $lnkTerms.Left = $innerPad
      $lnkTerms.Top = $lblFreeware.Bottom + ([int](10 * $scale))
      $lnkPrivacy.Left = $lnkTerms.Right + ([int](16 * $scale))
      $lnkPrivacy.Top = $lnkTerms.Top
      $lblLegalMark.Location = New-Object System.Drawing.Point($innerPad, ($lnkTerms.Bottom + ([int](10 * $scale))))
      $lblLegalMark.Size = New-Object System.Drawing.Size($iw, ((Measure-HudWrap -Text $lblLegalMark.Text -Font $lblLegalMark.Font -MaxWidth $iw) + $textPad))
      $secLegal.Height = $lblLegalMark.Bottom + $innerPad
      $y = $secLegal.Bottom + $gapY

      $lblFoot.Left = $cx - [int]($lblFoot.PreferredWidth / 2)
      $lblFoot.Top = $y
      $lblBuild.Left = $cx - [int]($lblBuild.PreferredWidth / 2)
      $lblBuild.Top = $lblFoot.Bottom + ([int](8 * $scale))

      $newMinH = $lblBuild.Bottom + $padBottom
    } finally {
      $aboutPad.ResumeLayout($true)
    }
    $needAboutScroll = ($aboutPad.ClientSize.Height -gt 20) -and ($newMinH -gt $aboutPad.ClientSize.Height) -and (-not $aboutPad.VerticalScroll.Visible)
    if ($null -eq $script:AboutScrollMinH -or [Math]::Abs([int]$script:AboutScrollMinH - $newMinH) -gt 2 -or $needAboutScroll) {
      $script:AboutScrollMinH = $newMinH
      $aboutPad.AutoScroll = $true
      $aboutPad.AutoScrollMinSize = New-Object System.Drawing.Size(0, $newMinH)
      $aboutPad.PerformLayout()
      $aboutPad.Invalidate($true)
    }
  }

  $script:LayoutAboutCard = { & $script:LayoutAboutPage }
  $script:RequestAboutLayout = {
    $script:AboutLayoutW = $null
    $script:AboutLayoutForce = $true
    & $script:LayoutAboutPage
  }

  $aboutPad.Add_Resize({ & $script:LayoutAboutPage })
  & $script:LayoutAboutPage
