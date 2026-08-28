import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:loc_motos/core/constants/app_constants.dart';

/// Qué motos del grupo se pintan en el mapa / navegación.
enum GroupMateDisplayMode {
  /// Todas las motos del grupo.
  all,

  /// Solo cabecera y cola.
  cabeceraCola,
}

extension GroupMateDisplayModeX on GroupMateDisplayMode {
  String get label => switch (this) {
        GroupMateDisplayMode.all => 'Todas las motos',
        GroupMateDisplayMode.cabeceraCola => 'Solo cabecera y cola',
      };

  String get subtitle => switch (this) {
        GroupMateDisplayMode.all => 'Ver a todo el pelotón en el mapa',
        GroupMateDisplayMode.cabeceraCola =>
          'En marcha solo ves cabecera y cola (menos lío)',
      };

  String get storageValue => name;

  static GroupMateDisplayMode parse(String? raw) {
    for (final mode in GroupMateDisplayMode.values) {
      if (mode.name == raw) {
        return mode;
      }
    }
    return GroupMateDisplayMode.all;
  }
}

/// Preferencias de grupo en ruta: avisos de pelotón + qué motos mostrar.
class GroupPackAlertPreferences extends Equatable {
  const GroupPackAlertPreferences({
    this.enabled = true,
    this.behindMeters = AppConstants.groupBehindAlertMeters,
    this.farMeters = AppConstants.groupFarAlertMeters,
    this.mateDisplayMode = GroupMateDisplayMode.all,
    this.showGroupOnNavigation = true,
    this.preferExternalNavigation = false,
    this.packAlertsMutedUntil,
  });

  static const defaults = GroupPackAlertPreferences();

  static const double minBehindMeters = 400;
  static const double maxBehindMeters = 4000;
  static const double minFarGapMeters = 300;

  /// Si es false, no hay avisos automáticos de distancia.
  final bool enabled;

  /// Distancia a ti para avisar «se queda atrás».
  final double behindMeters;

  /// Distancia a ti para avisar «muy lejos» (debe ser > [behindMeters]).
  final double farMeters;

  /// Filtro de motos en mapa de navegación (cuando el grupo está visible).
  final GroupMateDisplayMode mateDisplayMode;

  /// Si al abrir la navegación del grupo se muestran las motos por defecto.
  final bool showGroupOnNavigation;

  /// Navegar con Waze/Maps en lugar del HUD de LocMotos.
  final bool preferExternalNavigation;

  /// Hasta cuándo están silenciados los avisos de distancia (no emergencias).
  final DateTime? packAlertsMutedUntil;

  /// Por debajo de esto se considera que ha vuelto al pelotón.
  double get resetMeters {
    final derived = behindMeters * 0.5;
    return derived.clamp(200, behindMeters - 50).toDouble();
  }

  bool isPackAlertsMutedAt(DateTime now) {
    final until = packAlertsMutedUntil;
    return until != null && now.isBefore(until);
  }

  GroupPackAlertPreferences copyWith({
    bool? enabled,
    double? behindMeters,
    double? farMeters,
    GroupMateDisplayMode? mateDisplayMode,
    bool? showGroupOnNavigation,
    bool? preferExternalNavigation,
    DateTime? packAlertsMutedUntil,
    bool clearPackAlertsMute = false,
  }) {
    final nextBehind = (behindMeters ?? this.behindMeters)
        .clamp(minBehindMeters, maxBehindMeters)
        .toDouble();
    var nextFar = (farMeters ?? this.farMeters).toDouble();
    if (nextFar < nextBehind + minFarGapMeters) {
      nextFar = nextBehind + minFarGapMeters;
    }
    nextFar = nextFar.clamp(nextBehind + minFarGapMeters, 6000).toDouble();
    return GroupPackAlertPreferences(
      enabled: enabled ?? this.enabled,
      behindMeters: nextBehind,
      farMeters: nextFar,
      mateDisplayMode: mateDisplayMode ?? this.mateDisplayMode,
      showGroupOnNavigation:
          showGroupOnNavigation ?? this.showGroupOnNavigation,
      preferExternalNavigation:
          preferExternalNavigation ?? this.preferExternalNavigation,
      packAlertsMutedUntil: clearPackAlertsMute
          ? null
          : (packAlertsMutedUntil ?? this.packAlertsMutedUntil),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'behindMeters': behindMeters,
        'farMeters': farMeters,
        'mateDisplayMode': mateDisplayMode.storageValue,
        'showGroupOnNavigation': showGroupOnNavigation,
        'preferExternalNavigation': preferExternalNavigation,
        if (packAlertsMutedUntil != null)
          'packAlertsMutedUntil': packAlertsMutedUntil!.toIso8601String(),
      };

  factory GroupPackAlertPreferences.fromJson(Map<String, dynamic> json) {
    final rawBehind = (json['behindMeters'] as num?)?.toDouble() ??
        AppConstants.groupBehindAlertMeters;
    final rawFar = (json['farMeters'] as num?)?.toDouble() ??
        AppConstants.groupFarAlertMeters;
    final mutedRaw = json['packAlertsMutedUntil']?.toString();
    return GroupPackAlertPreferences.defaults.copyWith(
      enabled: json['enabled'] as bool? ?? true,
      behindMeters: rawBehind,
      farMeters: rawFar,
      mateDisplayMode: GroupMateDisplayModeX.parse(
        json['mateDisplayMode']?.toString(),
      ),
      showGroupOnNavigation: json['showGroupOnNavigation'] as bool? ?? true,
      preferExternalNavigation:
          json['preferExternalNavigation'] as bool? ?? false,
      packAlertsMutedUntil: mutedRaw == null || mutedRaw.isEmpty
          ? null
          : DateTime.tryParse(mutedRaw),
    );
  }

  @override
  List<Object?> get props => [
        enabled,
        behindMeters,
        farMeters,
        mateDisplayMode,
        showGroupOnNavigation,
        preferExternalNavigation,
        packAlertsMutedUntil,
      ];
}

class GroupPackAlertRepository {
  static const _boxName = 'group_pack_alerts';
  static const _key = 'prefs';

  Box<String>? _box;

  Future<Box<String>> _open() async {
    _box ??= await Hive.openBox<String>(_boxName);
    return _box!;
  }

  Future<GroupPackAlertPreferences> load() async {
    final box = await _open();
    final raw = box.get(_key);
    if (raw == null || raw.isEmpty) {
      return GroupPackAlertPreferences.defaults;
    }
    try {
      return GroupPackAlertPreferences.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return GroupPackAlertPreferences.defaults;
    }
  }

  Future<void> save(GroupPackAlertPreferences prefs) async {
    final box = await _open();
    await box.put(_key, jsonEncode(prefs.toJson()));
  }
}
