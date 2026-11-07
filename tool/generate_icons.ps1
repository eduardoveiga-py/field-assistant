Add-Type -AssemblyName System.Drawing

$bmp = New-Object System.Drawing.Bitmap 1024, 1024
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# 1. Fundo Gradiente Opaque (Azul Marinho Profundo para Azul Real / Índigo)
$rect = New-Object System.Drawing.Rectangle 0, 0, 1024, 1024
$cTop = [System.Drawing.Color]::FromArgb(255, 11, 17, 30)
$cBottom = [System.Drawing.Color]::FromArgb(255, 30, 58, 138)
$brushBg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $cTop, $cBottom, 45.0
$g.FillRectangle($brushBg, $rect)

# 2. Círculos Cartográficos / Bússola Decorativa
$penGrid = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(35, 56, 189, 248)), 3
$g.DrawEllipse($penGrid, 162, 162, 700, 700)
$g.DrawEllipse($penGrid, 262, 262, 500, 500)
$g.DrawLine($penGrid, 512, 100, 512, 924)
$g.DrawLine($penGrid, 100, 512, 924, 512)

# 3. Mapa Desdobrado de Território (3 Paineis Isométricos)
# Painel Esquerdo
$pathLeft = New-Object System.Drawing.Drawing2D.GraphicsPath
[System.Drawing.Point[]]$ptsLeft = @(
    (New-Object System.Drawing.Point 230, 560),
    (New-Object System.Drawing.Point 410, 500),
    (New-Object System.Drawing.Point 410, 770),
    (New-Object System.Drawing.Point 230, 830)
)
$pathLeft.AddPolygon($ptsLeft)
$brushLeft = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(240, 14, 116, 144))
$g.FillPath($brushLeft, $pathLeft)

# Painel Central
$pathMid = New-Object System.Drawing.Drawing2D.GraphicsPath
[System.Drawing.Point[]]$ptsMid = @(
    (New-Object System.Drawing.Point 410, 500),
    (New-Object System.Drawing.Point 614, 560),
    (New-Object System.Drawing.Point 614, 830),
    (New-Object System.Drawing.Point 410, 770)
)
$pathMid.AddPolygon($ptsMid)
$brushMid = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(250, 2, 132, 199))
$g.FillPath($brushMid, $pathMid)

# Painel Direito
$pathRight = New-Object System.Drawing.Drawing2D.GraphicsPath
[System.Drawing.Point[]]$ptsRight = @(
    (New-Object System.Drawing.Point 614, 560),
    (New-Object System.Drawing.Point 794, 500),
    (New-Object System.Drawing.Point 794, 770),
    (New-Object System.Drawing.Point 614, 830)
)
$pathRight.AddPolygon($ptsRight)
$brushRight = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(240, 14, 116, 144))
$g.FillPath($brushRight, $pathRight)

# Bordas do Mapa
$penMapBorder = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(200, 224, 242, 254)), 6
$g.DrawPath($penMapBorder, $pathLeft)
$g.DrawPath($penMapBorder, $pathMid)
$g.DrawPath($penMapBorder, $pathRight)

# Linha de Rota / Caminho Pastoral no Mapa
$penRoute = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(245, 251, 191, 36)), 8
$penRoute.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
[System.Drawing.Point[]]$ptsRoute = @(
    (New-Object System.Drawing.Point 280, 740),
    (New-Object System.Drawing.Point 410, 640),
    (New-Object System.Drawing.Point 512, 690),
    (New-Object System.Drawing.Point 740, 610)
)
$g.DrawCurve($penRoute, $ptsRoute, 0.4)

# 4. Sombra Projetada do Marcador de Ponto de Território
$pathPinShadow = New-Object System.Drawing.Drawing2D.GraphicsPath
$pathPinShadow.AddEllipse(452, 630, 120, 40)
$brushShadow = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(90, 0, 0, 0))
$g.FillPath($brushShadow, $pathPinShadow)

# 5. Pino Gigante Centralizado (Verde Esmeralda -> Azul Celeste Vibrante)
$rectPin = New-Object System.Drawing.Rectangle 332, 170, 360, 460
$brushPin = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rectPin, ([System.Drawing.Color]::FromArgb(255, 16, 185, 129)), ([System.Drawing.Color]::FromArgb(255, 37, 99, 235)), 60.0

$pathPin = New-Object System.Drawing.Drawing2D.GraphicsPath
$pathPin.AddArc(332, 170, 360, 360, 145, 250)
$pathPin.AddLine(655, 410, 512, 620)
$pathPin.AddLine(512, 620, 369, 410)
$pathPin.CloseFigure()
$g.FillPath($brushPin, $pathPin)

# Contorno Branco do Pino
$penPin = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 255, 255, 255)), 12
$g.DrawPath($penPin, $pathPin)

# Centro Branco do Pino
$brushWhite = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
$g.FillEllipse($brushWhite, 432, 270, 160, 160)

# Símbolo do Livro Aberto / Bíblia Ministerial no Coração do Pino
$brushCore = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 30, 58, 138))
[System.Drawing.Point[]]$ptsPageL = @(
    (New-Object System.Drawing.Point 506, 320),
    (New-Object System.Drawing.Point 455, 332),
    (New-Object System.Drawing.Point 455, 385),
    (New-Object System.Drawing.Point 506, 372)
)
$pathPageL = New-Object System.Drawing.Drawing2D.GraphicsPath
$pathPageL.AddPolygon($ptsPageL)
$g.FillPath($brushCore, $pathPageL)

[System.Drawing.Point[]]$ptsPageR = @(
    (New-Object System.Drawing.Point 518, 320),
    (New-Object System.Drawing.Point 569, 332),
    (New-Object System.Drawing.Point 569, 385),
    (New-Object System.Drawing.Point 518, 372)
)
$pathPageR = New-Object System.Drawing.Drawing2D.GraphicsPath
$pathPageR.AddPolygon($ptsPageR)
$g.FillPath($brushCore, $pathPageR)

$penRibbon = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 239, 68, 68)), 5
$g.DrawLine($penRibbon, 512, 315, 512, 400)

# Salva Master 1024x1024
$masterPath = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png'
$bmp.Save($masterPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Generated master icon: $masterPath"

function Resize-Save($src, $w, $h, $dest) {
    $target = New-Object System.Drawing.Bitmap $w, $h
    $gt = [System.Drawing.Graphics]::FromImage($target)
    $gt.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $gt.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gt.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $gt.DrawImage($src, 0, 0, $w, $h)
    $gt.Dispose()
    $target.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
    $target.Dispose()
    Write-Host "Exported: $dest ($w x $h)"
}

# Conjunto de Ícones do iOS
Resize-Save $bmp 167 167 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png'
Resize-Save $bmp 152 152 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png'
Resize-Save $bmp 76 76 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png'
Resize-Save $bmp 180 180 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png'
Resize-Save $bmp 120 120 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png'
Resize-Save $bmp 120 120 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png'
Resize-Save $bmp 80 80 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png'
Resize-Save $bmp 40 40 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png'
Resize-Save $bmp 87 87 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png'
Resize-Save $bmp 58 58 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png'
Resize-Save $bmp 29 29 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png'
Resize-Save $bmp 60 60 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png'
Resize-Save $bmp 40 40 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png'
Resize-Save $bmp 20 20 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png'

# Ícones da Web
Resize-Save $bmp 512 512 'web/icons/Icon-512.png'
Resize-Save $bmp 512 512 'web/icons/Icon-maskable-512.png'
Resize-Save $bmp 192 192 'web/icons/Icon-192.png'
Resize-Save $bmp 192 192 'web/icons/Icon-maskable-192.png'
Resize-Save $bmp 64 64 'web/favicon.png'

# Ícones do Android
Resize-Save $bmp 48 48 'android/app/src/main/res/mipmap-mdpi/ic_launcher.png'
Resize-Save $bmp 72 72 'android/app/src/main/res/mipmap-hdpi/ic_launcher.png'
Resize-Save $bmp 96 96 'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png'
Resize-Save $bmp 144 144 'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png'
Resize-Save $bmp 192 192 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'

$g.Dispose()
$bmp.Dispose()
Write-Host "Todos os icones do aplicativo foram gerados com sucesso!"
