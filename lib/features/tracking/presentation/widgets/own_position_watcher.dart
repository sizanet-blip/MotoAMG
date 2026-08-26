import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:loc_motos/features/tracking/domain/entities/device_position.dart';
import 'package:loc_motos/features/tracking/domain/exceptions/location_exceptions.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';

/// Escucha GPS para navegación cuando no hay un [LocationBinder] activo en grupo.
class OwnPositionWatcher extends ConsumerStatefulWidget {
  const OwnPositionWatcher({
    super.key,
    required this.child,
    this.useForegroundService = false,
  });

  final Widget child;

  /// En ruta activa (HUD): notificación persistente para que Android no pare el GPS.
  final bool useForegroundService;

  @override
  ConsumerState<OwnPositionWatcher> createState() => _OwnPositionWatcherState();
}

class _OwnPositionWatcherState extends ConsumerState<OwnPositionWatcher>
    with WidgetsBindingObserver {
  StreamSubscription<Position>? _subscription;
  StreamSubscription<ServiceStatus>? _serviceSubscription;
  var _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  @override
  void didUpdateWidget(covariant OwnPositionWatcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.useForegroundService != widget.useForegroundService) {
      unawaited(_restart());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_started) {
      return;
    }
    if (_subscription == null) {
      unawaited(_restart());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stop());
    super.dispose();
  }

  Future<void> _restart() async {
    await _stop();
    await _start();
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
      final stream = widget.useForegroundService
          ? gps.watchActiveNavigationPosition()
          : gps.watchNavigationPosition();
      _subscription = stream.listen(
        _apply,
        onError: (Object error) {
          if (error is LocationServiceDisabledException) {
            _setGpsLost(true);
          }
        },
        onDone: () => _subscription = null,
      );
      _serviceSubscription = Geolocator.getServiceStatusStream().listen((
        status,
      ) {
        if (status == ServiceStatus.disabled) {
          _setGpsLost(true);
        } else {
          _setGpsLost(false);
        }
      });
    } on LocationException catch (error) {
      _started = false;
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

  Future<void> _stop() async {
    await _serviceSubscription?.cancel();
    _serviceSubscription = null;
    await _subscription?.cancel();
    _subscription = null;
    if (ref.read(ownPositionWatchSourceProvider) ==
        OwnPositionWatchSource.navigation) {
      ref.read(ownPositionWatchSourceProvider.notifier).state = null;
    }
    if (mounted) {
      ref.read(ownGpsLostProvider.notifier).state = false;
    }
    _started = false;
  }

  void _setGpsLost(bool lost) {
    if (!mounted) {
      return;
    }
    ref.read(ownGpsLostProvider.notifier).state = lost;
  }

  void _apply(Position position) {
    if (!mounted) {
      return;
    }
    if (ref.read(routeSimulationActiveProvider)) {
      return;
    }
    _setGpsLost(false);
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
