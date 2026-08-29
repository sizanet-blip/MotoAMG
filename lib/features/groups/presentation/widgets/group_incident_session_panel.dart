import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/groups/domain/entities/group_incident.dart';
import 'package:loc_motos/features/groups/domain/entities/group_voice_announcement.dart';
import 'package:loc_motos/features/groups/domain/entities/ride_role.dart';
import 'package:loc_motos/features/groups/domain/services/critical_emergency_actions.dart';
import 'package:loc_motos/features/groups/domain/services/group_incident_service.dart';
import 'package:loc_motos/features/groups/domain/services/group_ride_alert_feedback.dart';
import 'package:loc_motos/features/groups/presentation/providers/group_providers.dart';
import 'package:loc_motos/features/groups/presentation/widgets/group_incident_widgets.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:loc_motos/features/tracking/domain/entities/device_position.dart';
import 'package:loc_motos/features/tracking/presentation/helpers/resolve_own_device_position.dart';

/// Banner + barra de incidencias (mapa de grupo / HUD).
class GroupIncidentSessionPanel extends ConsumerStatefulWidget {
  const GroupIncidentSessionPanel({
    super.key,
    required this.groupId,
    required this.user,
    this.showBanner = true,
    this.compact = false,
    this.drivingMode = false,
    this.embedded = false,
    this.vertical = false,
    this.tight = false,
    this.showActions = true,
  });

  final String groupId;
  final AppUser user;
  final bool showBanner;

  /// Landscape / poco alto: barra de incidencias en una sola fila de iconos.
  final bool compact;

  /// Navegando: sin snackbars ni banners de error (menos distracción).
  final bool drivingMode;

  /// Dentro del panel inferior del mapa (menos márgenes).
  final bool embedded;

  /// Landscape: columna de iconos en el lateral del mapa.
  final bool vertical;

  /// Landscape: iconos pequeños en una fila, sin estirar.
  final bool tight;

  /// Barra de botones de aviso. False = solo el mensaje/confirmación.
  final bool showActions;

  @override
  ConsumerState<GroupIncidentSessionPanel> createState() =>
      _GroupIncidentSessionPanelState();
}

class _GroupIncidentSessionPanelState
    extends ConsumerState<GroupIncidentSessionPanel> {
  final _dismissedBannerIds = <String>{};
  final _seenIncidentKeys = <String>{};
  final _seenVoiceKeys = <String>{};
  var _incidentAlertPrimed = false;
  var _voiceAlertPrimed = false;
  _PendingIncidentRaise? _pendingIncident;
  GroupIncident? _localOwnIncident;
  var _incidentBusy = false;
  String? _lastIncidentError;

  bool get _silent => widget.drivingMode;

  @override
  Widget build(BuildContext context) {
    final incidentsAsync = ref.watch(groupIncidentsProvider(widget.groupId));
    final remoteIncidents =
        incidentsAsync.valueOrNull ?? const <GroupIncident>[];
    final incidents = _effectiveIncidents(remoteIncidents);
    final group =
        ref.watch(rideGroupProvider(widget.groupId)).asData?.value;
    final iAmAdmin = group?.isAdmin(widget.user.uid) ?? false;
    final members =
        ref.watch(groupMembersProvider(widget.groupId)).asData?.value;
    final iAmCabecera = members?.any(
          (member) =>
              member.uid == widget.user.uid &&
              member.rideRole == RideRole.cabecera,
        ) ??
        false;
    final canAskWait = iAmAdmin || iAmCabecera;
    final ownIncident = _ownActiveIncident(incidents);
    final bannerIncident =
        widget.showBanner ? _highestPriorityBanner(incidents) : null;

    ref.listen(mapNetworkAvailableProvider, (prev, next) {
      final wasOffline = prev?.asData?.value == false;
      final nowOnline = next.asData?.value == true;
      if (wasOffline && nowOnline) {
        unawaited(_flushPendingIncident());
      }
    });

    ref.listen(groupIncidentsProvider(widget.groupId), (previous, next) {
      next.when(
        data: (list) {
          if (_localOwnIncident != null &&
              list.any(
                (incident) =>
                    incident.uid == widget.user.uid && incident.active,
              )) {
            setState(() => _localOwnIncident = null);
          }
          _maybeAlertNewIncidents(list);
        },
        error: (error, _) {
          if (_silent || !mounted) {
            return;
          }
          setState(() {
            _lastIncidentError =
                'No se pueden leer los avisos del grupo.';
          });
        },
        loading: () {},
      );
    });

    ref.listen(groupVoiceAnnouncementsProvider(widget.groupId), (_, next) {
      final list = next.asData?.value;
      if (list != null) {
        _maybeAlertVoiceAnnouncements(list);
      }
    });

    _maybeAlertNewIncidents(incidents);
    final voiceList =
        ref.watch(groupVoiceAnnouncementsProvider(widget.groupId)).asData?.value;
    if (voiceList != null) {
      _maybeAlertVoiceAnnouncements(voiceList);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.vertical || widget.tight
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.stretch,
      children: [
        if (bannerIncident != null) ...[
          GroupIncidentBanner(
            incident: bannerIncident,
            compact: widget.compact || widget.vertical,
            onDismiss: () {
              setState(() {
                _dismissedBannerIds.add(_bannerId(bannerIncident));
              });
            },
            isOwnIncident: bannerIncident.uid == widget.user.uid,
            onClear: bannerIncident.uid == widget.user.uid
                ? () => unawaited(_clearOwnIncident())
                : null,
          ),
          SizedBox(height: widget.compact ? 4 : 8),
        ],
        if (!_silent && _lastIncidentError != null) ...[
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _lastIncidentError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          SizedBox(height: widget.compact ? 4 : 8),
        ],
        if (!_silent &&
            incidentsAsync.hasError &&
            _lastIncidentError == null) ...[
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'No se pueden leer los avisos del grupo.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          SizedBox(height: widget.compact ? 4 : 8),
        ],
        if (widget.showActions)
          GroupIncidentActionsBar(
          compact: widget.compact,
          embedded: widget.embedded,
          vertical: widget.vertical,
          tight: widget.tight,
          hasOwnAlert: ownIncident != null || _pendingIncident != null,
          enabled: !_incidentBusy,
          showWait: canAskWait,
          onWait: () => unawaited(_raiseIncident(GroupIncidentType.espera)),
          onEmergency: () =>
              unawaited(_raiseIncident(GroupIncidentType.emergencia)),
          onBreakdown: () =>
              unawaited(_raiseIncident(GroupIncidentType.averia)),
          onSeparated: () =>
              unawaited(_raiseIncident(GroupIncidentType.separado)),
          onClear: () => unawaited(_clearOwnIncident()),
        ),
      ],
    );
  }

  void _notifyUser(String message) {
    if (_silent || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  GroupIncident? _ownActiveIncident(List<GroupIncident> incidents) {
    for (final incident in incidents) {
      if (incident.active && incident.uid == widget.user.uid) {
        return incident;
      }
    }
    return null;
  }

  String _bannerId(GroupIncident incident) =>
      '${incident.uid}|${incident.at.toIso8601String()}|${incident.type.name}';

  GroupIncident? _highestPriorityBanner(List<GroupIncident> incidents) {
    final candidates = incidents
        .where(
          (incident) =>
              incident.active &&
              !_dismissedBannerIds.contains(_bannerId(incident)),
        )
        .toList();
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort((a, b) {
      final critical =
          (b.isCriticalEmergency ? 1 : 0) - (a.isCriticalEmergency ? 1 : 0);
      if (critical != 0) {
        return critical;
      }
      final byType = b.type.priorityRank.compareTo(a.type.priorityRank);
      if (byType != 0) {
        return byType;
      }
      return b.at.compareTo(a.at);
    });
    return candidates.first;
  }

  void _maybeAlertNewIncidents(List<GroupIncident> incidents) {
    final keys = <String>{
      for (final incident in incidents)
        if (incident.active) _bannerId(incident),
    };
    if (!_incidentAlertPrimed) {
      _seenIncidentKeys.addAll(keys);
      _incidentAlertPrimed = true;
      return;
    }
    final voice = ref.read(navigationVoiceServiceProvider);
    for (final incident in incidents) {
      if (!incident.active || incident.uid == widget.user.uid) {
        continue;
      }
      final key = _bannerId(incident);
      if (_seenIncidentKeys.add(key)) {
        final members =
            ref.read(groupMembersProvider(widget.groupId)).asData?.value;
        final fromMember = members
            ?.where((member) => member.uid == incident.uid)
            .map((member) => member.displayName)
            .firstOrNull;
        final name =
            (incident.displayName ?? fromMember ?? '').trim();
        unawaited(
          GroupRideAlertFeedback.playIncident(
            incident: incident,
            name: name,
            voice: voice,
          ),
        );
      }
    }
  }

  void _maybeAlertVoiceAnnouncements(List<GroupVoiceAnnouncement> list) {
    const freshWindow = Duration(seconds: 30);
    final now = DateTime.now();
    if (!_voiceAlertPrimed) {
      for (final announcement in list) {
        _seenVoiceKeys.add(announcement.dedupeKey);
        final age = now.difference(announcement.at).abs();
        // Si acabas de entrar al HUD y el aviso es reciente de otro, aún lo oyes.
        if (announcement.uid != widget.user.uid && age <= freshWindow) {
          unawaited(
            GroupRideAlertFeedback.playVoiceAnnouncement(
              announcement: announcement,
              voice: ref.read(navigationVoiceServiceProvider),
            ),
          );
        }
      }
      _voiceAlertPrimed = true;
      return;
    }
    final voice = ref.read(navigationVoiceServiceProvider);
    for (final announcement in list) {
      if (!_seenVoiceKeys.add(announcement.dedupeKey)) {
        continue;
      }
      if (now.difference(announcement.at).abs() > freshWindow) {
        continue;
      }
      // Quien publica ya oye en local; el resto del grupo por RTDB.
      if (announcement.uid == widget.user.uid) {
        continue;
      }
      unawaited(
        GroupRideAlertFeedback.playVoiceAnnouncement(
          announcement: announcement,
          voice: voice,
        ),
      );
    }
  }

  Future<void> _raiseIncident(GroupIncidentType type) async {
    final confirmed = await confirmGroupIncident(context, type: type);
    if (!confirmed || !mounted) {
      return;
    }

    GroupIncidentSeverity? severity;
    if (type == GroupIncidentType.emergencia) {
      severity = await pickEmergencySeverity(context);
      if (severity == null || !mounted) {
        return;
      }
    }

    OwnDevicePosition own;
    try {
      own = await resolveOwnDevicePosition(ref);
    } catch (_) {
      return;
    }

    final point = GeoPoint(lat: own.lat, lng: own.lng);
    final isCritical112 = severity == GroupIncidentSeverity.critica;
    final hasNetwork =
        ref.read(mapNetworkAvailableProvider).asData?.value ?? true;
    if (!hasNetwork) {
      setState(() {
        _pendingIncident = _PendingIncidentRaise(
          type: type,
          severity: severity,
          point: point,
        );
        _localOwnIncident = GroupIncident(
          uid: widget.user.uid,
          type: type,
          point: point,
          at: DateTime.now(),
          severity: severity,
          displayName: widget.user.displayName,
        );
        _lastIncidentError = null;
      });
      if (isCritical112) {
        await _runCritical112Actions(point: point, groupQueued: true);
      } else if (!_silent) {
        _notifyUser('Se enviará al recuperar cobertura');
      }
      return;
    }

    setState(() {
      _localOwnIncident = GroupIncident(
        uid: widget.user.uid,
        type: type,
        point: point,
        at: DateTime.now(),
        severity: severity,
        displayName: widget.user.displayName,
      );
      _lastIncidentError = null;
      _incidentBusy = true;
    });

    try {
      await _publishIncident(
        type: type,
        severity: severity,
        point: point,
        skipSnackBar: isCritical112,
      );
      if (isCritical112 && mounted) {
        await _runCritical112Actions(point: point, groupQueued: false);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      if (_silent) {
        setState(() {
          _pendingIncident = _PendingIncidentRaise(
            type: type,
            severity: severity,
            point: point,
          );
        });
        unawaited(_flushPendingIncident());
        if (isCritical112) {
          await _runCritical112Actions(point: point, groupQueued: true);
        }
        return;
      }
      setState(() {
        _localOwnIncident = null;
        _lastIncidentError = 'No se pudo enviar el aviso. Inténtalo de nuevo.';
      });
      _notifyUser('No se pudo enviar el aviso. Inténtalo de nuevo.');
      // Aunque falle el aviso al grupo, en Urgente · 112 abrimos el marcador.
      if (isCritical112) {
        await _runCritical112Actions(point: point, groupQueued: true);
      }
    } finally {
      if (mounted) {
        setState(() => _incidentBusy = false);
      }
    }
  }

  Future<void> _runCritical112Actions({
    required GeoPoint point,
    required bool groupQueued,
  }) async {
    final result = await CriticalEmergencyActions.copyAndOpen112(
      displayName: widget.user.displayName,
      point: point,
    );
    if (!mounted || _silent) {
      return;
    }
    _notifyUser(result.snackBarMessage(groupQueued: groupQueued));
  }

  Future<void> _publishIncident({
    required GroupIncidentType type,
    required GroupIncidentSeverity? severity,
    required GeoPoint point,
    bool skipSnackBar = false,
  }) async {
    await ref.read(groupIncidentServiceProvider).publish(
          ref: ref,
          groupId: widget.groupId,
          uid: widget.user.uid,
          displayName: widget.user.displayName,
          type: type,
          point: point,
          severity: severity,
        );
    if (!mounted) {
      return;
    }
    if (!_silent && !skipSnackBar) {
      _notifyUser('Aviso enviado al grupo: ${type.label}');
    }
  }

  Future<void> _flushPendingIncident() async {
    final pending = _pendingIncident;
    if (pending == null) {
      return;
    }
    setState(() {
      _localOwnIncident = GroupIncident(
        uid: widget.user.uid,
        type: pending.type,
        point: pending.point,
        at: DateTime.now(),
        severity: pending.severity,
        displayName: widget.user.displayName,
      );
      _incidentBusy = true;
      _lastIncidentError = null;
    });
    try {
      await _publishIncident(
        type: pending.type,
        severity: pending.severity,
        point: pending.point,
      );
      if (!mounted) {
        return;
      }
      setState(() => _pendingIncident = null);
    } catch (_) {
      if (!mounted) {
        return;
      }
      if (_silent) {
        return;
      }
      setState(() {
        _localOwnIncident = null;
        _lastIncidentError = 'No se pudo enviar el aviso. Inténtalo de nuevo.';
      });
      _notifyUser('No se pudo enviar el aviso. Inténtalo de nuevo.');
    } finally {
      if (mounted) {
        setState(() => _incidentBusy = false);
      }
    }
  }

  Future<void> _clearOwnIncident() async {
    setState(() {
      _lastIncidentError = null;
      _incidentBusy = true;
    });
    try {
      await ref.read(groupIncidentServiceProvider).clear(
            groupId: widget.groupId,
            uid: widget.user.uid,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingIncident = null;
        _localOwnIncident = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      if (_silent) {
        unawaited(_retryClearOwnIncidentLater());
        return;
      }
      setState(
        () => _lastIncidentError =
            'No se pudo quitar el aviso. Inténtalo de nuevo.',
      );
      _notifyUser('No se pudo quitar el aviso. Inténtalo de nuevo.');
    } finally {
      if (mounted) {
        setState(() => _incidentBusy = false);
      }
    }
  }

  Future<void> _retryClearOwnIncidentLater() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted || _incidentBusy) {
      return;
    }
    try {
      await ref.read(groupIncidentServiceProvider).clear(
            groupId: widget.groupId,
            uid: widget.user.uid,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingIncident = null;
        _localOwnIncident = null;
      });
    } catch (_) {
      // Sin mensajes al volante; el motero puede pulsar otra vez si hace falta.
    }
  }

  List<GroupIncident> _effectiveIncidents(List<GroupIncident> remote) {
    final local = _localOwnIncident;
    if (local == null) {
      return remote;
    }
    if (remote.any((incident) => incident.uid == local.uid && incident.active)) {
      return remote;
    }
    return [...remote, local];
  }
}

class _PendingIncidentRaise {
  const _PendingIncidentRaise({
    required this.type,
    required this.severity,
    required this.point,
  });

  final GroupIncidentType type;
  final GroupIncidentSeverity? severity;
  final GeoPoint point;
}
