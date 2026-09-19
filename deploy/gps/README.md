# MotoAMG GPS (Realtime en Oracle)

WebSocket + Redis para posiciones en vivo del pelotón.
URL: `wss://gps.albertomaestre.es/ws`  
Health: `https://gps.albertomaestre.es/health`

Auth: JWT HS256 emitido por el **panel** (MySQL). El GPS no habla con MySQL.

## En el VPS

```
/home/ubuntu/motoamg-gps/
├── docker-compose.yml    # Redis
└── server/
    ├── .env
    ├── server.js
    ├── mint-token.js     # solo pruebas
    └── package.json
```

Systemd: `motoamg-gps.service`

## Protocolo WS

1. Conectar a `/ws` → `{ "type": "hello", "auth": "jwt" }`
2. `join` con token:
```json
{"type":"join","groupId":"abc","token":"<JWT>"}
```
3. `publish`:
```json
{"type":"publish","lat":41.65,"lng":-0.88,"heading":90,"speed":12}
```
4. Recibes `location` de otros / `clear` al salir.

### Avisos / paradas / voz (mismo socket)

Tras el `join`, el snapshot incluye `incidents` y `stops`. Tipos:

| Cliente → server | Server → todos |
|------------------|----------------|
| `publish_incident` | `incident` |
| `clear_incident` | `incident_cleared` |
| `publish_stop` | `stop` (+ `stop_published` al emisor) |
| `clear_stop` | `stop_cleared` |
| `publish_voice` | `voice` (efímero) |

Estado de avisos/paradas en Redis (`alert:…`, `stop:…`); **no** se borran al desconectar el socket (solo la location).

### Claims JWT (panel)

| Claim | Uso |
|-------|-----|
| `sub` | uid |
| `displayName` | nombre en mapa |
| `groupIds` | grupos permitidos (array) |
| `iss` | `motoamg-panel` |
| alg | HS256 |
| exp | obligatorio |

Mismo `JWT_SECRET` en panel y en `/home/ubuntu/motoamg-gps/server/.env`.

## Prueba local (sin panel)

```bash
cd /home/ubuntu/motoamg-gps/server
TOKEN=$(node mint-token.js motoA "Moto A" test1)
npx --yes wscat -c wss://gps.albertomaestre.es/ws
# luego: {"type":"join","groupId":"test1","token":"...pegar TOKEN..."}
```
