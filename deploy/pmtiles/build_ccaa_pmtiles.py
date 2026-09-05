#!/usr/bin/env python3
"""Genera PMTiles por CCAA para MotoAMG (Protomaps build + pmtiles extract).

Requisito: CLI go-pmtiles (pmtiles / pmtiles.exe)
  https://github.com/protomaps/go-pmtiles/releases

Uso típico en PC:
  python3 deploy/pmtiles/build_ccaa_pmtiles.py
  python3 deploy/pmtiles/build_ccaa_pmtiles.py --only aragon,madrid
  python3 deploy/pmtiles/build_ccaa_pmtiles.py --force --upload ubuntu@TU_IP:/var/www/maps/

Salida: maps/offline/<ccaa>.pmtiles + catalog_sizes.json
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass
from datetime import date, timedelta
from pathlib import Path

# Mismos bounds que lib/core/constants/navigation_constants.dart (availableRegions)
REGIONS: list[tuple[str, str, tuple[float, float, float, float]]] = [
    ("andalucia", "Andalucía", (-7.55, 35.90, -1.60, 38.75)),
    ("aragon", "Aragón", (-2.25, 39.80, 0.85, 42.98)),
    ("asturias", "Asturias", (-7.20, 42.85, -4.50, 43.70)),
    ("baleares", "Illes Balears", (1.15, 38.60, 4.40, 40.15)),
    ("canarias", "Canarias", (-18.20, 27.60, -13.30, 29.50)),
    ("cantabria", "Cantabria", (-4.85, 42.75, -3.15, 43.55)),
    ("castilla-la-mancha", "Castilla-La Mancha", (-5.50, 38.00, -0.80, 41.35)),
    ("castilla-leon", "Castilla y León", (-7.10, 40.20, -1.70, 43.30)),
    ("cataluna", "Cataluña", (0.15, 40.50, 3.35, 42.90)),
    ("ceuta", "Ceuta", (-5.40, 35.85, -5.25, 35.92)),
    ("extremadura", "Extremadura", (-7.55, 37.90, -4.65, 40.50)),
    ("galicia", "Galicia", (-9.35, 41.80, -6.70, 43.80)),
    ("la-rioja", "La Rioja", (-3.15, 41.90, -1.70, 42.65)),
    ("madrid", "Comunidad de Madrid", (-4.60, 39.85, -3.05, 41.20)),
    ("melilla", "Melilla", (-2.98, 35.26, -2.90, 35.34)),
    ("murcia", "Región de Murcia", (-2.35, 37.35, -0.65, 38.85)),
    ("navarra", "Navarra", (-2.50, 41.90, -0.70, 43.35)),
    ("pais-vasco", "País Vasco", (-3.45, 42.45, -1.70, 43.50)),
    ("valencia", "Comunidad Valenciana", (-1.55, 37.85, 0.70, 40.80)),
]

PROTOMAPS_BUILD_URL = "https://build.protomaps.com/{yyyymmdd}.pmtiles"
PROTOMAPS_BUILDS_INDEX = "https://maps.protomaps.com/builds/"
PROTOMAPS_BUILDS_JSON = "https://build-metadata.protomaps.dev/builds.json"
MIN_OUTPUT_BYTES = 1_000_000


@dataclass
class CatalogEntry:
    id: str
    name: str
    sizeBytes: int
    west: float
    south: float
    east: float
    north: float


def repo_root() -> Path:
    here = Path(__file__).resolve().parent
    for candidate in (here, *here.parents):
        if (candidate / "pubspec.yaml").is_file():
            return candidate
    return Path.cwd()


def log(msg: str, log_file: Path) -> None:
    line = msg
    print(line, flush=True)
    log_file.parent.mkdir(parents=True, exist_ok=True)
    with log_file.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def find_pmtiles_cli(root: Path) -> Path:
    env = os.environ.get("PMTILES_CLI")
    if env:
        path = Path(env)
        if path.is_file():
            return path

    candidates = [
        root / "tools" / "pmtiles" / "pmtiles.exe",
        root / "tools" / "pmtiles" / "pmtiles",
        Path(shutil.which("pmtiles") or ""),
    ]
    for path in candidates:
        if path and path.is_file():
            return path
    raise SystemExit(
        "No se encontró el CLI 'pmtiles'. Descarga go-pmtiles y colócalo en "
        "tools/pmtiles/ o en el PATH. Ver deploy/pmtiles/README.md"
    )


def protomaps_source_from_metadata() -> str | None:
    """Lista oficial de builds (maps.protomaps.com/builds)."""
    req = urllib.request.Request(
        PROTOMAPS_BUILDS_JSON,
        headers={"User-Agent": "MotoAMG-PMTilesBuild/1.0"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except (OSError, urllib.error.HTTPError, json.JSONDecodeError, TimeoutError):
        return None
    if not isinstance(payload, list) or not payload:
        return None
    # Entradas tipo {"key": "20260826.pmtiles", ...}; la más reciente primero.
    sorted_keys = sorted(
        (
            str(item.get("key", ""))
            for item in payload
            if isinstance(item, dict) and str(item.get("key", "")).endswith(".pmtiles")
        ),
        reverse=True,
    )
    if not sorted_keys:
        return None
    key = sorted_keys[0]
    return f"https://build.protomaps.com/{key}"


def protomaps_source_url(max_days_back: int = 21) -> str:
    from_metadata = protomaps_source_from_metadata()
    if from_metadata:
        return from_metadata

    today = date.today()
    for offset in range(max_days_back):
        day = today - timedelta(days=offset)
        url = PROTOMAPS_BUILD_URL.format(yyyymmdd=day.strftime("%Y%m%d"))
        req = urllib.request.Request(url, method="HEAD")
        req.add_header("User-Agent", "MotoAMG-PMTilesBuild/1.0")
        try:
            with urllib.request.urlopen(req, timeout=25) as resp:
                if 200 <= resp.status < 300:
                    return url
        except urllib.error.HTTPError:
            continue
        except OSError:
            continue
    raise SystemExit(
        "No se encontró un build Protomaps reciente.\n"
        f"- La URL base {PROTOMAPS_BUILDS_INDEX} lista builds válidos.\n"
        "- La raíz https://build.protomaps.com/ devuelve 404 (es normal).\n"
        "- Usa una URL con fecha, p. ej.:\n"
        "    --source https://build.protomaps.com/20260826.pmtiles\n"
        "  (cambia la fecha por una fila reciente en maps.protomaps.com/builds)"
    )


def bbox_arg(bounds: tuple[float, float, float, float]) -> str:
    west, south, east, north = bounds
    return f"{west},{south},{east},{north}"


def extract_region(
    cli: Path,
    source: str,
    out_path: Path,
    bounds: tuple[float, float, float, float],
    threads: int,
) -> None:
    cmd = [
        str(cli),
        "extract",
        source,
        str(out_path),
        f"--bbox={bbox_arg(bounds)}",
        f"--download-threads={threads}",
    ]
    subprocess.run(cmd, check=True)


def scp_upload(files: list[Path], dest: str) -> None:
    if not files:
        return
    scp = shutil.which("scp")
    if not scp:
        raise SystemExit("scp no está en el PATH; sube los .pmtiles a mano.")
    cmd = [scp, "-p", *[str(f) for f in files], dest]
    subprocess.run(cmd, check=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extrae PMTiles por CCAA desde Protomaps para MotoAMG."
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=None,
        help="Directorio de salida (default: maps/offline en la raíz del repo)",
    )
    parser.add_argument(
        "--source",
        help="URL .pmtiles de Protomaps (default: último build diario)",
    )
    parser.add_argument(
        "--only",
        help="Solo estas CCAA, separadas por coma (ej. aragon,madrid)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Regenerar aunque el fichero ya exista",
    )
    parser.add_argument(
        "--threads",
        type=int,
        default=4,
        help="Hilos de descarga para pmtiles extract (default 4)",
    )
    parser.add_argument(
        "--upload",
        metavar="DEST",
        help="Subir al VPS con scp, ej. ubuntu@IP:/var/www/maps/",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Mostrar qué haría sin extraer",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = repo_root()
    out_dir = args.out_dir or (root / "maps" / "offline")
    log_file = out_dir / "extract_log.txt"

    only_ids: set[str] | None = None
    if args.only:
        only_ids = {part.strip() for part in args.only.split(",") if part.strip()}

    regions = [
        (rid, name, bounds)
        for rid, name, bounds in REGIONS
        if only_ids is None or rid in only_ids
    ]
    if not regions:
        raise SystemExit("Ninguna CCAA coincide con --only")

    unknown = only_ids - {rid for rid, _, _ in REGIONS} if only_ids else set()
    if unknown:
        raise SystemExit(f"IDs desconocidos en --only: {', '.join(sorted(unknown))}")

    cli = find_pmtiles_cli(root)
    source = args.source or protomaps_source_url()

    log(f"SOURCE={source}", log_file)
    log(f"CLI={cli}", log_file)
    log(f"OUT={out_dir}", log_file)

    catalog: list[CatalogEntry] = []
    uploaded: list[Path] = []

    for region_id, name, bounds in regions:
        out_path = out_dir / f"{region_id}.pmtiles"
        west, south, east, north = bounds

        if (
            not args.force
            and out_path.is_file()
            and out_path.stat().st_size > MIN_OUTPUT_BYTES
        ):
            size = out_path.stat().st_size
            log(f"SKIP {region_id} ({size} bytes)", log_file)
        elif args.dry_run:
            log(f"DRY-RUN extract {region_id} bbox={bbox_arg(bounds)}", log_file)
        else:
            out_path.parent.mkdir(parents=True, exist_ok=True)
            if out_path.is_file():
                out_path.unlink()
            log(f"EXTRACT {region_id} bbox={bbox_arg(bounds)}", log_file)
            try:
                extract_region(cli, source, out_path, bounds, args.threads)
            except subprocess.CalledProcessError as err:
                log(f"FAIL {region_id} exit={err.returncode}", log_file)
                continue
            if not out_path.is_file():
                log(f"FAIL {region_id} (sin fichero de salida)", log_file)
                continue
            log(f"OK {region_id} {out_path.stat().st_size} bytes", log_file)
            uploaded.append(out_path)

        if out_path.is_file():
            catalog.append(
                CatalogEntry(
                    id=region_id,
                    name=name,
                    sizeBytes=out_path.stat().st_size,
                    west=west,
                    south=south,
                    east=east,
                    north=north,
                )
            )

    catalog_path = out_dir / "catalog_sizes.json"
    catalog_path.write_text(
        json.dumps([asdict(entry) for entry in catalog], indent=2, ensure_ascii=False)
        + "\n",
        encoding="utf-8",
    )
    log(f"DONE catalog={catalog_path}", log_file)

    for entry in catalog:
        log(f"FILE {entry.id}.pmtiles {entry.sizeBytes}", log_file)

    if args.upload and not args.dry_run:
        files = uploaded or [out_dir / f"{e.id}.pmtiles" for e in catalog]
        files = [f for f in files if f.is_file()]
        log(f"UPLOAD {len(files)} files -> {args.upload}", log_file)
        scp_upload(files, args.upload)

    failed = len(regions) - len(catalog)
    if failed:
        log(f"WARN {failed} region(es) sin fichero", log_file)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
