import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/tracking/domain/entities/device_position.dart';
import 'package:loc_motos/features/tracking/domain/entities/live_location.dart';
import 'package:loc_motos/features/tracking/domain/exceptions/location_exceptions.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';

/// Pide GPS y lo envía a Firebase mientras el usuario está en el grupo.
class LocationBinder extends ConsumerStatefulWidget {
  const LocationBinder({
    super.key,
    required this.user,
    required this.groupId,
    required this.child,
  });

  final AppUser user;
  final String groupId;
  final Widget child;

  @override
  ConsumerState<LocationBinder> createState() => _LocationBinderState();
}

class _LocationBinderState extends ConsumerState<LocationBinder>
    with WidgetsBindingObserver {
  StreamSubscription<Position>? _subscription;
  StreamSubscription<ServiceStatus>? _serviceSubscription;
  Timer? _heartbeat;
  Timer? _gpsCheck;
  Position? _lastPosition;
  DateTime? _lastPublishedAt;
  bool? _lastPublishedHasSignal;
  var _started = false;
  var _checkingGps = false;
  var _notifiedPublishError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didUpdateWidget(covariant LocationBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId ||
        oldWidget.user.uid != widget.user.uid) {
      unawaited(_restart(clearRemote: true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_started) {
      return;
    }
    unawaited(_checkGpsSignal());
    if (_subscription == null) {
      unawaited(_restart(clearRemote: false));
    }
  }

  Future<void> _restart({required bool clearRemote}) async {
    await _stop(clearRemote: clearRemote);
    await _start();
  }

  Future<void> _start() async {
    if (_started || !mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final gps = ref.read(deviceLocationServiceProvider);
      await gps.ensurePermission();
      _started = true;
      ref.read(ownPositionWatchSourceProvider.notifier).state =
          OwnPositionWatchSource.group;
      final first = await gps.readPosition();
      if (!mounted) {
        return;
      }
      if (first != null) {
        _rememberPosition(first);
      }
      _subscription = gps.watchPosition().listen(
        _rememberPosition,
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
          return;
        }
        unawaited(_checkGpsSignal());
      });
      _heartbeat = Timer.periodic(AppConstants.locationUpdateInterval, (_) {
        unawaited(_publishLatest());
      });
      _gpsCheck = Timer.periodic(AppConstants.gpsCheckInterval, (_) {
        unawaited(_checkGpsSignal());
      });
      unawaited(_checkGpsSignal());
    } on LocationException catch (error) {
      messenger?.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _rememberPosition(Position position) {
    _lastPosition = position;
    if (mounted) {
      if (ref.read(routeSimulationActiveProvider)) {
        return;
      }
      ref.read(ownDevicePositionProvider.notifier).state = ownDevicePosition(
        lat: position.latitude,
        lng: position.longitude,
        heading: position.heading >= 0 ? position.heading : null,
        speedMps: position.speed >= 0 ? position.speed : 0,
        accuracyMeters: position.accuracy > 0 ? position.accuracy : null,
      );
    }
    if (ref.read(routeSimulationActiveProvider)) {
      return;
    }
    unawaited(_publish(position));
  }

  Future<void> _checkGpsSignal() async {
    if (_checkingGps) {
      return;
    }
    // En simulación no tocamos GPS real ni marcamos "sin señal".
    if (ref.read(routeSimulationActiveProvider)) {
      return;
    }
    _checkingGps = true;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _setGpsLost(true);
        return;
      }
      final gpsFix =
          await ref.read(deviceLocationServiceProvider).readGpsProviderPosition();
      if (gpsFix != null) {
        _setGpsLost(false);
        _rememberPosition(gpsFix);
        return;
      }
      _setGpsLost(true);
    } finally {
      _checkingGps = false;
    }
  }

  Future<void> _publishLatest() async {
    if (ref.read(routeSimulationActiveProvider)) {
      final own = ref.read(ownDevicePositionProvider);
      if (own != null) {
        await _publishDevicePosition(own);
      }
      return;
    }
    if (_lastPosition != null) {
      await _publish(_lastPosition!);
    }
  }

  void _setGpsLost(bool lost) {
    if (!mounted) {
      return;
    }
    final wasLost = ref.read(ownGpsLostProvider);
    if (wasLost == lost) {
      return;
    }
    ref.read(ownGpsLostProvider.notifier).state = lost;
    if (ref.read(routeSimulationActiveProvider)) {
      final own = ref.read(ownDevicePositionProvider);
      if (own != null) {
        unawaited(_publishDevicePosition(own));
      }
      return;
    }
    if (_lastPosition != null) {
      unawaited(_publish(_lastPosition!));
    }
  }

  Future<void> _publish(Position position) async {
    final hasSignal = !ref.read(ownGpsLostProvider);
    if (!_shouldPublishToGroup(
      speedMps: position.speed.isFinite && position.speed >= 0
          ? position.speed
          : 0.0,
      hasSignal: hasSignal,
    )) {
      return;
    }
    try {
      await ref.read(locationRepositoryProvider).publishLocation(
        LiveLocation(
          uid: widget.user.uid,
          groupId: widget.groupId,
          lat: position.latitude,
          lng: position.longitude,
          heading: position.heading.isFinite ? position.heading : 0,
          speed: position.speed.isFinite ? position.speed : 0,
          updatedAt: DateTime.now(),
          displayName: widget.user.displayName,
          hasSignal: hasSignal,
        ),
      );
      _lastPublishedAt = DateTime.now();
      _lastPublishedHasSignal = hasSignal;
    } catch (error) {
      if (!mounted || _notifiedPublishError) {
        return;
      }
      _notifiedPublishError = true;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  /// Publica la posición del HUD (p. ej. simulación de ruta) al grupo.
  Future<void> _publishDevicePosition(OwnDevicePosition own) async {
    final simulating = ref.read(routeSimulationActiveProvider);
    final hasSignal = true;
    // En simulación no apliques el throttle de «parado»: hay que verse mover.
    if (!simulating &&
        !_shouldPublishToGroup(speedMps: own.speedMps, hasSignal: hasSignal)) {
      return;
    }
    try {
      await ref.read(locationRepositoryProvider).publishLocation(
        LiveLocation(
          uid: widget.user.uid,
          groupId: widget.groupId,
          lat: own.lat,
          lng: own.lng,
          heading: own.heading ?? 0,
          speed: own.speedMps,
          updatedAt: DateTime.now(),
          displayName: widget.user.displayName,
          hasSignal: hasSignal,
        ),
      );
      _lastPublishedAt = DateTime.now();
      _lastPublishedHasSignal = hasSignal;
    } catch (error) {
      if (!mounted || _notifiedPublishError) {
        return;
      }
      _notifiedPublishError = true;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  bool _shouldPublishToGroup({
    required double speedMps,
    required bool hasSignal,
  }) {
    if (_lastPublishedHasSignal != null &&
        _lastPublishedHasSignal != hasSignal) {
      return true;
    }
    final stopped = speedMps < AppConstants.locationStoppedSpeedMps;
    if (!stopped) {
      return true;
    }
    final lastAt = _lastPublishedAt;
    if (lastAt == null) {
      return true;
    }
    return DateTime.now().difference(lastAt) >=
        AppConstants.locationStoppedPublishInterval;
  }

  Future<void> _stop({required bool clearRemote}) async {
    _heartbeat?.cancel();
    _heartbeat = null;
    _gpsCheck?.cancel();
    _gpsCheck = null;
    await _serviceSubscription?.cancel();
    _serviceSubscription = null;
    await _subscription?.cancel();
    _subscription = null;
    _lastPosition = null;
    _lastPublishedAt = null;
    _lastPublishedHasSignal = null;
    _started = false;
    if (mounted) {
      if (ref.read(ownPositionWatchSourceProvider) ==
          OwnPositionWatchSource.group) {
        ref.read(ownPositionWatchSourceProvider.notifier).state = null;
      }
      ref.read(ownDevicePositionProvider.notifier).state = null;
      ref.read(ownGpsLostProvider.notifier).state = false;
    }
    if (clearRemote) {
      await ref.read(locationRepositoryProvider).clearLocation(
        groupId: widget.groupId,
        uid: widget.user.uid,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    _gpsCheck?.cancel();
    unawaited(_serviceSubscription?.cancel());
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Durante simulación del HUD, reenviar la posición ficticia al grupo.
    ref.listen(ownDevicePositionProvider, (previous, next) {
      if (!ref.read(routeSimulationActiveProvider) || next == null) {
        return;
      }
      unawaited(_publishDevicePosition(next));
    });
    return widget.child;
  }
}
