import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/groups/domain/entities/group_incident.dart';
import 'package:loc_motos/features/groups/presentation/providers/group_providers.dart';
import 'package:loc_motos/features/groups/presentation/widgets/group_incident_widgets.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';

/// Banner + barra de incidencias (mapa de grupo / HUD).
class GroupIncidentSessionPanel extends ConsumerStatefulWidget {
  const GroupIncidentSessionPanel({
    super.key,
    required this.groupId,
    required this.user,
    this.showBanner = true,
    this.allowAdminClear = true,
  });

  final String groupId;
  final AppUser user;
  final bool showBanner;
  final bool allowAdminClear;

  @override
  ConsumerState<GroupIncidentSessionPanel> createState() =>
      _GroupIncidentSessionPanelState();
}

class _GroupIncidentSessionPanelState
    extends ConsumerState<GroupIncidentSessionPanel> {
  final _dismissedBannerIds = <String>{};
  final _seenIncidentKeys = <String>{};
  var _incidentAlertPrimed = false;
  _PendingIncidentRaise? _pendingIncident;

  @override
  Widget build(BuildContext context) {
    final incidents =
        ref.watch(groupIncidentsProvider(widget.groupId)).asData?.value ??
            const <GroupIncident>[];
    final group =
        ref.watch(rideGroupProvider(widget.groupId)).asData?.value;
    final iAmAdmin = group?.isAdmin(widget.user.uid) ?? false;
    final actionBusy = ref.watch(groupActionControllerProvider).isLoading;
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

    _maybeAlertNewIncidents(incidents);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bannerIncident != null) ...[
          GroupIncidentBanner(
            incident: bannerIncident,
            onDismiss: () {
              setState(() {
                _dismissedBannerIds.add(_bannerId(bannerIncident));
              });
            },
            canClear: bannerIncident.uid == widget.user.uid ||
                (widget.allowAdminClear && iAmAdmin),
            onClear: () => unawaited(
              _clearIncident(bannerIncident.uid),
            ),
          ),
          const SizedBox(height: 8),
        ],
        GroupIncidentActionsBar(
          hasOwnAlert: ownIncident != null || _pendingIncident != null,
          enabled: !actionBusy,
          onEmergency: () =>
              unawaited(_raiseIncident(GroupIncidentType.emergencia)),
          onBreakdown: () =>
              unawaited(_raiseIncident(GroupIncidentType.averia)),
          onSeparated: () =>
              unawaited(_raiseIncident(GroupIncidentType.separado)),
          onClear: () => unawaited(_clearIncident(widget.user.uid)),
        ),
      ],
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
    for (final incident in incidents) {
      if (!incident.active || incident.uid == widget.user.uid) {
        continue;
      }
      final key = _bannerId(incident);
      if (_seenIncidentKeys.add(key)) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      }
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

    final own = ref.read(ownDevicePositionProvider);
    if (own == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin ubicación GPS')),
      );
      return;
    }

    final point = GeoPoint(lat: own.lat, lng: own.lng);
    final hasNetwork =
        ref.read(mapNetworkAvailableProvider).asData?.value ?? true;
    if (!hasNetwork) {
      setState(() {
        _pendingIncident = _PendingIncidentRaise(
          type: type,
          severity: severity,
          point: point,
        );
      });
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se enviará al recuperar cobertura')),
      );
      return;
    }

    await _publishIncident(
      type: type,
      severity: severity,
      point: point,
    );
  }

  Future<void> _publishIncident({
    required GroupIncidentType type,
    required GroupIncidentSeverity? severity,
    required GeoPoint point,
  }) async {
    await ref.read(groupActionControllerProvider.notifier).raiseIncident(
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
    final error = ref.read(groupActionControllerProvider).asError?.error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _flushPendingIncident() async {
    final pending = _pendingIncident;
    if (pending == null) {
      return;
    }
    setState(() => _pendingIncident = null);
    await _publishIncident(
      type: pending.type,
      severity: pending.severity,
      point: pending.point,
    );
  }

  Future<void> _clearIncident(String uid) async {
    if (uid == widget.user.uid) {
      setState(() => _pendingIncident = null);
    }
    await ref.read(groupActionControllerProvider.notifier).clearIncident(
          groupId: widget.groupId,
          uid: uid,
        );
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
