# LocMotos

Rastreo de ubicación en tiempo real para grupos de moteros (Android + Flutter + Firebase).

## Firebase (ya hecho)

Proyecto: `locmotos-project`. Package: `com.locmotos.loc_motos`.

## Login (correo, Google o solo nombre)

En [Firebase Console](https://console.firebase.google.com/project/locmotos-project/authentication/providers):

1. **Authentication** → **Sign-in method**.
2. Activa **Correo/contraseña** (Email/Password). Guárdalo.
3. Activa **Google** (guárdalo).
4. Activa **Anonymous** / **Anónimo**.
5. **Project settings** (engranaje) → tu app Android → **Add fingerprint** y pega el SHA-1 de debug:

```
74:C2:2B:09:74:60:9A:AB:64:18:5A:8A:A4:2E:37:E5:F3:82:E2:C3
```

5. Crea **Firestore** (modo producción o prueba) si aún no existe. Las reglas están en `firestore.rules`.
