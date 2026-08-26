#!/usr/bin/env python3
"""Genera /var/www/radares/es.json (DGT + SCT + OSM vía Geofabrik/osmium).

Requisitos en el servidor:
  sudo apt install osmium-tool curl

Uso:
  sudo python3 /opt/locmotos/radares/build_es_json.py
  python3 build_es_json.py --out /var/www/radares/es.json --skip-osm

Cron (ejemplo 04:15):
  15 4 * * * /usr/bin/python3 /opt/locmotos/radares/build_es_json.py >> /var/log/radares-build.log 2>&1
"""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import shutil
import subprocess
import tempfile
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

USER_AGENT = "LocMotos-RadarBuild/1.0 (+https://valhalla.albertomaestre.es)"
DGT_URL = (
    "https://infocar.dgt.es/datex2/dgt/PredefinedLocationsPublication/"
    "radares/content.xml"
)
SCT_FIJOS = (
    "https://transit.gencat.cat/web/.content/documents/"
    "seguretat_viaria/radars.txt"
)
SCT_REMOLC = (
    "https://transit.gencat.cat/web/.content/documents/"
    "seguretat_viaria/radars-remolc.txt"
)
GEOFABRIK_SPAIN_PBF = (
    "https://download.geofabrik.de/europe/spain-latest.osm.pbf"
)
DEFAULT_CACHE_DIR = "/var/cache/locmotos/radares"
DEFAULT_PBF_MAX_AGE_HOURS = 24


def http_get(url: str, timeout: int = 60) -> bytes:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": USER_AGENT, "Accept": "*/*"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def utm31n_to_wgs84(easting: float, northing: float) -> tuple[float, float]:
    a = 6378137.0
    f = 1 / 298.257223563
    k0 = 0.9996
    e0 = 500000.0
    lon0 = 3.0 * math.pi / 180
    e2 = f * (2 - f)
    ep2 = e2 / (1 - e2)
    x = easting - e0
    y = northing
    m = y / k0
    mu = m / (
        a * (1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256)
    )
    e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2))
    phi1 = (
        mu
        + (3 * e1 / 2 - 27 * e1**3 / 32) * math.sin(2 * mu)
        + (21 * e1**2 / 16 - 55 * e1**4 / 32) * math.sin(4 * mu)
        + (151 * e1**3 / 96) * math.sin(6 * mu)
    )
    sin1 = math.sin(phi1)
    cos1 = math.cos(phi1)
    tan1 = math.tan(phi1)
    n1 = a / math.sqrt(1 - e2 * sin1 * sin1)
    t1 = tan1 * tan1
    c1 = ep2 * cos1 * cos1
    r1 = a * (1 - e2) / (1 - e2 * sin1 * sin1) ** 1.5
    d = x / (n1 * k0)
    lat = phi1 - (n1 * tan1 / r1) * (
        d * d / 2
        - (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * ep2) * d**4 / 24
        + (61 + 90 * t1 + 298 * c1 + 45 * t1 * t1 - 252 * ep2 - 3 * c1 * c1)
        * d**6
        / 720
    )
    lon = lon0 + (
        d
        - (1 + 2 * t1 + c1) * d**3 / 6
        + (5 - 2 * c1 + 28 * t1 - 3 * c1 * c1 + 8 * ep2 + 24 * t1 * t1)
        * d**5
        / 120
    ) / cos1
    return lat * 180 / math.pi, lon * 180 / math.pi


def poi(
    lat: float,
    lng: float,
    source: str,
    kind: str,
    label: str,
    road: str | None = None,
    speed: int | None = None,
) -> dict[str, Any]:
    item: dict[str, Any] = {
        "lat": round(lat, 6),
        "lng": round(lng, 6),
        "source": source,
        "kind": kind,
        "label": label,
    }
    if road:
        item["road"] = road
    if speed is not None:
        item["speedLimitKmh"] = speed
    return item


def fetch_dgt() -> list[dict[str, Any]]:
    print("→ DGT DATEX…")
    raw = http_get(DGT_URL, timeout=90).decode("utf-8", errors="replace")
    out: list[dict[str, Any]] = []
    parts = re.split(r'predefinedLocation\s+id="', raw)
    lat_re = re.compile(r"latitude>([-0-9.]+)<")
    lng_re = re.compile(r"longitude>([-0-9.]+)<")
    road_re = re.compile(r"roadNumber>([^<]+)<")
    for part in parts[1:]:
        quote = part.find('"')
        if quote <= 0:
            continue
        loc_id = part[:quote]
        body = part[quote + 1 :]
        lats = [float(m.group(1)) for m in lat_re.finditer(body)]
        lngs = [float(m.group(1)) for m in lng_re.finditer(body)]
        if not lats or len(lats) != len(lngs):
            continue
        road_m = road_re.search(body)
        road = road_m.group(1).strip() if road_m else None
        is_section = (
            "CVM" in loc_id
            or "VELOCIDADMEDIA" in loc_id.upper()
            or len(lats) > 1
        )
        kind = "section" if is_section else "fixed"
        label = (
            f"Radar de tramo · {road}"
            if is_section and road
            else ("Radar de tramo" if is_section else None)
        )
        if label is None:
            label = f"Radar fijo · {road}" if road else "Radar fijo"
        for i, (lat, lng) in enumerate(zip(lats, lngs)):
            if not (27 <= lat <= 44 and -19 <= lng <= 5):
                continue
            out.append(
                poi(
                    lat,
                    lng,
                    "dgt",
                    kind,
                    f"{label} (fin)" if is_section and i > 0 else label,
                    road=road,
                )
            )
    print(f"  DGT: {len(out)}")
    return out


def parse_sct(text: str, trailer: bool) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("(") or line.lower().startswith("via"):
            continue
        parts = line.split()
        if len(parts) < 5:
            continue
        try:
            x = float(parts[-2].replace(",", "."))
            y = float(parts[-1].replace(",", "."))
        except ValueError:
            continue
        speed_raw = parts[-3].replace(",", ".").split(".")[0]
        speed = int(speed_raw) if speed_raw.isdigit() else None
        if not (200000 <= x <= 600000 and 4400000 <= y <= 4800000):
            continue
        road = parts[0]
        pk = parts[1] if len(parts) >= 5 else ""
        if trailer:
            kind = "trailer"
        elif "-" in pk:
            kind = "section"
        else:
            kind = "fixed"
        if speed is not None and not (20 <= speed <= 140):
            speed = None
        lat, lng = utm31n_to_wgs84(x, y)
        speed_label = f" · {speed} km/h" if speed else ""
        kind_label = {
            "fixed": "fijo",
            "section": "tramo",
            "trailer": "móvil",
        }.get(kind, kind)
        label = (
            f"Radar {kind_label} · {road}{speed_label}"
            if road
            else f"Radar {kind_label}{speed_label}"
        )
        out.append(
            poi(lat, lng, "sct", kind, label, road=road or None, speed=speed)
        )
    return out


def fetch_sct() -> list[dict[str, Any]]:
    print("→ SCT fijos…")
    fijos = parse_sct(http_get(SCT_FIJOS).decode("utf-8", errors="replace"), False)
    print(f"  SCT fijos: {len(fijos)}")
    print("→ SCT remolque…")
    remolc = parse_sct(
        http_get(SCT_REMOLC).decode("utf-8", errors="replace"), True
    )
    print(f"  SCT remolque: {len(remolc)}")
    return fijos + remolc


def osm_kind(tags: dict[str, Any]) -> str:
    joined = " ".join(
        str(tags.get(k, ""))
        for k in ("speed_camera", "enforcement", "camera:type", "highway")
    ).lower()
    if any(x in joined for x in ("section", "average", "tram", "stretch")):
        return "section"
    if "mobile" in joined or "trailer" in joined:
        return "trailer"
    if tags.get("highway") == "speed_camera" or tags.get("enforcement") == "maxspeed":
        return "fixed"
    return "unknown"


def parse_maxspeed(raw: Any) -> int | None:
    if raw is None:
        return None
    m = re.search(r"(\d{2,3})", str(raw))
    if not m:
        return None
    value = int(m.group(1))
    return value if 20 <= value <= 140 else None


def require_osmium() -> str:
    path = shutil.which("osmium")
    if not path:
        raise SystemExit(
            "No se encontró 'osmium'. Instala: sudo apt install osmium-tool"
        )
    return path


def download_spain_pbf(dest: Path, force: bool = False) -> Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and not force:
        age_h = (datetime.now().timestamp() - dest.stat().st_mtime) / 3600
        size_mb = dest.stat().st_size / (1024 * 1024)
        print(f"  PBF en caché ({size_mb:.0f} MB, {age_h:.1f} h) → {dest}")
        return dest

    print(f"→ Descargando Geofabrik España (~1.5 GB)…\n  {GEOFABRIK_SPAIN_PBF}")
    tmp = dest.with_suffix(".osm.pbf.partial")
    curl = shutil.which("curl")
    if curl:
        cmd = [
            curl,
            "-L",
            "--fail",
            "--retry",
            "3",
            "-C",
            "-",
            "-A",
            USER_AGENT,
            "-o",
            str(tmp),
            GEOFABRIK_SPAIN_PBF,
        ]
        subprocess.run(cmd, check=True)
    else:
        req = urllib.request.Request(
            GEOFABRIK_SPAIN_PBF,
            headers={"User-Agent": USER_AGENT},
        )
        with urllib.request.urlopen(req, timeout=600) as resp, open(tmp, "wb") as out:
            shutil.copyfileobj(resp, out)
    os.replace(tmp, dest)
    size_mb = dest.stat().st_size / (1024 * 1024)
    print(f"  Descargado {size_mb:.0f} MB → {dest}")
    return dest


def ensure_spain_pbf(
    cache_dir: Path,
    max_age_hours: float,
    force_download: bool,
    pbf_path: Path | None,
) -> Path:
    if pbf_path is not None:
        if not pbf_path.is_file():
            raise SystemExit(f"No existe el PBF: {pbf_path}")
        print(f"→ Usando PBF local: {pbf_path}")
        return pbf_path

    dest = cache_dir / "spain-latest.osm.pbf"
    if dest.exists() and not force_download:
        age_h = (datetime.now().timestamp() - dest.stat().st_mtime) / 3600
        if age_h <= max_age_hours:
            return download_spain_pbf(dest, force=False)
        print(f"  PBF caducado ({age_h:.1f} h > {max_age_hours} h), renovando…")
    return download_spain_pbf(dest, force=True)


def tags_from_geojson_props(props: dict[str, Any]) -> dict[str, Any]:
    """osmium export mete tags OSM en properties (a veces anidados)."""
    if isinstance(props.get("tags"), dict):
        return props["tags"]
    skip = {
        "@id",
        "@type",
        "id",
        "type",
        "version",
        "timestamp",
        "changeset",
        "uid",
        "user",
    }
    return {k: v for k, v in props.items() if k not in skip and v is not None}


def fetch_osm_geofabrik(
    cache_dir: Path,
    max_age_hours: float,
    force_download: bool,
    pbf_path: Path | None,
) -> list[dict[str, Any]]:
    osmium = require_osmium()
    spain_pbf = ensure_spain_pbf(
        cache_dir=cache_dir,
        max_age_hours=max_age_hours,
        force_download=force_download,
        pbf_path=pbf_path,
    )

    with tempfile.TemporaryDirectory(prefix="radares-osm-") as tmp:
        tmp_dir = Path(tmp)
        filtered = tmp_dir / "radars.osm.pbf"
        geojsonseq = tmp_dir / "radars.geojsonseq"

        print("→ osmium tags-filter (speed_camera / enforcement=maxspeed)…")
        subprocess.run(
            [
                osmium,
                "tags-filter",
                str(spain_pbf),
                "n/highway=speed_camera",
                "n/enforcement=maxspeed",
                "-o",
                str(filtered),
                "--overwrite",
            ],
            check=True,
        )

        print("→ osmium export → GeoJSONSeq…")
        subprocess.run(
            [
                osmium,
                "export",
                str(filtered),
                "-f",
                "geojsonseq",
                "--geometry-types=point",
                "-o",
                str(geojsonseq),
                "--overwrite",
            ],
            check=True,
        )

        merged: list[dict[str, Any]] = []
        seen: set[str] = set()
        with open(geojsonseq, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                feat = json.loads(line)
                geom = feat.get("geometry") or {}
                if geom.get("type") != "Point":
                    continue
                coords = geom.get("coordinates") or []
                if len(coords) < 2:
                    continue
                lng, lat = float(coords[0]), float(coords[1])
                if not (27 <= lat <= 44 and -19 <= lng <= 5):
                    continue
                key = f"{lat:.5f}_{lng:.5f}"
                if key in seen:
                    continue
                seen.add(key)
                tags = tags_from_geojson_props(feat.get("properties") or {})
                kind = osm_kind(tags)
                limit = parse_maxspeed(tags.get("maxspeed"))
                speed_label = f" · {limit} km/h" if limit else ""
                noun = {
                    "fixed": "Radar fijo",
                    "section": "Radar de tramo",
                    "trailer": "Radar móvil",
                }.get(kind, "Radar")
                merged.append(
                    poi(
                        lat,
                        lng,
                        "osm",
                        kind,
                        f"{noun}{speed_label}",
                        speed=limit,
                    )
                )
        print(f"  OSM: {len(merged)}")
        return merged


def atomic_write(path: str, payload: dict[str, Any]) -> None:
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))
    os.replace(tmp, path)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Genera es.json de radares (DGT+SCT+Geofabrik/osmium)"
    )
    parser.add_argument(
        "--out",
        default="/var/www/radares/es.json",
        help="Ruta de salida (default: /var/www/radares/es.json)",
    )
    parser.add_argument(
        "--skip-osm",
        action="store_true",
        help="Solo DGT+SCT (más rápido para probar)",
    )
    parser.add_argument(
        "--cache-dir",
        default=DEFAULT_CACHE_DIR,
        help=f"Caché del PBF Geofabrik (default {DEFAULT_CACHE_DIR})",
    )
    parser.add_argument(
        "--pbf-max-age-hours",
        type=float,
        default=DEFAULT_PBF_MAX_AGE_HOURS,
        help="Reutilizar PBF si es más reciente (default 24 h)",
    )
    parser.add_argument(
        "--force-pbf-download",
        action="store_true",
        help="Forzar descarga de spain-latest.osm.pbf",
    )
    parser.add_argument(
        "--pbf",
        type=Path,
        default=None,
        help="Usar un PBF local (no descarga Geofabrik)",
    )
    args = parser.parse_args()

    official = fetch_dgt() + fetch_sct()
    osm: list[dict[str, Any]] = []
    if not args.skip_osm:
        osm = fetch_osm_geofabrik(
            cache_dir=Path(args.cache_dir),
            max_age_hours=args.pbf_max_age_hours,
            force_download=args.force_pbf_download,
            pbf_path=args.pbf,
        )

    now = datetime.now(timezone.utc).isoformat()
    payload = {
        "version": 1,
        "updatedAt": now,
        "officialCount": len(official),
        "osmCount": len(osm),
        "official": official,
        "osm": osm,
        "attribution": "© OpenStreetMap contributors (ODbL); DGT NAP; SCT",
    }
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    atomic_write(str(out_path), payload)
    print(f"✓ Escrito {out_path}")
    print(f"  oficiales={len(official)} osm={len(osm)} updatedAt={now}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
