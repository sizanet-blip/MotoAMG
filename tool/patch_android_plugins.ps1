# Applies local AGP 9 / built-in Kotlin patches to Flutter plugins in pub-cache.
# Run after `flutter pub get` when plugin versions change.

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$pubCache = if ($env:PUB_CACHE) { $env:PUB_CACHE } else { Join-Path $env:LOCALAPPDATA "Pub\Cache\hosted\pub.dev" }

$patches = @(
    @{
        PackagePrefix = "flutter_tts-"
        RelativePath  = "android\build.gradle"
        PatchFile     = Join-Path $projectRoot "tool\patches\flutter_tts_android_build.gradle"
    },
    @{
        PackagePrefix = "maplibre_gl-"
        RelativePath  = "android\build.gradle"
        PatchFile     = Join-Path $projectRoot "tool\patches\maplibre_gl_android_build.gradle"
    }
)

foreach ($patch in $patches) {
    $packageDir = Get-ChildItem -Path $pubCache -Directory -Filter ($patch.PackagePrefix + "*") |
        Sort-Object Name -Descending |
        Select-Object -First 1

    if (-not $packageDir) {
        Write-Warning "No package found for $($patch.PackagePrefix)* in $pubCache"
        continue
    }

    $target = Join-Path $packageDir.FullName $patch.RelativePath
    Copy-Item -Path $patch.PatchFile -Destination $target -Force
    Write-Host "Patched: $target"
}
