#!/usr/bin/env python3
"""Genera /var/www/gasolineras/es.json desde la API de carburantes MITECO.

Uso:
  sudo python3 /opt/locmotos/gasolineras/build_es_json.py
  python3 build_es_json.py --out /var/www/gasolineras/es.json

Cron (ejemplo 04:45, tras radares):
  45 4 * * * /usr/bin/python3 /opt/locmotos/gasolineras/build_es_json.py >> /var/log/gasolineras-build.log 2>&1
"""

from __future__ import annotations

import argparse
import json
import os
import urllib.request
from datetime import datetime, timezone
from typing import Any

USER_AGENT = "LocMotos-FuelBuild/1.0 (+https://valhalla.albertomaestre.es)"

# Documentación: sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/...
ESTACIONES_URL = (
    "https://sedeaplicaciones.minetur.gob.es/"
    "ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/"
)

# Clave API → clave compacta en es.json
PRICE_FIELDS: list[tuple[str, str]] = [
    ("Precio Gasolina 95 E5", "gasolina95"),
    ("Precio Gasolina 95 E10", "gasolina95e10"),
    ("Precio Gasolina 98 E5", "gasolina98"),
    ("Precio Gasolina 98 E10", "gasolina98e10"),
    ("Precio Gasoleo A", "gasoleoA"),
    ("Precio Gasóleo A", "gasoleoA"),
    ("Precio Gasoleo Premium", "gasoleoPremium"),
    ("Precio Gasóleo Premium", "gasoleoPremium"),
    ("Precio Gasoleo B", "gasoleoB"),
    ("Precio Gasóleo B", "gasoleoB"),
]


def http_get(url: str, timeout: int = 180) -> bytes:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def parse_eu_float(raw: Any) -> float | None:
    if raw is None:
        return None
    text = str(raw).strip().replace(",", ".")
    if not text:
        return None
    try:
        value = float(text)
    except ValueError:
        return None
    if value <= 0 or value > 10:
        return None
    return round(value, 3)


def parse_coord(raw: Any) -> float | None:
    if raw is None:
        return None
    text = str(raw).strip().replace(",", ".")
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def _first(raw: dict[str, Any], *keys: str) -> Any:
    for key in keys:
        if key in raw and raw[key] not in (None, ""):
            return raw[key]
    return None


def station_from_raw(raw: dict[str, Any]) -> dict[str, Any] | None:
    lat = parse_coord(_first(raw, "Latitud", "latitud"))
    # La API oficial usa "Longitud (WGS84)"; variantes por encoding XML/JSON.
    lng = parse_coord(
        _first(
            raw,
            "Longitud (WGS84)",
            "Longitud_x0020__x0028_WGS84_x0029_",
            "Longitud",
            "longitud",
            "Longitud_WGS84",
        )
    )
    if lat is None or lng is None:
        return None
    if not (27 <= lat <= 44 and -19 <= lng <= 5):
        return None

    prices: dict[str, float] = {}
    for api_key, out_key in PRICE_FIELDS:
        value = parse_eu_float(raw.get(api_key))
        if value is not None and out_key not in prices:
            prices[out_key] = value
    # Fallback: claves con espacios codificados como _x0020_ (algunos proxies).
    if not prices:
        encoded = {
            k.replace(" ", "_x0020_"): v for k, v in PRICE_FIELDS
        }
        for api_key, out_key in encoded.items():
            value = parse_eu_float(raw.get(api_key))
            if value is not None and out_key not in prices:
                prices[out_key] = value
    if not prices:
        return None

    station_id = str(
        raw.get("IDEESS")
        or raw.get("IdEESS")
        or raw.get("id")
        or f"{lat:.5f}_{lng:.5f}"
    )
    name = (
        str(
            _first(raw, "Rótulo", "Rotulo", "R_x00F3_tulo", "Nombre") or ""
        ).strip()
        or "Gasolinera"
    )
    brand = (
        str(_first(raw, "Rótulo", "Rotulo", "R_x00F3_tulo") or "").strip()
        or None
    )
    locality = str(raw.get("Localidad") or "").strip() or None

    item: dict[str, Any] = {
        "id": station_id,
        "lat": round(lat, 6),
        "lng": round(lng, 6),
        "name": name,
        "prices": prices,
    }
    if brand:
        item["brand"] = brand
    if locality:
        item["locality"] = locality
    return item


def fetch_stations() -> list[dict[str, Any]]:
    print("→ MITECO EstacionesTerrestres…")
    raw = http_get(ESTACIONES_URL)
    data = json.loads(raw.decode("utf-8-sig"))
    resultado = data.get("ResultadoConsulta")
    if resultado and str(resultado).upper() != "OK":
        raise RuntimeError(f"MITECO ResultadoConsulta={resultado!r}")
    lista = data.get("ListaEESSPrecio") or data.get("ListaEESS") or []
    if not isinstance(lista, list):
        raise RuntimeError("Respuesta MITECO sin ListaEESSPrecio")
    print(f"  estaciones en respuesta: {len(lista)}")
    out: list[dict[str, Any]] = []
    seen: set[str] = set()
    skipped = 0
    for item in lista:
        if not isinstance(item, dict):
            continue
        station = station_from_raw(item)
        if station is None:
            skipped += 1
            continue
        key = station["id"]
        if key in seen:
            continue
        seen.add(key)
        out.append(station)
    print(f"  estaciones con precio: {len(out)} (descartadas: {skipped})")
    return out


def atomic_write(path: str, payload: dict[str, Any]) -> None:
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))
    os.replace(tmp, path)


def main() -> int:
    parser = argparse.ArgumentParser(description="Genera es.json de gasolineras")
    parser.add_argument(
        "--out",
        default="/var/www/gasolineras/es.json",
        help="Ruta de salida",
    )
    args = parser.parse_args()

    stations = fetch_stations()
    now = datetime.now(timezone.utc).isoformat()
    payload = {
        "version": 1,
        "updatedAt": now,
        "count": len(stations),
        "stations": stations,
        "attribution": "Ministerio para la Transición Ecológica (precios carburantes)",
    }
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    atomic_write(args.out, payload)
    print(f"✓ Escrito {args.out} ({len(stations)} estaciones)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
