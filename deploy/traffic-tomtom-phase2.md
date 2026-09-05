# Tráfico en vivo (TomTom) — DESCARTADO por ahora

**Estado (ago 2026):** fuera de alcance. MotoAMG **no** integra TomTom.

La fase de avisos moto (peajes Valhalla, gasolineras/radares, curvas por geometría) sigue sin API keys de pago ni tráfico en vivo.

Si en el futuro se retoma, el alcance previsto era:

- **TomTom Routing** (ETA con tráfico en preview).
- **TomTom Traffic Incidents** (retrasos / incidentes en HUD).
- Valhalla seguiría siendo el motor de geometría/maniobras; TomTom solo enriquecería ETA e incidentes.
- Degradación: si falla o se agota cuota → ETA Valhalla y sin banner de tráfico.

## Fuera de alcance (definitivo por ahora)

- Clientes HTTP TomTom.
- Sustitución de Valhalla como router.
- Polling de tráfico en navegación.

No hay tareas abiertas de este módulo.
