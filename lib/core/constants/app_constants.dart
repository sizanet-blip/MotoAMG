/// Constantes de negocio y rutas de Firebase para LocMotos.
abstract final class AppConstants {
  static const String appName = 'LocMotos';
  static const String appIconAsset = 'assets/branding/locmotos-app-icon.png';
  static const String appWordmarkAsset = 'assets/branding/locmotos-wordmark.png';

  /// Intervalo de envío de GPS al nodo RTDB `live_locations`.
  static const Duration locationUpdateInterval = Duration(seconds: 3);

  /// Con la moto parada, no escribir en RTDB más a menudo que esto.
  static const Duration locationStoppedPublishInterval = Duration(seconds: 30);

  /// Por debajo de esta velocidad se considera «parado» (~5 km/h).
  static const double locationStoppedSpeedMps = 1.4;

  /// Distancia mínima (metros) para considerar un movimiento y escribir.
  static const int locationDistanceFilterMeters = 8;

  /// Comprobación del GPS real (no la última posición guardada).
  static const Duration gpsCheckInterval = Duration(seconds: 5);

  /// Si un compañero no actualiza en este tiempo, su moto muestra «Sin señal».
  static const Duration gpsStaleAfter = Duration(minutes: 2);

  static const String locationNotificationTitle = 'LocMotos';
  static const String locationNotificationText =
      'Compartiendo tu ubicación con el grupo';
  static const String locationNotificationChannel = 'Ubicación en ruta';

  /// Notificación mientras navegas con ruta activa (servicio en primer plano).
  static const String navigationNotificationTitle = 'LocMotos';
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
  static const String usernameAuthDomain = 'users.locmotos.app';
  static const int minGroupNameLength = 2;
  static const int maxGroupNameLength = 40;

  // --- Firestore ---
  static const String usersCollection = 'users';
  static const String usernamesCollection = 'usernames';
  static const String groupsCollection = 'groups';
  static const String membersSubcollection = 'members';
  static const String membershipsSubcollection = 'memberships';

  // --- Realtime Database ---
  static const String liveLocationsPath = 'live_locations';
}
