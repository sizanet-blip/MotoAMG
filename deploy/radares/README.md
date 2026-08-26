# Inventario de radares (`es.json`)

Genera el fichero que sirve nginx en:

`https://valhalla.albertomaestre.es/radares/es.json`

Fuentes:

- DGT DATEX + SCT (oficiales)
- OpenStreetMap vía **Geofabrik** (`spain-latest.osm.pbf`) + **osmium**

## Dependencias

```bash
sudo apt update
sudo apt install -y osmium-tool curl
```

## Instalación

```bash
sudo mkdir -p /opt/locmotos/radares /var/www/radares /var/cache/locmotos/radares
sudo cp build_es_json.py /opt/locmotos/radares/
sudo chmod +x /opt/locmotos/radares/build_es_json.py
```

## Primera generación (solo oficiales)

```bash
sudo python3 /opt/locmotos/radares/build_es_json.py --skip-osm
curl -I https://valhalla.albertomaestre.es/radares/es.json
```

## Generación completa

La **primera** vez descarga ~1.5 GB de Geofabrik (varios minutos).
Luego filtra con osmium (rápido). El PBF se reutiliza 24 h.

```bash
sudo python3 /opt/locmotos/radares/build_es_json.py
```

Opciones útiles:

```bash
# Forzar nueva descarga del PBF
sudo python3 /opt/locmotos/radares/build_es_json.py --force-pbf-download

# Usar un PBF ya descargado
sudo python3 /opt/locmotos/radares/build_es_json.py --pbf /ruta/spain-latest.osm.pbf
```

## Cron diario

```bash
sudo crontab -e
```

```
15 4 * * * /usr/bin/python3 /opt/locmotos/radares/build_es_json.py >> /var/log/radares-build.log 2>&1
```

## Formato

```json
{
  "version": 1,
  "updatedAt": "2026-08-26T…",
  "officialCount": 1234,
  "osmCount": 5678,
  "official": [ { "lat", "lng", "source", "kind", "label", … } ],
  "osm": [ … ],
  "attribution": "© OpenStreetMap contributors (ODbL); DGT NAP; SCT"
}
```
