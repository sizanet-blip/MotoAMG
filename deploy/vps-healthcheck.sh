#!/usr/bin/env bash
# LocMotos — comprobación rápida del VPS (Valhalla, Photon, bundles, PMTiles).
# Uso en el servidor:
#   chmod +x vps-healthcheck.sh
#   ./vps-healthcheck.sh
# Salida: OK / WARN / FAIL por comprobación. Exit 0 si no hay FAIL críticos.

set -u

VALHALLA_HOST="${VALHALLA_HOST:-https://valhalla.albertomaestre.es}"
PHOTON_HOST="${PHOTON_HOST:-https://photon.albertomaestre.es}"
VALHALLA_CONTAINER="${VALHALLA_CONTAINER:-valhalla}"
MIN_DISK_GB="${MIN_DISK_GB:-15}"
MOTO_MIN_DISTANCE="${MOTO_MIN_DISTANCE:-1500000}"

FAIL_COUNT=0
WARN_COUNT=0

ok()   { printf '  \033[32mOK\033[0m   %s\n' "$1"; }
warn() { printf '  \033[33mWARN\033[0m %s\n' "$1"; WARN_COUNT=$((WARN_COUNT + 1)); }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

section() {
  echo
  echo "== $1 =="
}

http_code() {
  curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 12 --max-time 45 "$@" 2>/dev/null || echo '000'
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Falta comando: $1"
    return 1
  fi
  return 0
}

section "Comandos"
for cmd in curl docker; do
  if require_cmd "$cmd"; then
    ok "$cmd disponible"
  fi
done

section "Docker"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$VALHALLA_CONTAINER"; then
  status="$(docker inspect -f '{{.State.Status}}' "$VALHALLA_CONTAINER" 2>/dev/null || echo unknown)"
  ok "Contenedor $VALHALLA_CONTAINER ($status)"
else
  fail "Contenedor $VALHALLA_CONTAINER no está en ejecución"
fi

if docker ps --format '{{.Names}}' 2>/dev/null | grep -Eiq 'photon'; then
  photon_name="$(docker ps --format '{{.Names}}' | grep -Ei 'photon' | head -n1)"
  ok "Contenedor Photon ($photon_name)"
else
  warn "No se detecta contenedor Photon en ejecución"
fi

section "Valhalla — límite moto"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$VALHALLA_CONTAINER"; then
  moto_line="$(docker exec "$VALHALLA_CONTAINER" grep -A3 '"motorcycle"' /custom_files/valhalla.json 2>/dev/null || true)"
  max_distance="$(echo "$moto_line" | grep max_distance | head -n1 | sed -E 's/[^0-9.]//g')"
  if [[ -n "$max_distance" ]]; then
    max_int="${max_distance%%.*}"
    if [[ "$max_int" -ge "$MOTO_MIN_DISTANCE" ]]; then
      ok "max_distance motorcycle = ${max_distance} m (>= ${MOTO_MIN_DISTANCE})"
    else
      warn "max_distance motorcycle = ${max_distance} m (recomendado >= ${MOTO_MIN_DISTANCE})"
    fi
  else
    fail "No se pudo leer max_distance de /custom_files/valhalla.json"
  fi
else
  warn "Sin contenedor Valhalla — omitida lectura de config"
fi

section "Endpoints HTTPS"
route_body='{"locations":[{"lat":41.65,"lon":-0.88},{"lat":40.42,"lon":-3.70}],"costing":"motorcycle","shape_format":"polyline6"}'
route_code="$(http_code -X POST "${VALHALLA_HOST}/route" -H 'Content-Type: application/json' -d "$route_body")"
if [[ "$route_code" == "200" ]]; then
  ok "POST ${VALHALLA_HOST}/route → $route_code"
else
  fail "POST ${VALHALLA_HOST}/route → $route_code"
fi

photon_code="$(http_code "${PHOTON_HOST}/api?q=Zaragoza&lang=default&limit=1")"
if [[ "$photon_code" == "200" ]]; then
  ok "GET ${PHOTON_HOST}/api → $photon_code"
else
  fail "GET ${PHOTON_HOST}/api → $photon_code"
fi

radares_code="$(http_code -I "${VALHALLA_HOST}/radares/es.json")"
if [[ "$radares_code" == "200" ]]; then
  ok "GET ${VALHALLA_HOST}/radares/es.json → $radares_code"
else
  fail "GET radares/es.json → $radares_code"
fi

fuel_code="$(http_code -I "${VALHALLA_HOST}/gasolineras/es.json")"
if [[ "$fuel_code" == "200" ]]; then
  ok "GET ${VALHALLA_HOST}/gasolineras/es.json → $fuel_code"
else
  fail "GET gasolineras/es.json → $fuel_code"
fi

pmtiles_code="$(http_code -I "${VALHALLA_HOST}/maps/aragon.pmtiles")"
if [[ "$pmtiles_code" == "200" ]]; then
  ok "GET ${VALHALLA_HOST}/maps/aragon.pmtiles → $pmtiles_code"
else
  fail "GET maps/aragon.pmtiles → $pmtiles_code"
fi

section "Bundles — frescura (updatedAt)"
check_json_date() {
  local url="$1"
  local label="$2"
  local json updated days
  json="$(curl -sS --connect-timeout 12 --max-time 60 "$url" 2>/dev/null || true)"
  if [[ -z "$json" ]]; then
    warn "$label: no se pudo descargar JSON"
    return
  fi
  updated="$(echo "$json" | sed -n 's/.*"updatedAt"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
  if [[ -z "$updated" ]]; then
    warn "$label: sin campo updatedAt"
    return
  fi
  if updated_epoch="$(date -d "$updated" +%s 2>/dev/null)"; then
    now_epoch="$(date +%s)"
    days=$(( (now_epoch - updated_epoch) / 86400 ))
    if [[ "$days" -le 2 ]]; then
      ok "$label updatedAt=$updated (${days}d)"
    elif [[ "$days" -le 7 ]]; then
      warn "$label updatedAt=$updated (${days}d — revisar cron)"
    else
      fail "$label updatedAt=$updated (${days}d — datos muy viejos)"
    fi
  else
    warn "$label updatedAt=$updated (fecha no parseable)"
  fi
}

check_json_date "${VALHALLA_HOST}/radares/es.json" "Radares"
check_json_date "${VALHALLA_HOST}/gasolineras/es.json" "Gasolineras"

section "Disco"
if df_output="$(df -BG / 2>/dev/null | tail -n1)"; then
  avail_gb="$(echo "$df_output" | awk '{print $4}' | tr -d 'G')"
  used_pct="$(echo "$df_output" | awk '{print $5}')"
  if [[ "$avail_gb" -ge "$MIN_DISK_GB" ]]; then
    ok "Disco /: ${avail_gb}G libres (${used_pct} usado)"
  else
    warn "Disco /: ${avail_gb}G libres (< ${MIN_DISK_GB}G recomendados)"
  fi
else
  warn "No se pudo leer df -h /"
fi

section "Cron (radares / gasolineras)"
if crontab -l 2>/dev/null | grep -q radares; then
  ok "Cron radares configurado"
else
  warn "Cron radares no encontrado en crontab del usuario actual"
fi
if crontab -l 2>/dev/null | grep -q gasolineras; then
  ok "Cron gasolineras configurado"
else
  warn "Cron gasolineras no encontrado en crontab del usuario actual"
fi
if sudo crontab -l 2>/dev/null | grep -Eq 'radares|gasolineras'; then
  ok "Cron en root (sudo crontab)"
fi

section "Resumen"
echo "  FAIL: $FAIL_COUNT   WARN: $WARN_COUNT"
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "  Estado general: FAIL"
  exit 1
fi
if [[ "$WARN_COUNT" -gt 0 ]]; then
  echo "  Estado general: WARN (revisar avisos)"
  exit 0
fi
echo "  Estado general: OK"
exit 0
