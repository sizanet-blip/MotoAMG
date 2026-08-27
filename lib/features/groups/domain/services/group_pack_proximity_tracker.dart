import 'package:geolocator/geolocator.dart';
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/core/utils/distance_format.dart';
import 'package:loc_motos/core/utils/gps_status.dart';
import 'package:loc_motos/features/tracking/domain/entities/live_location.dart';

enum GroupPackAlertKind { behind, far }

class GroupPackAlert {
  const GroupPackAlert({
    required this.uid,
    required this.name,
    required this.meters,
    required this.kind,
  });

  final String uid;
  final String name;
  final double meters;
  final GroupPackAlertKind kind;

  String get distanceLabel => formatRideDistance(meters);

  String get key => '${kind.name}:$uid';
}

/// Detecta compañeros que se quedan atrás / muy lejos (sin spam).
class GroupPackProximityTracker {
  final _activeBehind = <String>{};
  final _activeFar = <String>{};
  final _lastFiredAt = <String, DateTime>{};
  var _primed = false;

  /// Primera pasada: registra estado sin avisar (evitar tormenta al abrir).
  void prime() {
    _primed = true;
  }

  bool get isPrimed => _primed;

  List<GroupPackAlert> evaluate({
    required double ownLat,
    required double ownLng,
    required List<LiveLocation> others,
    required Map<String, String> names,
    required DateTime now,
    required String ownUid,
    double behindMeters = AppConstants.groupBehindAlertMeters,
    double farMeters = AppConstants.groupFarAlertMeters,
    double resetMeters = AppConstants.groupPackAlertResetMeters,
    Duration cooldown = AppConstants.groupPackAlertCooldown,
    bool enabled = true,
  }) {
    if (!enabled) {
      return const [];
    }
    if (farMeters <= behindMeters) {
      farMeters = behindMeters + 300;
    }

    if (!_primed) {
      for (final location in others) {
        if (location.uid == ownUid) {
          continue;
        }
        final meters = Geolocator.distanceBetween(
          ownLat,
          ownLng,
          location.lat,
          location.lng,
        );
        if (meters >= farMeters) {
          _activeFar.add(location.uid);
          _activeBehind.add(location.uid);
        } else if (meters >= behindMeters) {
          _activeBehind.add(location.uid);
        }
      }
      _primed = true;
      return const [];
    }

    final out = <GroupPackAlert>[];
    final stillNear = <String>{};

    for (final location in others) {
      if (location.uid == ownUid) {
        continue;
      }
      if (!location.hasSignal || isGpsStale(location.updatedAt, now)) {
        continue;
      }
      final meters = Geolocator.distanceBetween(
        ownLat,
        ownLng,
        location.lat,
        location.lng,
      );
      final name = (names[location.uid] ?? location.displayName).trim();
      final label = name.isEmpty ? 'Motero' : name;

      if (meters < resetMeters) {
        stillNear.add(location.uid);
        _activeBehind.remove(location.uid);
        _activeFar.remove(location.uid);
        continue;
      }

      if (meters >= farMeters) {
        if (_shouldFire(
          uid: location.uid,
          kind: GroupPackAlertKind.far,
          now: now,
          alreadyActive: _activeFar.contains(location.uid),
          cooldown: cooldown,
        )) {
          _activeFar.add(location.uid);
          _activeBehind.add(location.uid);
          _lastFiredAt[location.uid] = now;
          out.add(
            GroupPackAlert(
              uid: location.uid,
              name: label,
              meters: meters,
              kind: GroupPackAlertKind.far,
            ),
          );
        } else {
          _activeFar.add(location.uid);
          _activeBehind.add(location.uid);
        }
        continue;
      }

      if (meters >= behindMeters) {
        if (_shouldFire(
          uid: location.uid,
          kind: GroupPackAlertKind.behind,
          now: now,
          alreadyActive: _activeBehind.contains(location.uid),
          cooldown: cooldown,
        )) {
          _activeBehind.add(location.uid);
          _lastFiredAt[location.uid] = now;
          out.add(
            GroupPackAlert(
              uid: location.uid,
              name: label,
              meters: meters,
              kind: GroupPackAlertKind.behind,
            ),
          );
        } else {
          _activeBehind.add(location.uid);
        }
      }
    }

    for (final uid in stillNear) {
      _lastFiredAt.remove(uid);
    }
    return out;
  }

  bool _shouldFire({
    required String uid,
    required GroupPackAlertKind kind,
    required DateTime now,
    required bool alreadyActive,
    required Duration cooldown,
  }) {
    // Solo al cruzar el umbral (entrar en la zona), no en cada tick.
    if (alreadyActive) {
      return false;
    }
    final last = _lastFiredAt[uid];
    if (last != null && now.difference(last) < cooldown) {
      return false;
    }
    if (kind == GroupPackAlertKind.behind && _activeFar.contains(uid)) {
      return false;
    }
    return true;
  }
}
