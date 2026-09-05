import 'dart:async';

import 'package:flutter/services.dart';
import 'package:moto_amg/features/groups/domain/entities/group_incident.dart';
import 'package:moto_amg/features/groups/domain/entities/group_voice_announcement.dart';
import 'package:moto_amg/features/navigation/data/services/navigation_voice_service.dart';

/// Feedback háptico / sonido / voz para incidencias y pelotón.
///
/// La emergencia es claramente más agresiva que avería o separado.
abstract final class GroupRideAlertFeedback {
  /// Incidencia nueva de otro motero.
  static Future<void> playIncident({
    required GroupIncident incident,
    required String name,
    NavigationVoiceService? voice,
  }) async {
    final label = name.trim().isEmpty ? 'Un compañero' : name.trim();
    switch (incident.type) {
      case GroupIncidentType.emergencia:
        await _playEmergency(
          critical: incident.isCriticalEmergency,
          spoken: incident.isCriticalEmergency
              ? 'Emergencia urgente de $label'
              : 'Emergencia de $label',
          voice: voice,
        );
      case GroupIncidentType.averia:
        await _playStandard(
          spoken: 'Avería de $label',
          voice: voice,
          pulses: 1,
        );
      case GroupIncidentType.espera:
        await _playStandard(
          spoken: '$label pide esperar y reunir al grupo',
          voice: voice,
          pulses: 2,
        );
      case GroupIncidentType.separado:
        await _playStandard(
          spoken: '$label se ha separado del grupo',
          voice: voice,
          pulses: 1,
          softSound: true,
        );
    }
  }

  /// Compañero lejos / atrás (detección automática).
  static Future<void> playPackDistance({
    required String name,
    required String distanceLabel,
    required bool far,
    NavigationVoiceService? voice,
  }) async {
    final label = name.trim().isEmpty ? 'Un compañero' : name.trim();
    final spoken = far
        ? '$label muy lejos, a $distanceLabel'
        : '$label se queda atrás, a $distanceLabel';
    await HapticFeedback.mediumImpact();
    await SystemSound.play(SystemSoundType.alert);
    if (far) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await HapticFeedback.heavyImpact();
    }
    if (voice != null) {
      unawaited(voice.speak(spoken));
    }
  }

  /// Rezagado elige cabecera o destino: aviso de voz al pelotón.
  static Future<void> playVoiceAnnouncement({
    required GroupVoiceAnnouncement announcement,
    NavigationVoiceService? voice,
  }) async {
    await HapticFeedback.mediumImpact();
    await SystemSound.play(SystemSoundType.alert);
    if (voice != null) {
      // Urgente: suena con copiloto muteado y las maniobras no lo cortan.
      unawaited(voice.speakUrgent(announcement.spokenMessage()));
    }
  }

  static Future<void> _playEmergency({
    required bool critical,
    required String spoken,
    NavigationVoiceService? voice,
  }) async {
    // Emergencia: varios golpes + alertas; crítica aún más insistente.
    final rounds = critical ? 3 : 2;
    for (var i = 0; i < rounds; i++) {
      await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
      if (i < rounds - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 220));
      }
    }
    if (voice != null) {
      // La emergencia habla aunque el copiloto de ruta esté silenciado.
      unawaited(voice.speakUrgent(spoken));
    }
  }

  static Future<void> _playStandard({
    required String spoken,
    required int pulses,
    NavigationVoiceService? voice,
    bool softSound = false,
  }) async {
    for (var i = 0; i < pulses; i++) {
      await HapticFeedback.mediumImpact();
      if (i < pulses - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }
    await SystemSound.play(
      softSound ? SystemSoundType.click : SystemSoundType.alert,
    );
    if (voice != null) {
      unawaited(voice.speak(spoken));
    }
  }
}
