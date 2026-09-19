# LiveKit (MotoAMG intercom)

Servidor de salas: `livekit-server` (Docker, `network_mode: host`) en
`wss://livekit.albertomaestre.es`.

**Tokens:** los emite el **panel MySQL** (Yii2), no un servicio en el VPS.

`POST /motoamg/groups/<id>/livekit-token`  
`Authorization: Bearer <accessToken MySQL>`

El panel comprueba membresía + `intercom_enabled` y firma el JWT LiveKit con
`motoamgLiveKit.apiKey` / `apiSecret` de `params-local.php`.

## Requisitos

- LiveKit en marcha (`wss://livekit.albertomaestre.es`)
- En el panel: `motoamgLiveKit` con `apiKey: motoamg` y el secreto de `livekit.yaml`

## API key en el VPS

En `/home/ubuntu/livekit/livekit.yaml` la key debe llamarse `motoamg`:

```bash
sudo awk '/^[[:space:]]*motoamg:/{print $2; exit}' /home/ubuntu/livekit/livekit.yaml
```

Si aún aparece `locmotos`, renómbrala (mismo secreto) y reinicia:

```bash
sudo sed -i -E 's/^([[:space:]]*)locmotos:([[:space:]]*)(.*)$/\1motoamg:\2\3/' /home/ubuntu/livekit/livekit.yaml
sudo docker restart livekit-server
```

Script opcional: `rename-api-key-to-motoamg.sh`.

Pega el secreto en el panel (`common/config/params-local.php`):

```php
'motoamgLiveKit' => [
    'url' => 'wss://livekit.albertomaestre.es',
    'apiKey' => 'motoamg',
    'apiSecret' => '…',
    'ttl' => 21600,
],
```

## App Flutter

- `liveKitUrl` = `wss://livekit.albertomaestre.es`
- Token: `IntercomTokenRemoteDataSource` → panel MySQL

## Token-server Node (RETIRADO)

La carpeta `token-server/` y `nginx-token.snippet.conf` son **legado**
(Firebase Auth + Firestore). La app **ya no los usa**.

Si aún corre en el VPS, apágalo:

```bash
sudo systemctl disable --now motoamg-livekit-token 2>/dev/null || true
sudo docker stop motoamg-livekit-token 2>/dev/null || true
sudo docker rm motoamg-livekit-token 2>/dev/null || true
# Quita location /token del nginx de LiveKit y:
sudo nginx -t && sudo systemctl reload nginx
```

**No detengas** el contenedor `livekit-server`.
