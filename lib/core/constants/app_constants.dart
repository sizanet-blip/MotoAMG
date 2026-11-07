/// Constantes de negocio y rutas de Firebase para MotoAMG.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

abstract final class AppConstants {
  static const String appName = 'MotoAMG';
  static const String appIconAsset = 'assets/branding/motoamg-app-icon.png';
  static const String appWordmarkAsset = 'assets/branding/motoamg-wordmark.png';
  static const String homeLandscapeAsset =
      'assets/branding/motoamg-home-landscape.png';
  static const String appTagline = 'Pelotón en vivo y GPS para moteros';
  static const String appShortDescription =
      'Salidas en grupo, ubicación del pack, rutas e intercom';
  static const String developerName = 'Alberto Maestre Gutierrez';
  static const String copyrightNotice = '© 2026 Alberto Maestre Gutierrez';
  static const String supportEmail = 'info@albertomaestre.es';

  /// JSON de versión/APK. Build: `--dart-define=UPDATE_METADATA_URL=https://...`
  static const String updateMetadataUrl = String.fromEnvironment(
    'UPDATE_METADATA_URL',
  );

  /// Inventario unificado de instalaciones (panel Yii2).
  /// Preferente: `INSTALLATION_API_URL`; si vacío, `LICENSE_API_URL`.
  static const String _installationApiUrl = String.fromEnvironment(
    'INSTALLATION_API_URL',
    defaultValue: '',
  );
  static const String _licenseApiUrl = String.fromEnvironment(
    'LICENSE_API_URL',
    defaultValue: '',
  );

  static String get installationApiUrl {
    final a = _installationApiUrl.trim();
    if (a.isNotEmpty) return a;
    return _licenseApiUrl.trim();
  }

  /// Si está vacío, se muestra el texto integrado en la app.
  static const String privacyPolicyUrl = '';
  static const String termsOfUseUrl = '';

  static const String mapAttributionPlain =
      'Mapas: Protomaps · Datos © OpenStreetMap contributors';

  /// Atribuciones de datos y servicios (Acerca de / licencias).
  static const String dataAttributionsPlain =
      'Cartografía y estilos: Protomaps · Datos © OpenStreetMap contributors.\n'
      'Geocodificación: OpenStreetMap Nominatim (cuando aplica).\n'
      'Radares offline: inventarios derivados de fuentes oficiales (DGT / SCT) '
      'y datos OpenStreetMap, servidos o empaquetados para MotoAMG.\n'
      'Gasolineras y precios: inventario público MITECO (carburantes), '
      'cuando está descargado o disponible.\n'
      'Autenticación, datos en la nube e informes de error: Google Firebase.\n'
      'Intercom de voz: LiveKit.\n'
      'Bibliotecas de código abierto: ver «Licencias de software libre».';

  static const String onboardingBox = 'app_onboarding';
  static const String onboardingCompleteKey = 'permissions_v1';
  /// Aceptación de privacidad en este dispositivo (primera instalación).
  static const String privacyAcceptedKey = 'privacy_v1';

  /// Versión de la política: si cambia, cada cuenta debe volver a aceptar.
  /// Versión legal propia de MotoAMG (aceptación en registro / onboarding).
  static const String privacyPolicyVersion = '1.0-2026-10-25';
  static const String termsOfUseVersion = '1.0-2026-10-25';

  /// Intervalo de envío de GPS al nodo RTDB `live_locations`.
  static const Duration locationUpdateInterval = Duration(seconds: 3);

  /// Con la moto parada, no escribir más a menudo que esto.
  /// Corto al inicio del pelotón: si no, el compañero tarda mucho en verte.
  static const Duration locationStoppedPublishInterval = Duration(seconds: 8);

  /// Por debajo de esta velocidad se considera «parado» (~5 km/h).
  static const double locationStoppedSpeedMps = 1.4;

  /// Distancia mínima (metros) para considerar un movimiento y escribir.
  static const int locationDistanceFilterMeters = 8;

  /// Comprobación del GPS real (no la última posición guardada).
  static const Duration gpsCheckInterval = Duration(seconds: 5);

  /// Si un compañero no actualiza en este tiempo, su moto muestra «Sin señal».
  static const Duration gpsStaleAfter = Duration(minutes: 2);

  /// Aviso de pelotón: compañero se queda atrás (metros desde ti).
  static const double groupBehindAlertMeters = 1200;

  /// Aviso más fuerte: compañero muy lejos del pelotón.
  static const double groupFarAlertMeters = 2500;

  /// En el HUD de navegación, mostrar también a quien esté más lejos que esto
  /// (además de cabecera, cola, incidencias y sin señal).
  static const double groupHudShowFarMeters = 800;

  /// No repetir el mismo aviso de pelotón al mismo motero antes de esto.
  static const Duration groupPackAlertCooldown = Duration(minutes: 3);

  /// Si vuelve a acercarse por debajo de esto, se puede volver a avisar después.
  static const double groupPackAlertResetMeters = 600;

  static const String locationNotificationTitle = 'MotoAMG';
  static const String locationNotificationText =
      'Compartiendo tu ubicación con el grupo';
  static const String locationNotificationChannel = 'Ubicación en ruta';

  /// Notificación mientras navegas con ruta activa (servicio en primer plano).
  static const String navigationNotificationTitle = 'MotoAMG';
  static const String navigationNotificationText = 'Navegando en ruta';
  static const String navigationNotificationChannel = 'Navegación GPS';

  /// Longitud del código de sala (letras/números sin caracteres ambiguos).
  static const int groupCodeLength = 6;

  static const int minDisplayNameLength = 2;
  static const int maxDisplayNameLength = 24;
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 20;
  static const int minPasswordLength = 8;
  static const int maxBikeFieldLength = 32;
  static const int maxPlateLength = 12;

  /// Dominio sintético para cuentas con usuario (sin correo real).
  static const String usernameAuthDomain = 'users.motoamg.app';
  static const int minGroupNameLength = 2;
  static const int maxGroupNameLength = 40;

  // --- Clubs (acceso y cupos; distinto de grupos de ruta / salidas) ---
  static const int clubInviteCodeLength = 8;
  static const int minClubNameLength = 3;
  static const int maxClubNameLength = 60;

  // --- API MySQL (panel) ---
  /// Host virtual del panel (Apache/IIS en el PC).
  static const String apiHostHeader = 'panel.amg.desarrollo';

  /// Base URL. Emulador Android → 10.0.2.2 (el PC). Override: --dart-define=MOTOAMG_API_BASE=...
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('MOTOAMG_API_BASE');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    // ignore: avoid_classes_with_only_static_members
    return _ApiBase.resolve();
  }

  // --- Realtime Database (legado; GPS en vivo migra a WebSocket) ---
  static const String liveLocationsPath = 'live_locations';
  static const String groupAlertsPath = 'group_alerts';
  static const String groupStopsPath = 'group_stops';
  static const String groupVoicePath = 'group_voice';

  // --- GPS en vivo (Oracle WebSocket + token) ---
  static const String gpsWsUrl = String.fromEnvironment(
    'GPS_WS_URL',
    defaultValue: 'wss://gps.albertomaestre.es/ws',
  );

  static String get gpsTokenUrl {
    const fromEnv = String.fromEnvironment('GPS_TOKEN_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return '${apiBaseUrl.replaceAll(RegExp(r'/$'), '')}/motoamg/gps-token';
  }

  static const String gpsApiKey = String.fromEnvironment(
    'GPS_API_KEY',
    defaultValue: 'motoamg-dev-api-key-change-me',
  );

  // --- LiveKit intercom ---
  static const String liveKitUrl = 'wss://livekit.albertomaestre.es';
}

/// Resolución de base URL del panel según plataforma.
abstract final class _ApiBase {
  static String resolve() {
    // Emulador Android: 10.0.2.2 = localhost del PC (HTTPS + Host virtual).
    if (!kIsWeb && Platform.isAndroid) {
      return 'https://10.0.2.2';
    }
    // Escritorio / iOS sim: hostname local.
    return 'https://panel.amg.desarrollo';
  }
}
