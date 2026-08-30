import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/features/tracking/domain/exceptions/location_exceptions.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceLocationService {
  Future<bool> ensurePermission() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      throw const LocationException(
        'Activa la ubicación del móvil para verte en el mapa.',
      );
    }

    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
    }
    if (status.isPermanentlyDenied) {
      throw const LocationException(
        'El permiso de ubicación está bloqueado. Ábrelo en Ajustes.',
      );
    }
    if (!status.isGranted) {
      throw const LocationException(
        'Sin permiso de ubicación no se puede mostrar tu moto.',
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      var always = await Permission.locationAlways.status;
      if (always.isDenied) {
        always = await Permission.locationAlways.request();
      }
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android 13+: sin notificación el sistema puede parar el servicio en segundo plano.
      final notification = await Permission.notification.status;
      if (notification.isDenied) {
        await Permission.notification.request();
      }
    }
    return true;
  }

  Stream<Position> watchPosition() {
    return Geolocator.getPositionStream(locationSettings: _watchSettings());
  }

  /// GPS para planificar o previsualizar (sin notificación persistente).
  Stream<Position> watchNavigationPosition() {
    return Geolocator.getPositionStream(
      locationSettings: _navigationWatchSettings(foregroundService: false),
    );
  }

  /// GPS en ruta activa: en Android usa servicio en primer plano + notificación.
  Stream<Position> watchActiveNavigationPosition() {
    return Geolocator.getPositionStream(
      locationSettings: _navigationWatchSettings(foregroundService: true),
    );
  }

  LocationSettings _navigationWatchSettings({required bool foregroundService}) {
    // Navegación: fixes frecuentes. El stream del grupo (8 m / 3 s) no sirve en curva.
    if (defaultTargetPlatform == TargetPlatform.android && foregroundService) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 800),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: AppConstants.navigationNotificationTitle,
          notificationText: AppConstants.navigationNotificationText,
          notificationChannelName: AppConstants.navigationNotificationChannel,
          setOngoing: true,
          enableWakeLock: true,
          enableWifiLock: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  Future<Position?> readPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 12));
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  /// Posición del GPS del aparato. Si el emulador apaga «Enable GPS signal», falla.
  Future<Position?> readGpsProviderPosition() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            forceLocationManager: true,
            timeLimit: const Duration(seconds: 4),
          ),
        );
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
    } on LocationServiceDisabledException {
      return null;
    } catch (_) {
      return null;
    }
  }

  LocationSettings _watchSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: AppConstants.locationDistanceFilterMeters,
        intervalDuration: AppConstants.locationUpdateInterval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: AppConstants.locationNotificationTitle,
          notificationText: AppConstants.locationNotificationText,
          notificationChannelName: AppConstants.locationNotificationChannel,
          setOngoing: true,
          enableWakeLock: true,
          enableWifiLock: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: AppConstants.locationDistanceFilterMeters,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: AppConstants.locationDistanceFilterMeters,
    );
  }
}
