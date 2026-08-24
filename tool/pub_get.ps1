# Ejecuta `flutter pub get` y aplica parches AGP 9 a plugins de terceros.
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Split-Path -Parent $projectRoot)

flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

powershell -ExecutionPolicy Bypass -File (Join-Path $projectRoot "patch_android_plugins.ps1")
