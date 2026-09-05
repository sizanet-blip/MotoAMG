# MotoAMG

Pelotón en vivo y GPS para moteros. Salidas en grupo, ubicación del pack, rutas e intercom (Android + Flutter + Firebase).

| | |
|---|---|
| Nombre visible | **MotoAMG** |
| Package Dart | `moto_amg` |
| Android / iOS | `es.albertomaestre.motoamg` |
| Firebase | proyecto `motoamg` |

## Firebase

Proyecto: [`motoamg`](https://console.firebase.google.com/project/motoamg/overview).

Tras clonar / al configurar por primera vez en la consola:

1. **Authentication** → Sign-in method: activa Correo/contraseña, Google y Anónimo.
2. **Firestore** y **Realtime Database** (recomendado `europe-west1` para RTDB).
3. **Project settings** → app Android → **Add fingerprint** (SHA-1 de debug) para Google Sign-In:

```
74:C2:2B:09:74:60:9A:AB:64:18:5A:8A:A4:2E:37:E5:F3:82:E2:C3
```

4. Despliega reglas si aplica: `firestore.rules`, `database.rules.json`.

Los ficheros `android/app/google-services.json` e `ios/Runner/GoogleService-Info.plist` ya apuntan a `motoamg`.
