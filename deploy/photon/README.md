# Photon en Oracle Cloud (MotoAMG)

Buscador de direcciones propio, complemento de Valhalla.

## Requisitos

- Ubuntu ARM64 (misma VM que Valhalla o aparte)
- **RAM libre:** ~4–6 GB (Photon + JVM)
- **Disco:** ~30–40 GB para dump Europa (incluye España)
- Docker + Docker Compose

## 1. Desplegar Photon

```bash
cd deploy/photon
chmod +x setup.sh
./setup.sh
```

El servicio queda en `http://127.0.0.1:2322` (solo local).

## Imagen Docker usada en producción

```yaml
image: rtuszik/photon-docker:latest
ports:
  - "127.0.0.1:2322:2322"
```

## 2. HTTPS con Nginx

Archivo `/etc/nginx/sites-available/photon` (usa el mismo certificado que Valhalla, p. ej. Certbot):

```nginx
server {
    listen 80;
    server_name photon.albertomaestre.es;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name photon.albertomaestre.es;

    ssl_certificate     /etc/letsencrypt/live/photon.albertomaestre.es/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/photon.albertomaestre.es/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:2322;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
    }
}
```

```bash
sudo ln -sf /etc/nginx/sites-available/photon /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

Prueba local en el servidor (debe responder JSON, no HTML):

```bash
curl -s "http://127.0.0.1:2322/api?q=Siguenza&lang=es&limit=2" | head -c 200
curl -s "https://photon.albertomaestre.es/api?q=Siguenza&lang=es&limit=2" | head -c 200
```

Si HTTPS devuelve **502 Bad Gateway**: Photon aún no está listo o no escucha en 2322. Revisa:

```bash
docker ps
docker logs --tail 50 <contenedor_photon>
curl http://127.0.0.1:2322/api?q=test
```

## 3. Activar en MotoAMG

En `lib/core/constants/navigation_constants.dart`:

```dart
static const String photonBaseUrl = 'https://photon.albertomaestre.es';
```

Reinstala la app. El buscador usará Photon automáticamente (sin Nominatim público).

## Dump solo España (opcional, avanzado)

El script por defecto descarga **Europa** (más simple). Para menos disco:

1. Exportar JSON desde Nominatim con `spain.osm.pbf`
2. Importar en Photon con `-nominatim-import`

Ver: https://github.com/komoot/photon

## Arquitectura

| Servicio | URL | Función |
|----------|-----|---------|
| Valhalla | https://valhalla.albertomaestre.es | Rutas moto |
| Photon | https://photon.albertomaestre.es | Buscar direcciones |

## Mantenimiento

- Actualizar mapa cada 1–2 meses (re-descargar dump o reimportar)
- Monitorizar RAM: `docker stats motoamg-photon`
