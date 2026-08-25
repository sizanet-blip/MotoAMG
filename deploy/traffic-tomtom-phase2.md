# Fase 2 — Tráfico en vivo (TomTom) — no implementado

Documentación de alcance futuro. La fase 1 de avisos moto (peajes Valhalla, gasolineras/radares Overpass, curvas por geometría) **no** usa TomTom ni API keys de pago.

## Proveedor previsto

- **TomTom Routing API** con tráfico (ETA realista en preview).
- **TomTom Traffic Incidents** (retrasos / incidentes en HUD).

## Cuotas (orientativas, free tier → pay-as-you-grow)

- ~20 000 rutas/mes (Routing).
- ~2 500 detalles de incidente/mes.

Revisar siempre los límites actuales en la consola TomTom.

## Uso previsto en LocMotos

1. **Preview:** ETA con tráfico al calcular / seleccionar ruta.
2. **HUD:** banner “retrasos” o incidentes cercanos a la polilínea.
3. **Polling:** cada 1–2 minutos **solo** con sesión de navegación activa (no en background idle).

## Integración

- Requiere API key en secrets / `--dart-define` (no commitear).
- No mezclar respuestas TomTom con Valhalla en el mismo `NavigationRoute` hasta tener key y cuota clara: Valhalla sigue siendo el motor de geometría/maniobras; TomTom enriquecería ETA e incidentes.
- Degradación: si falla o se agota cuota, mantener ETA Valhalla y ocultar banner de tráfico.

## Fuera de alcance ahora

- Implementación de clientes HTTP TomTom.
- Sustitución de Valhalla como router principal.
