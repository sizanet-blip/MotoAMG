import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:permission_handler/permission_handler.dart';

/// Preferencias de pantalla y controles al navegar.
class HudSafetySettingsScreen extends ConsumerWidget {
  const HudSafetySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(hudSafetyProvider);
    final controller = ref.read(hudSafetyProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(titleText: 'Pantalla (mapa y ruta)'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 8),
          SwitchListTile(
            secondary: const Icon(Icons.smartphone_outlined),
            title: const Text('Mantener pantalla encendida'),
            subtitle: const Text(
              'No se apaga sola en el mapa del grupo ni al navegar',
            ),
            value: prefs.keepScreenOn,
            onChanged: controller.setKeepScreenOn,
            activeThumbColor: HubStyle.accent,
            activeTrackColor: HubStyle.accent.withValues(alpha: 0.45),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Más brillo en la ruta'),
            subtitle: const Text(
              'Sube el brillo al empezar a navegar y lo deja como estaba al salir',
            ),
            value: prefs.highBrightness,
            onChanged: controller.setHighBrightness,
            activeThumbColor: HubStyle.accent,
            activeTrackColor: HubStyle.accent.withValues(alpha: 0.45),
          ),
          const Divider(height: 24),
          SwitchListTile(
            secondary: const Icon(Icons.sports_motorsports_outlined),
            title: const Text('Botones grandes (con guantes)'),
            subtitle: const Text(
              'Silenciar y cancelar más fáciles de pulsar con el casco puesto',
            ),
            value: prefs.helmetMode,
            onChanged: controller.setHelmetMode,
            activeThumbColor: HubStyle.accent,
            activeTrackColor: HubStyle.accent.withValues(alpha: 0.45),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Si lo activas, al navegar verás abajo dos botones grandes: '
              'uno para silenciar la voz y otro para cancelar la ruta.',
              style: HubStyle.caption(),
            ),
          ),
          const Divider(height: 24),
          SwitchListTile(
            secondary: const Icon(Icons.threed_rotation_outlined),
            title: const Text('Mapa en 3D'),
            subtitle: const Text(
              'Inclina el mapa y muestra edificios en volumen. '
              'Desactivado = vista plana (2D)',
            ),
            value: prefs.map3dEnabled,
            onChanged: controller.setMap3dEnabled,
            activeThumbColor: HubStyle.accent,
            activeTrackColor: HubStyle.accent.withValues(alpha: 0.45),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Por defecto está desactivado. Si lo activas, el mapa se inclina '
              'y, al acercarte (zoom alto), verás los edificios en 3D.',
              style: HubStyle.caption(),
            ),
          ),
          const Divider(height: 24),
          SwitchListTile(
            secondary: const Icon(Icons.play_circle_outline_rounded),
            title: const Text('Simular ruta'),
            subtitle: const Text(
              'Al navegar aparecen los botones Volver y Simular para recorrer '
              'la ruta sin moverte. Apágalo cuando vayas a circular de verdad',
            ),
            value: prefs.showRouteSimulator,
            onChanged: controller.setShowRouteSimulator,
            activeThumbColor: HubStyle.accent,
            activeTrackColor: HubStyle.accent.withValues(alpha: 0.45),
          ),
          if (defaultTargetPlatform == TargetPlatform.android) ...[
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'GPS en segundo plano',
                style: HubStyle.sectionTitle(color: HubStyle.accent),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _BatteryOptimizationSection(),
            ),
          ],
        ],
      ),
    );
  }
}

class _BatteryOptimizationSection extends StatefulWidget {
  const _BatteryOptimizationSection();

  @override
  State<_BatteryOptimizationSection> createState() =>
      _BatteryOptimizationSectionState();
}

class _BatteryOptimizationSectionState extends State<_BatteryOptimizationSection>
    with WidgetsBindingObserver {
  PermissionStatus? _status;
  var _checking = true;

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
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (!mounted) {
      return;
    }
    setState(() {
      _status = status;
      _checking = false;
    });
  }

  Future<void> _openBatterySettings() async {
    setState(() => _checking = true);
    final requested = await Permission.ignoreBatteryOptimizations.request();
    if (requested.isGranted) {
      await _refresh();
      return;
    }
    final opened = await openAppSettings();
    if (!mounted) {
      return;
    }
    setState(() => _checking = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudieron abrir los ajustes. Búscalos manualmente en '
            'Ajustes → Aplicaciones → MotoAMG → Batería.',
          ),
        ),
      );
    }
  }

  bool get _isExempt => _status?.isGranted ?? false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : HubStyle.cardShadow,
      ),
      child: Material(
        color: isDark ? colors.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _isExempt
                        ? Icons.check_circle_outline
                        : Icons.battery_alert_outlined,
                    size: 22,
                    color: _isExempt ? HubStyle.accent : colors.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Optimización de batería',
                          style: HubStyle.sectionTitle(),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'En Samsung, Xiaomi y otras marcas el móvil puede parar '
                          'el GPS con la pantalla apagada. Desactiva la optimización '
                          'para MotoAMG y la ruta seguirá mejor.',
                          style: HubStyle.caption(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_checking)
                const LinearProgressIndicator(
                  minHeight: 3,
                  color: HubStyle.accent,
                )
              else
                Text(
                  _isExempt
                      ? 'MotoAMG puede usar GPS en segundo plano.'
                      : 'Aún puede estar restringido — conviene revisarlo.',
                  style: HubStyle.caption(
                    color: _isExempt ? HubStyle.accent : colors.error,
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed:
                    _checking ? null : () => unawaited(_openBatterySettings()),
                style: HubStyle.filledButtonStyle(enabled: !_checking),
                icon: const Icon(Icons.settings_outlined),
                label: Text(
                  _isExempt
                      ? 'Revisar ajustes de batería'
                      : 'Abrir ajustes de batería',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
