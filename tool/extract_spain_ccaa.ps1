# Extrae PMTiles por CCAA desde Protomaps. ASCII-only for PS 5.1.
# Uso: .\tool\extract_spain_ccaa.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root "pubspec.yaml"))) {
  $root = (Get-Location).Path
}

$exe = Join-Path $root "tools\pmtiles\pmtiles.exe"
$outDir = Join-Path $root "maps\offline"
$logFile = Join-Path $outDir "extract_log.txt"
$catalogFile = Join-Path $outDir "catalog_sizes.json"

if (-not (Test-Path $exe)) {
  throw "pmtiles.exe missing: $exe"
}
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$source = $null
foreach ($i in 0..20) {
  $d = (Get-Date).AddDays(-$i).ToString("yyyyMMdd")
  $u = "https://build.protomaps.com/$d.pmtiles"
  try {
    $req = [System.Net.HttpWebRequest]::Create($u)
    $req.Method = "HEAD"
    $req.Timeout = 20000
    $resp = $req.GetResponse()
    $resp.Close()
    $source = $u
    break
  } catch {}
}
if (-not $source) {
  throw "No Protomaps build found"
}

# id|displayName|west,south,east,north
$lines = @(
  "andalucia|Andalucia|-7.55,35.90,-1.60,38.75",
  "aragon|Aragon|-2.25,39.80,0.85,42.98",
  "asturias|Asturias|-7.20,42.85,-4.50,43.70",
  "baleares|Illes Balears|1.15,38.60,4.40,40.15",
  "canarias|Canarias|-18.20,27.60,-13.30,29.50",
  "cantabria|Cantabria|-4.85,42.75,-3.15,43.55",
  "castilla-la-mancha|Castilla-La Mancha|-5.50,38.00,-0.80,41.35",
  "castilla-leon|Castilla y Leon|-7.10,40.20,-1.70,43.30",
  "cataluna|Cataluna|0.15,40.50,3.35,42.90",
  "extremadura|Extremadura|-7.55,37.90,-4.65,40.50",
  "galicia|Galicia|-9.35,41.80,-6.70,43.80",
  "madrid|Comunidad de Madrid|-4.60,39.85,-3.05,41.20",
  "murcia|Region de Murcia|-2.35,37.35,-0.65,38.85",
  "navarra|Navarra|-2.50,41.90,-0.70,43.35",
  "pais-vasco|Pais Vasco|-3.45,42.45,-1.70,43.50",
  "la-rioja|La Rioja|-3.15,41.90,-1.70,42.65",
  "valencia|Comunidad Valenciana|-1.55,37.85,0.70,40.80",
  "ceuta|Ceuta|-5.40,35.85,-5.25,35.92",
  "melilla|Melilla|-2.98,35.26,-2.90,35.34"
)

function Write-Log([string]$msg) {
  $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
  Add-Content -Path $logFile -Value $line -Encoding ASCII
  Write-Host $line
}

Write-Log "SOURCE=$source"
$catalog = New-Object System.Collections.Generic.List[object]

foreach ($line in $lines) {
  $parts = $line.Split("|")
  $id = $parts[0]
  $name = $parts[1]
  $bbox = $parts[2]
  $out = Join-Path $outDir "$id.pmtiles"

  if ((Test-Path $out) -and ((Get-Item $out).Length -gt 1MB)) {
    $size = (Get-Item $out).Length
    Write-Log "SKIP $id ($size bytes)"
  } else {
    Write-Log "EXTRACT $id bbox=$bbox"
    & $exe extract $source $out --bbox=$bbox --download-threads=4
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $out)) {
      Write-Log "FAIL $id exit=$LASTEXITCODE"
      continue
    }
    $size = (Get-Item $out).Length
    Write-Log "OK $id $size bytes"
  }

  $b = $bbox.Split(",")
  $catalog.Add([pscustomobject]@{
    id = $id
    name = $name
    sizeBytes = [long](Get-Item $out).Length
    west = [double]$b[0]
    south = [double]$b[1]
    east = [double]$b[2]
    north = [double]$b[3]
  }) | Out-Null
}

$catalog | ConvertTo-Json -Depth 4 | Set-Content -Path $catalogFile -Encoding ASCII
Write-Log "DONE catalog=$catalogFile"
Get-ChildItem $outDir -Filter *.pmtiles | Sort-Object Name | ForEach-Object {
  Write-Log ("FILE {0} {1}" -f $_.Name, $_.Length)
}
