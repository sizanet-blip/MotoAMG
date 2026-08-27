import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/auth/presentation/providers/auth_providers.dart';
import 'package:loc_motos/features/tracking/domain/entities/device_position.dart';
import 'package:loc_motos/features/tracking/domain/entities/live_location.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';

/// Publica [ownDevicePositionProvider] al grupo mientras navegas (HUD).
///
/// Complementa [LocationBinder]: al abrir el HUD con rutas encima, el binder
/// del mapa puede quedar bajo una ruta no actual; desde aquí el envío es directo.
class GroupLiveLocationPublisher extends ConsumerStatefulWidget {
  const GroupLiveLocationPublisher({
    super.key,
    required this.user,
    required this.child,
    this.forceInterval = const Duration(milliseconds: 700),
  });

  final AppUser user;
  final Widget child;

  /// En simulación / movimiento: tope de frecuencia de escritura a RTDB.
  final Duration forceInterval;

  @override
  ConsumerState<GroupLiveLocationPublisher> createState() =>
      _GroupLiveLocationPublisherState();
}

class _GroupLiveLocationPublisherState
    extends ConsumerState<GroupLiveLocationPublisher> {
  DateTime? _lastPublishedAt;
  Timer? _heartbeat;

  @override
  void initState() {
    super.initState();
    _heartbeat = Timer.periodic(widget.forceInterval, (_) {
      final own = ref.read(ownDevicePositionProvider);
      if (own != null) {
        unawaited(_publish(own));
      }
    });
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _heartbeat = null;
    super.dispose();
  }

  String? _resolveGroupId() {
    final live = ref.read(signedInUserProvider);
    final fromLive = live?.currentGroupId;
    if (fromLive != null && fromLive.isNotEmpty) {
      return fromLive;
    }
    final fromWidget = widget.user.currentGroupId;
    if (fromWidget != null && fromWidget.isNotEmpty) {
      return fromWidget;
    }
    return null;
  }

  Future<void> _publish(OwnDevicePosition own) async {
    final groupId = _resolveGroupId();
    if (groupId == null) {
      return;
    }
    final now = DateTime.now();
    final last = _lastPublishedAt;
    if (last != null && now.difference(last) < widget.forceInterval) {
      return;
    }
    _lastPublishedAt = now;
    try {
      await ref.read(locationRepositoryProvider).publishLocation(
            LiveLocation(
              uid: widget.user.uid,
              groupId: groupId,
              lat: own.lat,
              lng: own.lng,
              heading: own.heading ?? 0,
              speed: own.speedMps,
              updatedAt: now,
              displayName: widget.user.displayName,
              hasSignal: true,
            ),
          );
    } catch (error, stack) {
      debugPrint(
        'GroupLiveLocationPublisher: fallo al publicar '
        '(group=$groupId): $error\n$stack',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ownDevicePositionProvider, (previous, next) {
      if (next == null) {
        return;
      }
      unawaited(_publish(next));
    });
    return widget.child;
  }
}
