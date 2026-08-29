# LiveKit + tokens (LocMotos intercom)

Servidor de salas: `livekit-server` (Docker, `network_mode: host`).  
Tokens de acceso: servicio Node en `127.0.0.1:7882`, expuesto como `https://livekit.albertomaestre.es/token`.

## Requisitos

- LiveKit ya en marcha (`wss://livekit.albertomaestre.es`)
- Cuenta de servicio Firebase (`locmotos-project`) con acceso a Auth + Firestore
- Node.js 20+ o Docker

## 1. Credenciales en el VPS

```bash
sudo mkdir -p /home/ubuntu/livekit/token-server
# Copia serviceAccount.json (Firebase Console → Project settings → Service accounts)
# No lo subas al repo.

sudo tee /home/ubuntu/livekit/token-server/.env >/dev/null <<EOF
PORT=7882
LIVEKIT_URL=wss://livekit.albertomaestre.es
LIVEKIT_API_KEY=locmotos
LIVEKIT_API_SECRET=$(sudo awk '/^[[:space:]]*locmotos:/{print $2; exit}' /home/ubuntu/livekit/livekit.yaml)
GOOGLE_APPLICATION_CREDENTIALS=/home/ubuntu/livekit/token-server/serviceAccount.json
EOF
sudo chmod 600 /home/ubuntu/livekit/token-server/.env
sudo chmod 600 /home/ubuntu/livekit/token-server/serviceAccount.json
```

## 2. Desplegar el token server

Copia el contenido de `deploy/livekit/token-server/` al VPS y:

```bash
cd /home/ubuntu/livekit/token-server
npm ci --omit=dev
# o: docker compose -f docker-compose.token.yml up -d
```

Systemd (recomendado):

```bash
sudo cp locmotos-livekit-token.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now locmotos-livekit-token
sudo systemctl status locmotos-livekit-token
```

Prueba local:

```bash
curl -s http://127.0.0.1:7882/health
# {"ok":true}
```

## 3. Nginx: ruta `/token`

En `/etc/nginx/sites-available/livekit`, **antes** del `location /` de LiveKit:

```nginx
location /token {
    proxy_pass http://127.0.0.1:7882/token;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 30s;
}

location / {
    proxy_pass http://127.0.0.1:7880;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

## 4. API

`POST https://livekit.albertomaestre.es/token`

Headers:

- `Authorization: Bearer <Firebase ID token>`
- `Content-Type: application/json`

Body:

```json
{ "groupId": "<firestore group id>" }
```

Respuesta 200:

```json
{
  "url": "wss://livekit.albertomaestre.es",
  "token": "<livekit jwt>",
  "room": "<groupId>"
}
```

Errores: `401` token Firebase inválido, `403` no es miembro del grupo, `400` body inválido.

## 5. App LocMotos

Constantes en `lib/core/constants/app_constants.dart`:

- `liveKitUrl` = `wss://livekit.albertomaestre.es`
- `liveKitTokenUrl` = `https://livekit.albertomaestre.es/token`
