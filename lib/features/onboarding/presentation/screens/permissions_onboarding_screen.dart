import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/core/onboarding/app_onboarding_provider.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:permission_handler/permission_handler.dart';

/// Primera vez: explica y solicita permisos esenciales antes del login.
class PermissionsOnboardingScreen extends ConsumerStatefulWidget {
  const PermissionsOnboardingScreen({super.key});

  @override
  ConsumerState<PermissionsOnboardingScreen> createState() =>
      _PermissionsOnboardingScreenState();
}

class _PermissionsOnboardingScreenState
    extends ConsumerState<PermissionsOnboardingScreen>
    with WidgetsBindingObserver {
  var _checking = true;
  var _locationGranted = false;
  var _notificationGranted = true;
  var _batteryExempt = false;
  var _completing = false;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  bool get _needsNotificationStep => _isAndroid;

  bool get _canContinue {
    if (!_locationGranted) {
      return false;
    }
    if (_needsNotificationStep && !_notificationGranted) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final location = await Permission.locationWhenInUse.status;
    PermissionStatus notification = PermissionStatus.granted;
    if (_needsNotificationStep) {
      notification = await Permission.notification.status;
    }
    PermissionStatus battery = PermissionStatus.granted;
    if (_isAndroid) {
      battery = await Permission.ignoreBatteryOptimizations.status;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _locationGranted = location.isGranted;
      _notificationGranted = notification.isGranted;
      _batteryExempt = battery.isGranted;
      _checking = false;
    });
  }

  Future<void> _requestLocation() async {
    setState(() => _checking = true);
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activa la ubicación del móvil en Ajustes.'),
        ),
      );
    }
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
    }
    if (status.isGranted && defaultTargetPlatform == TargetPlatform.iOS) {
      var always = await Permission.locationAlways.status;
      if (always.isDenied) {
        always = await Permission.locationAlways.request();
      }
      if (always.isPermanentlyDenied && mounted) {
        await openAppSettings();
      }
    }
    if (status.isPermanentlyDenied && mounted) {
      await openAppSettings();
    }
    await _refresh();
  }

  Future<void> _requestNotification() async {
    setState(() => _checking = true);
    var status = await Permission.notification.status;
    if (status.isDenied) {
      status = await Permission.notification.request();
    }
    if (status.isPermanentlyDenied && mounted) {
      await openAppSettings();
    }
    await _refresh();
  }

  Future<void> _openBatterySettings() async {
    setState(() => _checking = true);
    final requested = await Permission.ignoreBatteryOptimizations.request();
    if (!requested.isGranted) {
      await openAppSettings();
    }
    await _refresh();
  }

  Future<void> _finish() async {
    if (!_canContinue || _completing) {
      return;
    }
    setState(() => _completing = true);
    await ref.read(appOnboardingControllerProvider).complete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubStyle.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    AppConstants.appIconAsset,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Prepara MotoAMG',
                textAlign: TextAlign.center,
                style: HubStyle.headline(),
              ),
              const SizedBox(height: 8),
              Text(
                'Para ver tu moto en el mapa y seguir la ruta con el grupo '
                'necesitamos un par de permisos. Solo te lo pedimos una vez.',
                textAlign: TextAlign.center,
                style: HubStyle.body(),
              ),
              const SizedBox(height: 28),
              _PermissionStepCard(
                icon: Icons.location_on_rounded,
                title: 'Ubicación',
                description: defaultTargetPlatform == TargetPlatform.iOS
                    ? 'Muestra dónde estás en el mapa y comparte tu '
                        'posición con el pelotón, también con la pantalla '
                        'bloqueada (elige «Siempre» cuando iOS lo pida).'
                    : 'Muestra dónde estás en el mapa y comparte tu posición '
                        'con el pelotón mientras circulas.',
                granted: _locationGranted,
                checking: _checking,
                actionLabel: _locationGranted
                    ? 'Permiso concedido'
                    : 'Permitir ubicación',
                onAction: _locationGranted ? null : _requestLocation,
              ),
              if (_needsNotificationStep) ...[
                const SizedBox(height: 12),
                _PermissionStepCard(
                  icon: Icons.notifications_rounded,
                  title: 'Notificaciones',
                  description:
                      'Mientras navegas, Android muestra un aviso fijo para '
                      'que el GPS no se corte con la pantalla apagada.',
                  granted: _notificationGranted,
                  checking: _checking,
                  actionLabel: _notificationGranted
                      ? 'Permiso concedido'
                      : 'Permitir notificaciones',
                  onAction:
                      _notificationGranted ? null : _requestNotification,
                ),
              ],
              if (_isAndroid) ...[
                const SizedBox(height: 12),
                _PermissionStepCard(
                  icon: Icons.battery_charging_full_rounded,
                  title: 'Batería (recomendado)',
                  description:
                      'En Samsung, Xiaomi y otras marcas conviene excluir '
                      'MotoAMG de la optimización de batería para que el GPS '
                      'siga activo en ruta.',
                  granted: _batteryExempt,
                  checking: _checking,
                  optional: true,
                  actionLabel: _batteryExempt
                      ? 'Sin restricción de batería'
                      : 'Abrir ajustes de batería',
                  onAction: _openBatterySettings,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: HubStyle.accent.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Tu privacidad es importante. No compartimos tu información.',
                      textAlign: TextAlign.center,
                      style: HubStyle.caption(color: HubStyle.accent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _canContinue && !_completing ? _finish : null,
                style: HubStyle.filledButtonStyle(
                  enabled: _canContinue && !_completing,
                ),
                child: _completing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continuar'),
              ),
              if (!_canContinue && !_checking) ...[
                const SizedBox(height: 12),
                Text(
                  'Concede los permisos obligatorios para seguir.',
                  textAlign: TextAlign.center,
                  style: HubStyle.caption(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionStepCard extends StatelessWidget {
  const _PermissionStepCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.checking,
    required this.actionLabel,
    this.optional = false,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final bool checking;
  final bool optional;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: HubStyle.cardShadow,
        border: Border.all(
          color: granted
              ? HubStyle.accent.withValues(alpha: 0.45)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: HubStyle.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: HubStyle.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(title, style: HubStyle.sectionTitle()),
                          ),
                          if (optional && !granted)
                            Text('Opcional', style: HubStyle.caption())
                          else if (granted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: HubStyle.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Concedido',
                                style: HubStyle.caption(color: HubStyle.accent),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(description, style: HubStyle.caption()),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  granted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: granted ? HubStyle.accent : HubStyle.subtitle,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (checking)
              const LinearProgressIndicator(
                minHeight: 3,
                color: HubStyle.accent,
              )
            else if (onAction != null)
              OutlinedButton.icon(
                onPressed: onAction,
                style: HubStyle.outlinedButtonStyle(),
                icon: Icon(granted ? Icons.check_rounded : Icons.arrow_forward_rounded),
                label: Text(actionLabel),
              )
            else
              FilledButton.tonalIcon(
                onPressed: null,
                icon: const Icon(Icons.check_rounded),
                label: Text(actionLabel),
              ),
          ],
        ),
      ),
    );
  }
}
