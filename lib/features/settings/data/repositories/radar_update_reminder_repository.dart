import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Aviso al abrir la app si los radares llevan demasiado sin actualizar.
class RadarUpdateReminderPreferences extends Equatable {
  const RadarUpdateReminderPreferences({
    this.enabled = true,
    this.intervalDays = 14,
  });

  static const defaults = RadarUpdateReminderPreferences();

  static const minIntervalDays = 1;
  static const maxIntervalDays = 365;

  /// Si false, no se muestra el aviso al entrar.
  final bool enabled;

  /// Días sin actualizar a partir de los cuales se avisa.
  final int intervalDays;

  RadarUpdateReminderPreferences copyWith({
    bool? enabled,
    int? intervalDays,
  }) {
    return RadarUpdateReminderPreferences(
      enabled: enabled ?? this.enabled,
      intervalDays: intervalDays ?? this.intervalDays,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'intervalDays': intervalDays,
      };

  factory RadarUpdateReminderPreferences.fromJson(Map<String, dynamic> json) {
    final rawDays = json['intervalDays'];
    final days = rawDays is int
        ? rawDays
        : int.tryParse('$rawDays') ?? defaults.intervalDays;
    return RadarUpdateReminderPreferences(
      enabled: json['enabled'] as bool? ?? true,
      intervalDays: days.clamp(minIntervalDays, maxIntervalDays),
    );
  }

  @override
  List<Object?> get props => [enabled, intervalDays];
}

class RadarUpdateReminderRepository {
  static const _boxName = 'radar_update_reminder';
  static const _key = 'prefs_v1';

  Box<String>? _box;

  Future<Box<String>> _open() async {
    _box ??= await Hive.openBox<String>(_boxName);
    return _box!;
  }

  Future<RadarUpdateReminderPreferences> load() async {
    final box = await _open();
    final raw = box.get(_key);
    if (raw == null || raw.isEmpty) {
      return RadarUpdateReminderPreferences.defaults;
    }
    try {
      return RadarUpdateReminderPreferences.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return RadarUpdateReminderPreferences.defaults;
    }
  }

  Future<void> save(RadarUpdateReminderPreferences prefs) async {
    final box = await _open();
    await box.put(_key, jsonEncode(prefs.toJson()));
  }
}
