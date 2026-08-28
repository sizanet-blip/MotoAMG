import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/core/onboarding/app_onboarding_provider.dart';
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
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                'Prepara LocMotos',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Para ver tu moto en el mapa y seguir la ruta con el grupo '
                'necesitamos un par de permisos. Solo te lo pedimos una vez.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              _PermissionStepCard(
                icon: Icons.location_on_outlined,
                title: 'Ubicación',
                description:
                    'Muestra dónde estás en el mapa y comparte tu posición '
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
                  icon: Icons.notifications_outlined,
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
                  icon: Icons.battery_alert_outlined,
                  title: 'Batería (recomendado)',
                  description:
                      'En Samsung, Xiaomi y otras marcas conviene excluir '
                      'LocMotos de la optimización de batería para que el GPS '
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
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _canContinue && !_completing ? _finish : null,
                child: _completing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continuar'),
              ),
              if (!_canContinue && !_checking) ...[
                const SizedBox(height: 12),
                Text(
                  'Concede los permisos obligatorios para seguir.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.error,
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
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final statusColor = granted ? colors.primary : colors.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: granted
              ? colors.primary.withValues(alpha: 0.45)
              : colors.outlineVariant.withValues(alpha: 0.5),
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
                Icon(icon, color: statusColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (optional)
                            Text(
                              'Opcional',
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  granted ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: statusColor,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (checking)
              const LinearProgressIndicator(minHeight: 3)
            else
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: Icon(granted ? Icons.check : Icons.arrow_forward),
                label: Text(actionLabel),
              ),
          ],
        ),
      ),
    );
  }
}
