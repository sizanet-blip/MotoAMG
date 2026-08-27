import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:permission_handler/permission_handler.dart';

/// Preferencias de pantalla y controles al navegar.
class HudSafetySettingsScreen extends ConsumerWidget {
  const HudSafetySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(hudSafetyProvider);
    final controller = ref.read(hudSafetyProvider.notifier);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pantalla al navegar')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 8),
          SwitchListTile(
            secondary: const Icon(Icons.smartphone_outlined),
            title: const Text('Mantener pantalla encendida'),
            subtitle: const Text(
              'Así no se apaga sola mientras estás en ruta',
            ),
            value: prefs.keepScreenOn,
            onChanged: controller.setKeepScreenOn,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Más brillo en la ruta'),
            subtitle: const Text(
              'Sube el brillo al empezar a navegar y lo deja como estaba al salir',
            ),
            value: prefs.highBrightness,
            onChanged: controller.setHighBrightness,
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
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Si lo activas, al navegar verás abajo dos botones grandes: '
              'uno para silenciar la voz y otro para cancelar la ruta.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
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
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Por defecto está desactivado. Si lo activas, el mapa se inclina '
              'y, al acercarte (zoom alto), verás los edificios en 3D.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ),
          if (defaultTargetPlatform == TargetPlatform.android) ...[
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'GPS EN SEGUNDO PLANO',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
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
            'Ajustes → Aplicaciones → LocMotos → Batería.',
          ),
        ),
      );
    }
  }

  bool get _isExempt => _status?.isGranted ?? false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _isExempt ? Icons.check_circle_outline : Icons.battery_alert_outlined,
                  size: 22,
                  color: _isExempt ? colors.primary : colors.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Optimización de batería',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'En Samsung, Xiaomi y otras marcas el móvil puede parar '
                        'el GPS con la pantalla apagada. Desactiva la optimización '
                        'para LocMotos y la ruta seguirá mejor.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_checking)
              const LinearProgressIndicator(minHeight: 3)
            else
              Text(
                _isExempt
                    ? 'LocMotos puede usar GPS en segundo plano.'
                    : 'Aún puede estar restringido — conviene revisarlo.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _isExempt ? colors.primary : colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _checking ? null : () => unawaited(_openBatterySettings()),
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
    );
  }
}
