# Inventario de gasolineras (`es.json`)

Genera el fichero que sirve nginx en:

`https://valhalla.albertomaestre.es/gasolineras/es.json`

Fuente: API pública de precios de carburantes (MITECO / Ministerio).

## Nginx

En el mismo `server` de Valhalla:

```nginx
    location /gasolineras/ {
        alias /var/www/gasolineras/;
        autoindex off;
        sendfile on;
        tcp_nopush on;
        default_type application/json;
        add_header Access-Control-Allow-Origin *;
        add_header Cache-Control "public, max-age=3600";
    }
```

```bash
sudo mkdir -p /var/www/gasolineras /opt/locmotos/gasolineras
sudo nginx -t && sudo systemctl reload nginx
```

## Instalación

```bash
sudo cp build_es_json.py /opt/locmotos/gasolineras/
sudo python3 /opt/locmotos/gasolineras/build_es_json.py
curl -I https://valhalla.albertomaestre.es/gasolineras/es.json
```

## Cron diario

```
45 4 * * * /usr/bin/python3 /opt/locmotos/gasolineras/build_es_json.py >> /var/log/gasolineras-build.log 2>&1
```

## Formato

```json
{
  "version": 1,
  "updatedAt": "…",
  "count": 12000,
  "stations": [
    {
      "id": "1234",
      "lat": 41.65,
      "lng": -0.88,
      "name": "Repsol",
      "brand": "Repsol",
      "prices": { "gasolina95": 1.429, "gasoleoA": 1.389 }
    }
  ]
}
```
