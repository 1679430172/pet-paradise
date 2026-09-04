Add-Type -AssemblyName System.Drawing

$assetRoot = Join-Path $PSScriptRoot '..\public\assets\shop'
$names = @('leaf', 'candy', 'starlight', 'gold')

function Get-OuterBand([System.Drawing.Bitmap]$bitmap, [ValidateSet('x','y')]$axis, [ValidateSet('start','end')]$side) {
  $length = if ($axis -eq 'x') { $bitmap.Width } else { $bitmap.Height }
  $probe = if ($axis -eq 'x') { [int]($bitmap.Height * .5) } else { [int]($bitmap.Width * .3) }
  $limit = [int]($length * .28)
  $hits = [System.Collections.Generic.List[int]]::new()
  for ($i = 0; $i -lt $limit; $i++) {
    $coordinate = if ($side -eq 'start') { $i } else { $length - 1 - $i }
    $pixel = if ($axis -eq 'x') { $bitmap.GetPixel($coordinate, $probe) } else { $bitmap.GetPixel($probe, $coordinate) }
    if ($pixel.A -gt 32) { $hits.Add($i) }
  }
  if ($hits.Count -eq 0) { throw "No visible $axis rail found on $side side." }
  return @{ Center = ($hits[0] + $hits[$hits.Count - 1]) / 2; Split = $hits[$hits.Count - 1] + 1 }
}

function Export-Frame([string]$name, [int]$width, [int]$height, [string]$suffix) {
  $sourcePath = Join-Path $assetRoot "frame-$name-portrait-v2.png"
  $outputPath = Join-Path $assetRoot "frame-$name-$suffix.png"
  $source = [System.Drawing.Bitmap]::FromFile($sourcePath)
  $bands = @{
    Left = Get-OuterBand $source x start
    Right = Get-OuterBand $source x end
    Top = Get-OuterBand $source y start
    Bottom = Get-OuterBand $source y end
  }
  $targetX = $width * .05
  $targetY = $height * .05
  $left = [Math]::Round($targetX * $bands.Left.Split / $bands.Left.Center)
  $right = [Math]::Round($targetX * $bands.Right.Split / $bands.Right.Center)
  $top = [Math]::Round($targetY * $bands.Top.Split / $bands.Top.Center)
  $bottom = [Math]::Round($targetY * $bands.Bottom.Split / $bands.Bottom.Center)

  $target = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($target)
  $graphics.Clear([System.Drawing.Color]::Transparent)
  $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
  $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

  [int[]]$sourceX = @(0, $bands.Left.Split, ($source.Width - $bands.Right.Split), $source.Width)
  [int[]]$sourceY = @(0, $bands.Top.Split, ($source.Height - $bands.Bottom.Split), $source.Height)
  [int[]]$targetXPoints = @(0, $left, ($width - $right), $width)
  [int[]]$targetYPoints = @(0, $top, ($height - $bottom), $height)
  for ($row = 0; $row -lt 3; $row++) {
    for ($column = 0; $column -lt 3; $column++) {
      $sourceRect = [System.Drawing.Rectangle]::new($sourceX[$column], $sourceY[$row], $sourceX[$column + 1] - $sourceX[$column], $sourceY[$row + 1] - $sourceY[$row])
      $targetRect = [System.Drawing.Rectangle]::new($targetXPoints[$column], $targetYPoints[$row], $targetXPoints[$column + 1] - $targetXPoints[$column], $targetYPoints[$row + 1] - $targetYPoints[$row])
      $graphics.DrawImage($source, $targetRect, $sourceRect.X, $sourceRect.Y, $sourceRect.Width, $sourceRect.Height, [System.Drawing.GraphicsUnit]::Pixel)
    }
  }
  $graphics.Dispose()
  $source.Dispose()
  $target.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $target.Dispose()
  Write-Output "$name -> $outputPath"
}

foreach ($name in $names) {
  Export-Frame $name 1060 1484 'portrait-v3'
  Export-Frame $name 1484 900 'landscape-v3'
}
