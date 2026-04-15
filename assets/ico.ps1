Add-Type -AssemblyName System.Drawing

function New-IconBitmap {
  param([int]$Size)

  $bmp = [System.Drawing.Bitmap]::new($Size, $Size)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::Transparent)

  # escala proporcional ao tamanho do ícone (base = 128)
  $scale = $Size / 128.0

  # cores
  $bg = [System.Drawing.Color]::FromArgb(255, 0x28, 0x2a, 0x36)  # #282a36
  $border = [System.Drawing.Color]::FromArgb(255, 0x62, 0x72, 0xa4)  # #6272a4
  $bgAlpha = [System.Drawing.Color]::FromArgb(178, 0x28, 0x2a, 0x36)  # #282a36 70%
  $bdrAlpha = [System.Drawing.Color]::FromArgb(178, 0x62, 0x72, 0xa4)  # #6272a4 70%

  $brushBg = [System.Drawing.SolidBrush]::new($bg)
  $brushBorder = [System.Drawing.SolidBrush]::new($border)
  $brushBgA = [System.Drawing.SolidBrush]::new($bgAlpha)
  $brushBorderA = [System.Drawing.SolidBrush]::new($bdrAlpha)

  $penBorder = [System.Drawing.Pen]::new($border, [int](2 * $scale))
  $penBorderA = [System.Drawing.Pen]::new($bdrAlpha, [int](2 * $scale))

  # janela de trás (100% opacidade)
  # rect: x=8 y=8 w=80 h=80
  $x1 = [int](8 * $scale); $y1 = [int](8 * $scale)
  $w1 = [int](80 * $scale); $h1 = [int](80 * $scale)
  $t1 = [int](12 * $scale)  # altura da titlebar

  $g.FillRectangle($brushBg, $x1, $y1, $w1, $h1)
  $g.FillRectangle($brushBorder, $x1, $y1, $w1, $t1)
  $g.DrawRectangle($penBorder, $x1, $y1, $w1, $h1)

  # janela da frente (70% opacidade)
  # rect: x=40 y=40 w=80 h=80
  $x2 = [int](40 * $scale); $y2 = [int](40 * $scale)
  $w2 = [int](80 * $scale); $h2 = [int](80 * $scale)
  $t2 = [int](12 * $scale)

  $g.FillRectangle($brushBgA, $x2, $y2, $w2, $h2)
  $g.FillRectangle($brushBorderA, $x2, $y2, $w2, $t2)
  $g.DrawRectangle($penBorderA, $x2, $y2, $w2, $h2)

  $g.Dispose()
  return $bmp
}

function Save-Ico {
  param([string]$OutputPath)

  $sizes = @(16, 32, 48, 256)
  $pngStreams = @()

  foreach ($s in $sizes) {
    $bmp = New-IconBitmap -Size $s
    $ms = [System.IO.MemoryStream]::new()
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $pngStreams += $ms
  }

  $writer = [System.IO.BinaryWriter]::new([System.IO.File]::Create($OutputPath))

  # ICONDIR header
  $writer.Write([uint16]0)           # reserved
  $writer.Write([uint16]1)           # type = ICO
  $writer.Write([uint16]$sizes.Count)

  # offset inicial: header(6) + entries(16 * count)
  $offset = 6 + (16 * $sizes.Count)

  # ICONDIRENTRY para cada tamanho
  for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]
    $data = $pngStreams[$i].ToArray()

    $writer.Write([byte]$(if ($s -eq 256) { 0 } else { $s }))  # width  (0 = 256)
    $writer.Write([byte]$(if ($s -eq 256) { 0 } else { $s }))  # height (0 = 256)
    $writer.Write([byte]0)           # color count
    $writer.Write([byte]0)           # reserved
    $writer.Write([uint16]1)         # planes
    $writer.Write([uint16]32)        # bit count
    $writer.Write([uint32]$data.Length)
    $writer.Write([uint32]$offset)

    $offset += $data.Length
  }

  # dados PNG de cada tamanho
  foreach ($ms in $pngStreams) {
    $writer.Write($ms.ToArray())
    $ms.Dispose()
  }

  $writer.Dispose()
}

Save-Ico -OutputPath ".\assets\icon.ico"
Write-Host "icon.ico gerado em .\assets\icon.ico"
