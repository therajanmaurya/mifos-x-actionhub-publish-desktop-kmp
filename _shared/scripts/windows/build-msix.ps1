<#
.SYNOPSIS
  Pack a Compose Desktop release app-image into a Store-ready MSIX.

.DESCRIPTION
  Compose Desktop emits .msi/.exe, never .msix. This script bridges that gap:
    1. Locate the `createReleaseDistributable` app image (the .exe + bundled JRE).
    2. Generate the required MSIX tile assets from the fork icon (PNG resize).
    3. Substitute the AppxManifest template with the vault-managed identity values
       (these MUST match the Partner Center reservation or the Store rejects it).
    4. makeappx pack the app image → unsigned .msix (the Store re-signs on submit).

  All identity values come in as parameters (sourced from the vault → CI env), never
  hardcoded — multi-fork support depends on this.

.NOTES
  Runs on windows-latest. makeappx.exe ships with the Windows 10/11 SDK.
#>
param(
  [Parameter(Mandatory=$true)][string]$AppImageDir,          # cmp-desktop/build/compose/binaries/main-release/app/<AppName>
  [Parameter(Mandatory=$true)][string]$IconPng,              # source square PNG (e.g. cmp-desktop/icons/ic_launcher.png)
  [Parameter(Mandatory=$true)][string]$ManifestTemplate,     # AppxManifest.xml.template
  [Parameter(Mandatory=$true)][string]$OutputMsix,           # path to write the .msix
  [Parameter(Mandatory=$true)][string]$IdentityName,         # windows_msix_identity_name
  [Parameter(Mandatory=$true)][string]$Publisher,            # windows_msix_publisher (CN=...)
  [Parameter(Mandatory=$true)][string]$PublisherDisplayName, # windows_msix_publisher_display_name
  [Parameter(Mandatory=$true)][string]$DisplayName,          # app display name (libs.versions.desktopAppName)
  [Parameter(Mandatory=$true)][string]$Version              # MSIX 4-part version a.b.c.0
)
$ErrorActionPreference = "Stop"

# ── 1. Locate the .exe inside the app image ─────────────────────────────────
$exe = Get-ChildItem -Path $AppImageDir -Filter *.exe -File | Select-Object -First 1
if (-not $exe) { throw "No .exe found in app image: $AppImageDir" }
$exeName = $exe.Name
Write-Host "App image exe: $exeName"

# ── 2. Generate MSIX tile assets from the source icon (System.Drawing resize) ─
Add-Type -AssemblyName System.Drawing
$assetsDir = Join-Path $AppImageDir "Assets"
New-Item -ItemType Directory -Force -Path $assetsDir | Out-Null
$src = [System.Drawing.Image]::FromFile((Resolve-Path $IconPng))
# name -> edge size (px). Store requires at minimum Square44/150 + StoreLogo.
$tiles = @{
  "Square44x44Logo.png"   = 44;  "Square71x71Logo.png"  = 71;
  "Square150x150Logo.png" = 150; "Square310x310Logo.png"= 310;
  "StoreLogo.png"         = 50
}
foreach ($name in $tiles.Keys) {
  $sz = $tiles[$name]
  $bmp = New-Object System.Drawing.Bitmap $sz, $sz
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($src, 0, 0, $sz, $sz)
  $bmp.Save((Join-Path $assetsDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
}
# Wide tile (310x150) — center the square icon on a transparent canvas.
$wide = New-Object System.Drawing.Bitmap 310, 150
$gw = [System.Drawing.Graphics]::FromImage($wide)
$gw.DrawImage($src, [int]((310-150)/2), 0, 150, 150)
$wide.Save((Join-Path $assetsDir "Wide310x150Logo.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$gw.Dispose(); $wide.Dispose(); $src.Dispose()
Write-Host "Generated $($tiles.Count + 1) tile assets in $assetsDir"

# ── 3. Substitute the AppxManifest template ─────────────────────────────────
$manifest = Get-Content -Raw $ManifestTemplate
$manifest = $manifest.
  Replace("@IDENTITY_NAME@",          $IdentityName).
  Replace("@PUBLISHER@",              $Publisher).
  Replace("@PUBLISHER_DISPLAY_NAME@", $PublisherDisplayName).
  Replace("@DISPLAY_NAME@",           $DisplayName).
  Replace("@EXE_NAME@",               $exeName).
  Replace("@VERSION@",                $Version)
$manifestPath = Join-Path $AppImageDir "AppxManifest.xml"
Set-Content -Path $manifestPath -Value $manifest -Encoding UTF8
Write-Host "Wrote AppxManifest.xml (Identity Name=$IdentityName Version=$Version)"

# ── 4. makeappx pack ────────────────────────────────────────────────────────
$makeappx = Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\makeappx.exe" |
            Sort-Object FullName -Descending | Select-Object -First 1
if (-not $makeappx) { throw "makeappx.exe not found (Windows SDK missing on runner)" }
& $makeappx.FullName pack /d $AppImageDir /p $OutputMsix /o
if ($LASTEXITCODE -ne 0) { throw "makeappx pack failed (exit $LASTEXITCODE)" }
Write-Host "MSIX written: $OutputMsix"
