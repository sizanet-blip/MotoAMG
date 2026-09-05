# MotoAMG — PMTiles por CCAA (Protomaps).

**Importante:** `https://build.protomaps.com/` **sin fecha devuelve 404**. Es normal.

Los ficheros válidos llevan fecha:

`https://build.protomaps.com/20260826.pmtiles`

Lista de builds recientes: **https://maps.protomaps.com/builds/**

## Cómo funciona

1. Protomaps publica un mapa mundial diario (ver [maps.protomaps.com/builds](https://maps.protomaps.com/builds))
2. URL de descarga: `https://build.protomaps.com/YYYYMMDD.pmtiles`
3. El CLI [go-pmtiles](https://github.com/protomaps/go-pmtiles) **extrae** cada CCAA por bounding box
4. Subes los `.pmtiles` al VPS → `https://valhalla.albertomaestre.es/maps/<ccaa>.pmtiles`

En el repo también existe el script PowerShell `tool/extract_spain_ccaa.ps1` (misma lógica, solo Windows).

---

## 1. Instalar CLI `pmtiles`

### Windows

1. Descarga `pmtiles.exe` desde [Releases go-pmtiles](https://github.com/protomaps/go-pmtiles/releases)
2. Colócalo en:

```
MotoAMG/tools/pmtiles/pmtiles.exe
```

### Linux / VPS (solo si tienes mucho disco y RAM)

Descarga el binario para tu arquitectura desde  
https://github.com/protomaps/go-pmtiles/releases  
y colócalo en el PATH como `pmtiles`.

**Recomendación:** generar en tu **PC** (Windows) y subir al VPS. Castilla y León solo ya son ~600 MB.

---

## 2. Generar todas las CCAA

Desde la raíz del proyecto:

```bash
python3 deploy/pmtiles/build_ccaa_pmtiles.py
```

Salida:

```
maps/offline/andalucia.pmtiles
maps/offline/aragon.pmtiles
...
maps/offline/catalog_sizes.json
maps/offline/extract_log.txt
```

### Si falla al buscar el build

Listar builds disponibles:

```bash
python3 deploy/pmtiles/list_protomaps_builds.py
python3 deploy/pmtiles/list_protomaps_builds.py --days 30
```

Abre https://maps.protomaps.com/builds , copia la fecha del primer build y pásala al script:

```bash
python3 deploy/pmtiles/build_ccaa_pmtiles.py \
  --source https://build.protomaps.com/20260826.pmtiles
```

Comprobar que la URL responde (debe ser `200`, no `404`):

```bash
curl -I https://build.protomaps.com/20260826.pmtiles
```

### Opciones útiles

```bash
# Solo algunas regiones
python3 deploy/pmtiles/build_ccaa_pmtiles.py --only aragon,madrid

# Forzar regeneración
python3 deploy/pmtiles/build_ccaa_pmtiles.py --force

# Ver plan sin ejecutar
python3 deploy/pmtiles/build_ccaa_pmtiles.py --dry-run

# Generar y subir al VPS (requiere scp)
python3 deploy/pmtiles/build_ccaa_pmtiles.py --upload ubuntu@TU_IP:/var/www/maps/
```

En Windows (PowerShell), alternativa ya existente:

```powershell
.\tool\extract_spain_ccaa.ps1
```

---

## 3. Subir al VPS

Sustituye la ruta destino por donde nginx sirve `/maps/` (ajústala si es distinta):

```bash
scp maps/offline/*.pmtiles ubuntu@TU_IP:/var/www/maps/
```

Comprobar:

```bash
curl -I https://valhalla.albertomaestre.es/maps/aragon.pmtiles
```

---

## 4. Actualizar tamaños en la app (opcional)

Tras regenerar, `catalog_sizes.json` tiene los bytes reales. Si cambian mucho, actualiza `sizeBytes` en:

`lib/core/constants/navigation_constants.dart` → `availableRegions`

La app funciona igual aunque no actualices (solo afecta al texto de tamaño en ajustes).

---

## 5. Automatizar (cron en PC o VPS)

**No conviene** en el VPS pequeño de Oracle (mucho disco + ancho de banda).

En un PC/Linux con cron:

```cron
# Primer domingo de cada mes, 03:00 — solo ejemplo
0 3 1-7 * 0 cd /ruta/MotoAMG && python3 deploy/pmtiles/build_ccaa_pmtiles.py --force --upload ubuntu@IP:/var/www/maps/ >> /var/log/motoamg-pmtiles.log 2>&1
```

---

## Requisitos

| Recurso | Aproximado |
|---------|------------|
| Disco temporal | 5–15 GB (extracts simultáneos) |
| Tiempo | 1–4 h todas las CCAA (depende de red) |
| Python | 3.10+ (stdlib only) |

---

## Atribución

Datos © [OpenStreetMap](https://www.openstreetmap.org/copyright) · Tiles [Protomaps](https://protomaps.com/)
