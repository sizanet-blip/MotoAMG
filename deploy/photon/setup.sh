#!/usr/bin/env bash
set -euo pipefail

# Photon (Komoot) para LocMotos — Ubuntu ARM64 / Oracle Cloud
# Ejecutar en el servidor: bash setup.sh

PHOTON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${PHOTON_DIR}/photon_data"
mkdir -p "${DATA_DIR}"

# Dump Europa (incluye España). ~15–25 GB comprimido según versión.
# Alternativa más pequeña: importar solo España desde Nominatim (ver README).
PHOTON_DB_URL="${PHOTON_DB_URL:-https://download1.graphhopper.com/public/experimental/photon-db-europe-0.3.0.tar.bz2}"
PHOTON_DB_ARCHIVE="${PHOTON_DIR}/photon-db-europe.tar.bz2"

if [ ! -f "${DATA_DIR}/node_"* ] && [ ! -d "${DATA_DIR}/elasticsearch" ]; then
  echo "==> Descargando base Photon (Europa). Puede tardar bastante..."
  curl -L --fail --retry 3 -o "${PHOTON_DB_ARCHIVE}" "${PHOTON_DB_URL}"
  echo "==> Extrayendo en ${DATA_DIR}..."
  tar -xjf "${PHOTON_DB_ARCHIVE}" -C "${DATA_DIR}"
  rm -f "${PHOTON_DB_ARCHIVE}"
else
  echo "==> Datos Photon ya presentes en ${DATA_DIR}, omitiendo descarga."
fi

echo "==> Arrancando contenedor..."
docker compose -f "${PHOTON_DIR}/docker-compose.yml" up -d

echo ""
echo "Photon escuchando en http://127.0.0.1:2322"
echo "Prueba:"
echo "  curl 'http://127.0.0.1:2322/api?q=paseo+de+los+olmos+siguenza&lang=es&limit=3'"
echo ""
echo "Siguiente paso: proxy HTTPS (Caddy) → photon.albertomaestre.es"
echo "Luego en LocMotos: photonBaseUrl = 'https://photon.albertomaestre.es'"
