#!/usr/bin/env python3
"""Lista builds Protomaps disponibles (build.protomaps.com/YYYYMMDD.pmtiles).

La raíz https://build.protomaps.com/ no tiene índice (404). Este script:
  1) Intenta la API oficial build-metadata.protomaps.dev/builds.json
  2) Si falla, prueba HEAD en fechas recientes

Uso:
  python3 deploy/pmtiles/list_protomaps_builds.py
  python3 deploy/pmtiles/list_protomaps_builds.py --days 30
  python3 deploy/pmtiles/list_protomaps_builds.py --json
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from datetime import date, timedelta

PROTOMAPS_BUILD_URL = "https://build.protomaps.com/{yyyymmdd}.pmtiles"
PROTOMAPS_BUILDS_INDEX = "https://maps.protomaps.com/builds/"
PROTOMAPS_BUILDS_JSON = "https://build-metadata.protomaps.dev/builds.json"
USER_AGENT = "LocMotos-PMTilesList/1.0"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Lista builds Protomaps (fechas con .pmtiles disponible)."
    )
    parser.add_argument(
        "--days",
        type=int,
        default=14,
        help="Días hacia atrás a probar si la API JSON no responde (default 14)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Salida JSON en lugar de texto",
    )
    return parser.parse_args()


def fetch_builds_json() -> list[dict] | None:
    req = urllib.request.Request(
        PROTOMAPS_BUILDS_JSON,
        headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=45) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except (OSError, urllib.error.HTTPError, json.JSONDecodeError, TimeoutError):
        return None
    if not isinstance(payload, list):
        return None
    rows: list[dict] = []
    for item in payload:
        if not isinstance(item, dict):
            continue
        key = str(item.get("key", ""))
        if not key.endswith(".pmtiles"):
            continue
        date_part = key.removesuffix(".pmtiles")
        rows.append(
            {
                "date": date_part,
                "url": f"https://build.protomaps.com/{key}",
                "sizeBytes": item.get("size"),
                "version": item.get("version"),
                "uploaded": item.get("uploaded"),
                "source": "api",
            }
        )
    rows.sort(key=lambda r: r["date"], reverse=True)
    return rows or None


def head_build(day: date) -> dict | None:
    yyyymmdd = day.strftime("%Y%m%d")
    url = PROTOMAPS_BUILD_URL.format(yyyymmdd=yyyymmdd)
    req = urllib.request.Request(url, method="HEAD")
    req.add_header("User-Agent", USER_AGENT)
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            if resp.status < 200 or resp.status >= 300:
                return None
            length = resp.headers.get("Content-Length")
            return {
                "date": yyyymmdd,
                "url": url,
                "sizeBytes": int(length) if length and length.isdigit() else None,
                "version": None,
                "uploaded": resp.headers.get("Last-Modified"),
                "source": "head",
            }
    except (OSError, urllib.error.HTTPError):
        return None


def scan_days(days: int) -> list[dict]:
    today = date.today()
    found: list[dict] = []
    for offset in range(max(1, days)):
        row = head_build(today - timedelta(days=offset))
        if row is not None:
            found.append(row)
    return found


def format_bytes(size: int | None) -> str:
    if size is None or size <= 0:
        return "?"
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    value = float(size)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            if unit == "B":
                return f"{int(value)} B"
            return f"{value:.1f} {unit}"
        value /= 1024
    return f"{size} B"


def print_text(rows: list[dict], from_api: bool) -> None:
    print(f"Índice web: {PROTOMAPS_BUILDS_INDEX}")
    print(f"API JSON:   {PROTOMAPS_BUILDS_JSON}")
    print()
    if from_api:
        print(f"Fuente: API ({len(rows)} builds listados)")
    else:
        print(f"Fuente: HEAD últimos días ({len(rows)} encontrados)")
    print()
    if not rows:
        print("No se encontró ningún build.")
        print("Prueba: --days 30")
        return
    print(f"{'FECHA':<10} {'TAMAÑO':>12}  URL")
    print("-" * 72)
    for row in rows:
        print(
            f"{row['date']:<10} {format_bytes(row.get('sizeBytes')):>12}  {row['url']}"
        )
    latest = rows[0]
    print()
    print("Más reciente para --source:")
    print(f"  --source {latest['url']}")


def main() -> int:
    args = parse_args()
    rows = fetch_builds_json()
    from_api = rows is not None
    if rows is None:
        rows = scan_days(args.days)

    if args.json:
        print(json.dumps(rows, indent=2, ensure_ascii=False))
    else:
        print_text(rows, from_api)

    return 0 if rows else 1


if __name__ == "__main__":
    sys.exit(main())
