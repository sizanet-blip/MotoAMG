#!/usr/bin/env bash
# Renombra la API key LiveKit de locmotos → motoamg (mismo secreto).
# Ejecutar en el VPS: bash rename-api-key-to-motoamg.sh
set -euo pipefail

YAML="${LIVEKIT_YAML:-/home/ubuntu/livekit/livekit.yaml}"
TOKEN_ENV="${LIVEKIT_TOKEN_ENV:-/home/ubuntu/livekit/token-server/.env}"

if [[ ! -f "$YAML" ]]; then
  echo "No existe $YAML" >&2
  exit 1
fi

if grep -qE '^[[:space:]]*motoamg:' "$YAML"; then
  echo "Ya existe la key motoamg en $YAML"
else
  if ! grep -qE '^[[:space:]]*locmotos:' "$YAML"; then
    echo "No hay locmotos ni motoamg en $YAML" >&2
    exit 1
  fi
  # Duplica la línea locmotos como motoamg (mismo secreto).
  sudo sed -i -E 's/^([[:space:]]*)locmotos:([[:space:]]*)(.*)$/\1locmotos:\2\3\n\1motoamg:\2\3/' "$YAML"
  echo "Añadida key motoamg (mismo secreto que locmotos)"
fi

# Quita locmotos para que solo quede motoamg.
if grep -qE '^[[:space:]]*locmotos:' "$YAML"; then
  sudo sed -i -E '/^[[:space:]]*locmotos:/d' "$YAML"
  echo "Eliminada key locmotos"
fi

echo "--- keys en yaml ---"
sudo grep -E '^[[:space:]]*(motoamg|locmotos):' "$YAML" || true

if [[ -f "$TOKEN_ENV" ]]; then
  sudo sed -i -E 's/^LIVEKIT_API_KEY=.*/LIVEKIT_API_KEY=motoamg/' "$TOKEN_ENV"
  # Regenera secreto desde yaml si la línea existe.
  SECRET=$(sudo awk '/^[[:space:]]*motoamg:/{print $2; exit}' "$YAML")
  if [[ -n "${SECRET:-}" ]]; then
    sudo sed -i -E "s|^LIVEKIT_API_SECRET=.*|LIVEKIT_API_SECRET=${SECRET}|" "$TOKEN_ENV"
  fi
  echo "Actualizado $TOKEN_ENV → LIVEKIT_API_KEY=motoamg"
fi

# Reinicio LiveKit (docker o systemd).
if docker ps --format '{{.Names}}' 2>/dev/null | grep -qi livekit; then
  NAME=$(docker ps --format '{{.Names}}' | grep -i livekit | head -1)
  echo "Reiniciando contenedor $NAME"
  sudo docker restart "$NAME"
elif systemctl list-units --type=service --all 2>/dev/null | grep -qi livekit; then
  SVC=$(systemctl list-units --type=service --all --no-legend | awk '{print $1}' | grep -i livekit | head -1)
  echo "Reiniciando servicio $SVC"
  sudo systemctl restart "$SVC"
else
  echo "Aviso: no detecté contenedor/servicio livekit; reinícialo a mano."
fi

if systemctl list-units --type=service --all 2>/dev/null | grep -qi 'livekit-token\|motoamg-livekit'; then
  SVC=$(systemctl list-units --type=service --all --no-legend | awk '{print $1}' | grep -Ei 'livekit-token|motoamg-livekit' | head -1)
  echo "Reiniciando token server $SVC"
  sudo systemctl restart "$SVC" || true
fi

echo "Listo. Panel: motoamgLiveKit.apiKey = motoamg (mismo apiSecret)."
