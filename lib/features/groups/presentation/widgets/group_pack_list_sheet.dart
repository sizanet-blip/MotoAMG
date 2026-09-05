import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/core/utils/distance_format.dart';
import 'package:moto_amg/core/utils/gps_status.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/groups/domain/entities/group_incident.dart';
import 'package:moto_amg/features/groups/domain/entities/group_member.dart';
import 'package:moto_amg/features/groups/domain/entities/ride_role.dart';
import 'package:moto_amg/features/groups/presentation/providers/group_providers.dart';
import 'package:moto_amg/features/tracking/domain/entities/live_location.dart';
import 'package:moto_amg/features/tracking/presentation/providers/tracking_providers.dart';

/// Abre la lista rápida del pelotón (distancia + estado).
Future<void> showGroupPackListSheet({
  required BuildContext context,
  required String groupId,
  required AppUser user,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return GroupPackListSheet(
          groupId: groupId,
          user: user,
          scrollController: scrollController,
        );
      },
    ),
  );
}

class GroupPackListSheet extends ConsumerWidget {
  const GroupPackListSheet({
    super.key,
    required this.groupId,
    required this.user,
    this.scrollController,
  });

  final String groupId;
  final AppUser user;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(groupPackAlertProvider);
    final members =
        ref.watch(groupMembersProvider(groupId)).asData?.value ??
            const <GroupMember>[];
    final locations =
        ref.watch(groupLocationsProvider(groupId)).valueOrNull ??
            const <LiveLocation>[];
    final incidents =
        ref.watch(groupIncidentsProvider(groupId)).asData?.value ??
            const <GroupIncident>[];
    final own = ref.watch(ownDevicePositionProvider);
    ref.watch(gpsClockProvider);
    final now = DateTime.now();
    final muted = prefs.isPackAlertsMutedAt(now);

    final byUid = <String, LiveLocation>{
      for (final location in locations) location.uid: location,
    };
    final incidentByUid = <String, GroupIncident>{
      for (final incident in incidents)
        if (incident.active) incident.uid: incident,
    };

    final rows = <_PackRow>[];
    for (final member in members) {
      final location = byUid[member.uid];
      final incident = incidentByUid[member.uid];
      final isMe = member.uid == user.uid;
      double? meters;
      var stale = false;
      if (location != null) {
        stale = !location.hasSignal || isGpsStale(location.updatedAt, now);
        if (own != null && !isMe) {
          meters = Geolocator.distanceBetween(
            own.lat,
            own.lng,
            location.lat,
            location.lng,
          );
        }
      } else if (!isMe) {
        stale = true;
      }

      final status = _statusLabel(
        isMe: isMe,
        stale: stale,
        meters: meters,
        behindMeters: prefs.behindMeters,
        farMeters: prefs.farMeters,
        incident: incident,
        role: member.rideRole,
      );

      rows.add(
        _PackRow(
          uid: member.uid,
          name: member.displayName.trim().isEmpty
              ? 'Motero'
              : member.displayName.trim(),
          isMe: isMe,
          meters: meters,
          status: status,
          sortMeters: meters ?? (stale ? 1e12 : 0),
        ),
      );
    }
    rows.sort((a, b) {
      if (a.isMe != b.isMe) {
        return a.isMe ? -1 : 1;
      }
      return a.sortMeters.compareTo(b.sortMeters);
    });

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Pelotón', style: HubStyle.sectionTitle()),
                ),
                Text('${rows.length}', style: HubStyle.sectionTitle()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: muted
                ? ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_off_outlined),
                    title: const Text('Avisos de distancia silenciados'),
                    subtitle: Text(
                      'Hasta ${_formatClock(prefs.packAlertsMutedUntil!)} · '
                      'Las emergencias siguen activas',
                    ),
                    trailing: TextButton(
                      onPressed: () => unawaited(
                        ref
                            .read(groupPackAlertProvider.notifier)
                            .clearPackAlertsMute(),
                      ),
                      child: const Text('Reactivar'),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final minutes in [5, 10, 15])
                        ActionChip(
                          avatar: const Icon(Icons.notifications_paused, size: 18),
                          label: Text('Silenciar $minutes min'),
                          onPressed: () => unawaited(
                            ref
                                .read(groupPackAlertProvider.notifier)
                                .mutePackAlertsFor(Duration(minutes: minutes)),
                          ),
                        ),
                    ],
                  ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('No hay moteros en el grupo.'))
                : ListView.separated(
                    controller: scrollController,
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                                row.name.isEmpty
                                    ? '?'
                                    : row.name[0].toUpperCase(),
                          ),
                        ),
                        title: Text(
                          row.isMe ? '${row.name} (tú)' : row.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(row.status),
                        trailing: row.isMe || row.meters == null
                            ? null
                            : Text(
                                formatRideDistance(row.meters!),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel({
    required bool isMe,
    required bool stale,
    required double? meters,
    required double behindMeters,
    required double farMeters,
    required GroupIncident? incident,
    required RideRole? role,
  }) {
    final parts = <String>[];
    if (role == RideRole.cabecera) {
      parts.add('cabecera');
    } else if (role == RideRole.cola) {
      parts.add('cola');
    }
    if (incident != null) {
      parts.add(incident.type.label);
    }
    if (isMe) {
      parts.add(stale ? 'Sin señal' : 'OK');
    } else if (stale) {
      parts.add('Sin señal');
    } else if (meters != null && meters >= farMeters) {
      parts.add('Muy lejos');
    } else if (meters != null && meters >= behindMeters) {
      parts.add('Se queda atrás');
    } else {
      parts.add('OK');
    }
    return parts.join(' · ');
  }

  static String _formatClock(DateTime at) {
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _PackRow {
  const _PackRow({
    required this.uid,
    required this.name,
    required this.isMe,
    required this.meters,
    required this.status,
    required this.sortMeters,
  });

  final String uid;
  final String name;
  final bool isMe;
  final double? meters;
  final String status;
  final double sortMeters;
}
