import 'dart:async';
import 'dart:io';

import 'package:loc_motos/features/navigation/domain/exceptions/navigation_exceptions.dart';

/// Textos cortos para el usuario (sin nombres de servidor ni códigos técnicos).
abstract final class NavigationUserMessages {
  static const routeFailed =
      'No se pudo calcular la ruta. Inténtalo de nuevo.';
  static const routeUnavailable =
      'No se puede calcular la ruta ahora mismo.';
  static const noViableRoute = 'No hay una ruta viable hasta ese destino.';
  static const rerouteFailed =
      'No se pudo actualizar la ruta. Inténtalo de nuevo.';
  static const rerouteOffline =
      'Sin conexión — no se puede recalcular. Sigue el trazado o vuelve a la ruta.';
  static const offlineGuidance =
      'Sin conexión · guía con la ruta ya calculada';
  static const searchFailed =
      'No se pudo buscar la dirección. Inténtalo de nuevo.';
  static const searchUnavailable =
      'La búsqueda de direcciones no está disponible.';
  static const noConnection =
      'Sin conexión. Comprueba internet e inténtalo de nuevo.';
  static const timeout =
      'La conexión tarda demasiado. Inténtalo de nuevo.';
  static const noGps = 'Activa la ubicación o escribe una dirección.';
  static const noSavedRoute = 'No hay ninguna ruta guardada para continuar.';
  static const mapNotOnServer =
      'Este mapa aún no está disponible en el servidor.';
  static const mapDownloadFailed =
      'No se pudo descargar el mapa. Inténtalo de nuevo.';
  static const mapIncomplete =
      'La descarga quedó incompleta. Vuelve a intentarlo.';
  static const mapDownloadCancelled =
      'Descarga pausada. Puedes continuar más tarde.';
  static const mapInsufficientSpace =
      'No hay espacio suficiente en el dispositivo para este mapa.';
  static const generic = 'Algo salió mal. Inténtalo de nuevo.';
}

/// Convierte cualquier error de navegación en un mensaje entendible.
String navigationUserMessage(Object error) {
  if (error is NavigationException) {
    return error.message;
  }
  if (error is TimeoutException) {
    return NavigationUserMessages.timeout;
  }
  if (error is SocketException) {
    return NavigationUserMessages.noConnection;
  }
  final text = error.toString().toLowerCase();
  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable') ||
      text.contains('connection refused') ||
      text.contains('connection reset')) {
    return NavigationUserMessages.noConnection;
  }
  if (text.contains('timeout') || text.contains('timed out')) {
    return NavigationUserMessages.timeout;
  }
  return NavigationUserMessages.generic;
}
