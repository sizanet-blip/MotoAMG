# Mantenimiento del VPS MotoAMG

Guía operativa para el servidor Oracle Cloud (`*.albertomaestre.es`).

**Instalación Valhalla activa:**

- Carpeta: `/home/ubuntu/valhalla/`
- Config: `/home/ubuntu/valhalla/custom_files/valhalla.json`
- Contenedor: `valhalla` (`ghcr.io/gis-ops/docker-valhalla/valhalla:latest`)
- *(Ignorar `/var/www/proyectos/valhalla/` — copia antigua no montada)*

**Comprobación rápida:**

```bash
sed -i 's/\r$//' ~/vps-healthcheck.sh   # solo si se copió desde Windows
~/vps-healthcheck.sh
```

---

## Lo que ya se actualiza solo

| Qué | Cuándo | Comando manual (opcional) |
|-----|--------|---------------------------|
| **Radares** (`es.json`) | Cada día **04:15** | `sudo python3 /opt/motoamg/radares/build_es_json.py` |
| **Gasolineras** (`es.json`) | Cada día **04:45** | `sudo python3 /opt/motoamg/gasolineras/build_es_json.py` |

Cron en **root** (`sudo crontab -l`):

```
15 4 * * * /usr/bin/python3 /opt/motoamg/radares/build_es_json.py >> /var/log/radares-build.log 2>&1
45 4 * * * /usr/bin/python3 /opt/motoamg/gasolineras/build_es_json.py >> /var/log/gasolineras-build.log 2>&1
```

Logs:

```bash
tail -30 /var/log/radares-build.log
tail -30 /var/log/gasolineras-build.log
```

---

## Frecuencia recomendada

| Servicio | Cada cuánto | Esfuerzo | Para qué |
|----------|-------------|----------|----------|
| Radares / gasolineras | **Automático** (diario) | — | POI y precios en la app |
| **Valhalla** (rutas) | **1–2 meses** | Alto (horas) | Carreteras nuevas, sentidos |
| **Photon** (buscador) | **1–2 meses** | Alto | Direcciones nuevas |
| **PMTiles** (mapas offline) | **1–3 meses** | Muy alto | Mapa base offline CCAA |
| Imagen Docker | **Trimestral** | Bajo | Parches de seguridad |

El mapa **online** de vista previa (OpenFreeMap) **no** se mantiene en tu VPS.

---

## Estructura Valhalla

```bash
ls -lh /home/ubuntu/valhalla/custom_files/
cat /home/ubuntu/valhalla/docker-compose.yml
```

Típico:

```
/home/ubuntu/valhalla/
├── docker-compose.yml
└── custom_files/
    ├── valhalla.json           ← config (max_distance moto: 1500000)
    ├── spain-latest.osm.pbf    ← mapa OSM
    └── valhalla_tiles/ o .tar  ← grafo (generado; no editar a mano)
```

---

## Actualizar Valhalla (rutas moto)

**Cuándo:** cada 1–2 meses, o si fallan rutas en zonas recién abiertas.

**Tiempo:** descarga ~30 min + reconstrucción **varias horas**. Mejor de madrugada.

```bash
cd /home/ubuntu/valhalla

# 1. Copia de seguridad de la config
cp custom_files/valhalla.json ~/valhalla.json.bak

# 2. Mapa OSM España nuevo (~1.5 GB)
wget -O custom_files/spain-latest.osm.pbf \
  https://download.geofabrik.de/europe/spain-latest.osm.pbf

# 3. Reiniciar — docker-valhalla detecta el PBF nuevo y reconstruye tiles
docker restart valhalla

# 4. Ver progreso
docker logs -f valhalla
```

**Probar** cuando termine (debe devolver `200`):

```bash
curl -s -o /dev/null -w "%{http_code}" -X POST \
  https://valhalla.albertomaestre.es/route \
  -H "Content-Type: application/json" \
  -d '{"locations":[{"lat":41.65,"lon":-0.88},{"lat":40.42,"lon":-3.70}],"costing":"motorcycle","shape_format":"polyline6"}'
```

**Comprobar límite moto** (debe ser `1500000.0`):

```bash
docker exec valhalla grep -A2 '"motorcycle"' /custom_files/valhalla.json
```

Si se perdió tras la actualización:

```bash
cp ~/valhalla.json.bak /home/ubuntu/valhalla/custom_files/valhalla.json
docker restart valhalla
```

### Solo actualizar imagen Docker (sin mapa nuevo)

```bash
cd /home/ubuntu/valhalla
docker compose pull
docker compose up -d
```

---

## Actualizar Photon (buscador)

**Cuándo:** cada 1–2 meses si el buscador se queda corto.

**Espacio:** ~30–40 GB libres durante la actualización.

Localizar instalación:

```bash
docker ps | grep photon
find /home/ubuntu -name "docker-compose.yml" 2>/dev/null | xargs grep -l photon 2>/dev/null
```

```bash
cd /ruta/a/photon
docker compose down
rm -rf photon_data/*
bash setup.sh
docker logs -f photon
```

Probar:

```bash
curl "http://127.0.0.1:2322/api?q=Zaragoza&lang=default&limit=2"
curl "https://photon.albertomaestre.es/api?q=Zaragoza&lang=default&limit=2"
```

Ver también: `deploy/photon/README.md`

---

## PMTiles (mapas offline por CCAA)

URLs: `https://valhalla.albertomaestre.es/maps/<ccaa>.pmtiles`

**Generación automática** (Protomaps + script del repo):

```bash
python3 deploy/pmtiles/build_ccaa_pmtiles.py
python3 deploy/pmtiles/build_ccaa_pmtiles.py --upload ubuntu@TU_IP:/var/www/maps/
```

Ver guía completa: **`deploy/pmtiles/README.md`**

Alternativa Windows: `.\tool\extract_spain_ccaa.ps1`

Comprobar en el VPS:

```bash
curl -I https://valhalla.albertomaestre.es/maps/aragon.pmtiles
```

---

## Calendario práctico

| Frecuencia | Acción |
|------------|--------|
| **Diario** | Nada (cron radares/gasolineras) |
| **Semanal** | `~/vps-healthcheck.sh` |
| **1–2 meses** | Valhalla: nuevo PBF + `docker restart valhalla` |
| **1–2 meses** | Photon: reimportar dump (opcional) |
| **1–3 meses** | PMTiles: regenerar y subir (offline) |
| **Trimestral** | `docker compose pull` (Valhalla / Photon) |

---

## Orden si actualizas “todo el mapa”

1. Descargar **spain-latest.osm.pbf** (Geofabrik) — una vez sirve para varias cosas.
2. **Valhalla** → nuevo PBF + reiniciar contenedor.
3. **Radares** → cron diario; manual:  
   `sudo python3 /opt/motoamg/radares/build_es_json.py --force-pbf-download`
4. **PMTiles** → regenerar en PC y subir al VPS.
5. **Photon** → reimportar dump (proceso aparte).
6. **Gasolineras** → cron diario (MITECO, no OSM).

---

## Configuración Valhalla (referencia)

Límite distancia moto en `custom_files/valhalla.json`:

```json
"motorcycle": {
  "max_distance": 1500000.0
}
```

1500000 m = **1500 km**. Editar con `sudo nano`, luego `docker restart valhalla`.

---

## URLs de la app

| Servicio | URL |
|----------|-----|
| Valhalla (rutas) | https://valhalla.albertomaestre.es |
| Photon (buscador) | https://photon.albertomaestre.es |
| LiveKit (intercom) | https://livekit.albertomaestre.es (`wss://…`) |
| LiveKit tokens | Panel MySQL: `POST /motoamg/groups/<id>/livekit-token` (el `/token` Node del VPS está retirado) |
| Radares | https://valhalla.albertomaestre.es/radares/es.json |
| Gasolineras | https://valhalla.albertomaestre.es/gasolineras/es.json |
| PMTiles | https://valhalla.albertomaestre.es/maps/ |

---

## Scripts del repo

| Fichero | Uso |
|---------|-----|
| `deploy/vps-healthcheck.sh` | Comprobación rápida del VPS |
| `deploy/radares/build_es_json.py` | Inventario radares |
| `deploy/gasolineras/build_es_json.py` | Inventario gasolineras |
| `deploy/photon/setup.sh` | Instalar / actualizar Photon |

Copiar healthcheck al VPS (desde PC Windows):

```powershell
scp "RUTA\MotoAMG\deploy\vps-healthcheck.sh" ubuntu@TU_IP:/home/ubuntu/vps-healthcheck.sh
```

En el VPS:

```bash
sed -i 's/\r$//' ~/vps-healthcheck.sh
chmod +x ~/vps-healthcheck.sh
```

---

*Última revisión: agosto 2026*
