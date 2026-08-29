import 'package:flutter/services.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/settings/data/repositories/emergency_contacts_repository.dart';
import 'package:url_launcher/url_launcher.dart';

/// Acciones al marcar emergencia crítica (Urgente · 112): texto de ubicación y marcador.
abstract final class CriticalEmergencyActions {
  static String locationClipboardMessage({
    required String displayName,
    required GeoPoint point,
  }) {
    final name = displayName.trim().isEmpty ? 'Motero' : displayName.trim();
    final lat = point.lat.toStringAsFixed(5);
    final lng = point.lng.toStringAsFixed(5);
    return 'Emergencia LocMotos — $name\n'
        '$lat, $lng\n'
        '${mapsSearchUrl(point)}';
  }

  static String mapsSearchUrl(GeoPoint point) {
    final lat = point.lat.toStringAsFixed(5);
    final lng = point.lng.toStringAsFixed(5);
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  }

  static Uri mapsSearchUri(GeoPoint point) => Uri.parse(mapsSearchUrl(point));

  static Future<void> copyLocation({
    required String displayName,
    required GeoPoint point,
  }) {
    return Clipboard.setData(
      ClipboardData(
        text: locationClipboardMessage(
          displayName: displayName,
          point: point,
        ),
      ),
    );
  }

  /// Abre el marcador con 112. El usuario debe pulsar Llamar.
  static Future<bool> open112Dialer() async {
    try {
      return await launchUrl(Uri.parse('tel:112'));
    } catch (_) {
      return false;
    }
  }

  /// Copia ubicación y abre el 112.
  static Future<Critical112Result> copyAndOpen112({
    required String displayName,
    required GeoPoint point,
  }) async {
    final hasCoords = point.lat.abs() > 1e-6 || point.lng.abs() > 1e-6;
    if (hasCoords) {
      await copyLocation(displayName: displayName, point: point);
    }
    final opened = await open112Dialer();
    return Critical112Result(
      copied: hasCoords,
      dialerOpened: opened,
    );
  }

  static Future<bool> openSms({
    required EmergencyContact contact,
    required String body,
  }) async {
    final uri = Uri(
      scheme: 'sms',
      path: contact.phoneDigits,
      queryParameters: {'body': body},
    );
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openWhatsApp({
    required EmergencyContact contact,
    required String body,
  }) async {
    final phone = contact.phoneDigits;
    final encoded = Uri.encodeComponent(body);
    final native = Uri.parse('whatsapp://send?phone=$phone&text=$encoded');
    final web = Uri.parse('https://wa.me/$phone?text=$encoded');
    try {
      if (await canLaunchUrl(native)) {
        return await launchUrl(native, mode: LaunchMode.externalApplication);
      }
      return await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        return await launchUrl(web, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }
  }
}

class Critical112Result {
  const Critical112Result({
    required this.copied,
    required this.dialerOpened,
  });

  final bool copied;
  final bool dialerOpened;

  String snackBarMessage({required bool groupQueued}) {
    if (!copied) {
      return dialerOpened
          ? 'Grupo avisado sin GPS preciso. Pulsa Llamar en el teléfono.'
          : 'Grupo avisado sin GPS preciso. No se pudo abrir el 112; márcalo a mano.';
    }
    if (groupQueued) {
      return dialerOpened
          ? 'Ubicación copiada. Pulsa Llamar en el teléfono. El aviso al grupo se enviará con cobertura.'
          : 'Ubicación copiada. No se pudo abrir el 112; márcalo a mano. El aviso al grupo se enviará con cobertura.';
    }
    return dialerOpened
        ? 'Grupo avisado. Ubicación copiada. Pulsa Llamar en el teléfono.'
        : 'Grupo avisado. Ubicación copiada. No se pudo abrir el 112; márcalo a mano.';
  }
}
