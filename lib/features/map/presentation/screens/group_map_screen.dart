import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:loc_motos/core/utils/distance_format.dart';
import 'package:loc_motos/core/utils/gps_status.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/groups/domain/entities/group_member.dart';
import 'package:loc_motos/features/groups/presentation/providers/group_providers.dart';
import 'package:loc_motos/features/map/presentation/widgets/moto_marker.dart';
import 'package:loc_motos/features/tracking/domain/entities/device_position.dart';
import 'package:loc_motos/features/tracking/domain/entities/live_location.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';

class GroupMapView extends ConsumerWidget {
  const GroupMapView({
    super.key,
    required this.user,
    required this.groupId,
  });

  final AppUser user;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFix = ref.watch(
      ownDevicePositionProvider.select((value) => value != null),
    );
    if (!hasFix) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Buscando tu ubicación…\n'
                'Si usas el emulador: tres puntitos → Location → elige tu zona.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return _GroupMapCanvas(user: user, groupId: groupId);
  }
}

class _GroupMapCanvas extends ConsumerStatefulWidget {
  const _GroupMapCanvas({
    required this.user,
    required this.groupId,
  });

  final AppUser user;
  final String groupId;

  @override
  ConsumerState<_GroupMapCanvas> createState() => _GroupMapCanvasState();
}

class _GroupMapCanvasState extends ConsumerState<_GroupMapCanvas> {
  static const _meColor = Color(0xFF1565C0);
  static const _groupColor = Color(0xFFE65100);

  final _mapController = MapController();
  late final LatLng _initialCenter;
  var _followGroup = true;
  DateTime? _lastFollowFit;
  var _fittedUids = <String>{};

  @override
  void initState() {
    super.initState();
    final own = ref.read(ownDevicePositionProvider)!;
    _initialCenter = LatLng(own.lat, own.lng);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final own = ref.watch(ownDevicePositionProvider);
    final gpsLost = ref.watch(ownGpsLostProvider);
    ref.watch(gpsClockProvider);
    final now = DateTime.now();
    final locationsAsync = ref.watch(groupLocationsProvider(widget.groupId));
    final members =
        ref.watch(groupMembersProvider(widget.groupId)).asData?.value;
    final locations = locationsAsync.valueOrNull ?? const <LiveLocation>[];
    final markers = _markers(
      locations,
      own ??
          ownDevicePosition(
            lat: _initialCenter.latitude,
            lng: _initialCenter.longitude,
          ),
      now: now,
      ownGpsLost: gpsLost,
      members: members,
    );
    final memberUids = {
      widget.user.uid,
      if (members != null) ...members.map((member) => member.uid),
    };
    final liveUids = {
      for (final location in locations)
        if (members == null || memberUids.contains(location.uid)) location.uid,
      widget.user.uid,
    };
    final waiting = (members ?? const <GroupMember>[])
        .where((member) => !liveUids.contains(member.uid))
        .map((member) => member.displayName)
        .where((name) => name.trim().isNotEmpty)
        .toList();

    _scheduleFollow(liveUids, markers.map((marker) => marker.point).toList());

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: 15,
            onMapEvent: _onMapEvent,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.locmotos.loc_motos',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          top: 8,
          left: 8,
          right: 56,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MapLegend(meColor: _meColor, groupColor: _groupColor),
              if (waiting.isNotEmpty) ...[
                const SizedBox(height: 8),
                _WaitingBanner(names: waiting),
              ],
              if (locationsAsync.hasError) ...[
                const SizedBox(height: 8),
                Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'No se ven las motos del grupo. ${locationsAsync.error}',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: FloatingActionButton.small(
            tooltip: 'Centrar grupo',
            backgroundColor: _followGroup
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
            foregroundColor: _followGroup
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.primary,
            onPressed: _recenterGroup,
            child: const Icon(Icons.groups),
          ),
        ),
      ],
    );
  }

  void _onMapEvent(MapEvent event) {
    if (!_followGroup) {
      return;
    }
    if (event.source == MapEventSource.mapController ||
        event.source == MapEventSource.fitCamera) {
      return;
    }
    const userSources = {
      MapEventSource.dragStart,
      MapEventSource.onDrag,
      MapEventSource.dragEnd,
      MapEventSource.multiFingerGestureStart,
      MapEventSource.onMultiFinger,
      MapEventSource.multiFingerEnd,
      MapEventSource.doubleTap,
      MapEventSource.scrollWheel,
      MapEventSource.flingAnimationController,
      MapEventSource.doubleTapZoomAnimationController,
      MapEventSource.keyboard,
    };
    if (userSources.contains(event.source)) {
      setState(() => _followGroup = false);
    }
  }

  void _recenterGroup() {
    setState(() {
      _followGroup = true;
      _lastFollowFit = null;
    });
  }

  void _scheduleFollow(Set<String> uids, List<LatLng> points) {
    if (!_followGroup || points.isEmpty) {
      return;
    }
    final membersChanged = !setEquals(uids, _fittedUids);
    final due = _lastFollowFit == null ||
        DateTime.now().difference(_lastFollowFit!) >=
            const Duration(seconds: 2);
    if (!membersChanged && !due) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_followGroup || points.isEmpty) {
        return;
      }
      _fittedUids = uids;
      _lastFollowFit = DateTime.now();
      try {
        if (points.length == 1) {
          _mapController.move(points.first, 15);
          return;
        }
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.fromLTRB(48, 96, 48, 72),
            maxZoom: 16,
          ),
        );
      } catch (_) {}
    });
  }

  List<Marker> _markers(
    List<LiveLocation> locations,
    OwnDevicePosition own, {
    required DateTime now,
    required bool ownGpsLost,
    required List<GroupMember>? members,
  }) {
    final allowedUids = {
      widget.user.uid,
      if (members != null) ...members.map((member) => member.uid),
    };
    final names = <String, String>{
      widget.user.uid: widget.user.displayName,
      if (members != null)
        for (final member in members) member.uid: member.displayName,
    };
    final byUid = <String, LiveLocation>{};
    for (final location in locations) {
      if (!allowedUids.contains(location.uid)) {
        continue;
      }
      byUid[location.uid] = location;
    }
    byUid.putIfAbsent(
      widget.user.uid,
      () => LiveLocation(
        uid: widget.user.uid,
        groupId: widget.groupId,
        lat: own.lat,
        lng: own.lng,
        heading: 0,
        speed: 0,
        updatedAt: now,
        displayName: widget.user.displayName,
        hasSignal: !ownGpsLost,
      ),
    );

    final spreadCount = <String, int>{};
    return byUid.values.map((location) {
      final isMe = location.uid == widget.user.uid;
      final stale = isMe
          ? ownGpsLost
          : !location.hasSignal || isGpsStale(location.updatedAt, now);
      final bucket =
          '${location.lat.toStringAsFixed(5)}_${location.lng.toStringAsFixed(5)}';
      final index = spreadCount[bucket] ?? 0;
      spreadCount[bucket] = index + 1;
      const spread = 0.0002;
      final name = (names[location.uid] ?? location.displayName).trim();
      return Marker(
        point: LatLng(
          location.lat + index * spread,
          location.lng + index * spread,
        ),
        width: 128,
        height: 92,
        alignment: Alignment.bottomCenter,
        child: MotoMarker(
          name: name.isEmpty ? 'Motero' : name,
          color: isMe ? _meColor : _groupColor,
          isMe: isMe,
          heading: location.heading,
          isStale: stale,
          staleLabel: stale
              ? formatGpsStaleLabel(location.updatedAt, now)
              : null,
          distanceLabel: isMe || stale
              ? null
              : formatRideDistance(
                  Geolocator.distanceBetween(
                    own.lat,
                    own.lng,
                    location.lat,
                    location.lng,
                  ),
                ),
        ),
      );
    }).toList();
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({
    required this.meColor,
    required this.groupColor,
  });

  final Color meColor;
  final Color groupColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendDot(color: meColor, label: 'Tú'),
            const SizedBox(width: 12),
            _LegendDot(color: groupColor, label: 'Grupo'),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox(width: 10, height: 10),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _WaitingBanner extends StatelessWidget {
  const _WaitingBanner({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          names.length == 1
              ? '1 motero aún no manda GPS'
              : '${names.length} moteros aún no mandan GPS',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
        ),
      ),
    );
  }
}
