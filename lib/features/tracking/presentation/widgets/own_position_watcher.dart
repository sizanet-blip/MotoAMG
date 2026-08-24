import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:loc_motos/features/tracking/domain/entities/device_position.dart';
import 'package:loc_motos/features/tracking/domain/exceptions/location_exceptions.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';

/// Escucha GPS para navegación cuando no hay un [LocationBinder] activo en grupo.
class OwnPositionWatcher extends ConsumerStatefulWidget {
  const OwnPositionWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OwnPositionWatcher> createState() => _OwnPositionWatcherState();
}

class _OwnPositionWatcherState extends ConsumerState<OwnPositionWatcher> {
  StreamSubscription<Position>? _subscription;
  var _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  @override
  void dispose() {
    unawaited(_stop());
    super.dispose();
  }

  Future<void> _start() async {
    if (_started || !mounted) {
      return;
    }
    if (ref.read(ownPositionWatchSourceProvider) ==
        OwnPositionWatchSource.group) {
      return;
    }

    _started = true;
    ref.read(ownPositionWatchSourceProvider.notifier).state =
        OwnPositionWatchSource.navigation;

    try {
      final gps = ref.read(deviceLocationServiceProvider);
      await gps.ensurePermission();
      final first = await gps.readPosition();
      if (first != null) {
        _apply(first);
      }
      if (!mounted) {
        return;
      }
      _subscription = gps.watchNavigationPosition().listen(
        _apply,
        onError: (_) {},
      );
    } on LocationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

  Future<void> _stop() async {
    await _subscription?.cancel();
    _subscription = null;
    if (ref.read(ownPositionWatchSourceProvider) ==
        OwnPositionWatchSource.navigation) {
      ref.read(ownPositionWatchSourceProvider.notifier).state = null;
    }
    _started = false;
  }

  void _apply(Position position) {
    if (!mounted) {
      return;
    }
    ref.read(ownDevicePositionProvider.notifier).state = ownDevicePosition(
      lat: position.latitude,
      lng: position.longitude,
      heading: position.heading >= 0 ? position.heading : null,
      speedMps: position.speed >= 0 ? position.speed : 0,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
