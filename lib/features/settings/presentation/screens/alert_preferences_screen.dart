import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/navigation/domain/entities/alert_preferences.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';

/// Configuración de avisos HUD / mapa / voz durante la navegación.
class AlertPreferencesScreen extends ConsumerWidget {
  const AlertPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(alertPreferencesProvider);
    final notifier = ref.read(alertPreferencesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos de navegación'),
        actions: [
          TextButton(
            onPressed: () async {
              await notifier.reset();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Valores restablecidos')),
                );
              }
            },
            child: const Text('Restablecer'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Elige qué avisos ver y oír en ruta. Por defecto todo está activado.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          _SectionCard(
            icon: Icons.speed_outlined,
            title: 'Radares',
            children: [
              SwitchListTile(
                title: const Text('Avisos de radar'),
                value: prefs.radarsEnabled,
                onChanged: (v) =>
                    notifier.update((p) => p.copyWith(radarsEnabled: v)),
              ),
              if (prefs.radarsEnabled) ...[
                SwitchListTile(
                  title: const Text('Mostrar en el mapa'),
                  value: prefs.radarShowOnMap,
                  onChanged: (v) =>
                      notifier.update((p) => p.copyWith(radarShowOnMap: v)),
                ),
                SwitchListTile(
                  title: const Text('Aviso por voz'),
                  value: prefs.radarVoiceEnabled,
                  onChanged: (v) =>
                      notifier.update((p) => p.copyWith(radarVoiceEnabled: v)),
                ),
                _MultiDistanceChips(
                  label: 'Avisar a (puedes marcar varias)',
                  subtitle:
                      'Ej.: 800 m, 500 m y 200 m. El más cercano es el aviso fuerte.',
                  selected: prefs.radarAnnounceDistances,
                  options: AlertPreferences.radarAnnounceOptions,
                  onChanged: (next) => notifier.update(
                    (p) => p.copyWith(radarAnnounceDistances: next),
                  ),
                ),
              ],
            ],
          ),
          _SectionCard(
            icon: Icons.local_gas_station_outlined,
            title: 'Gasolineras',
            children: [
              SwitchListTile(
                title: const Text('Avisos de gasolinera'),
                value: prefs.fuelEnabled,
                onChanged: (v) =>
                    notifier.update((p) => p.copyWith(fuelEnabled: v)),
              ),
              if (prefs.fuelEnabled) ...[
                SwitchListTile(
                  title: const Text('Mostrar en el mapa'),
                  value: prefs.fuelShowOnMap,
                  onChanged: (v) =>
                      notifier.update((p) => p.copyWith(fuelShowOnMap: v)),
                ),
                SwitchListTile(
                  title: const Text('Mostrar precio'),
                  subtitle: const Text(
                    'Si se desactiva, solo verás la marca',
                  ),
                  value: prefs.fuelShowPrice,
                  onChanged: (v) =>
                      notifier.update((p) => p.copyWith(fuelShowPrice: v)),
                ),
                SwitchListTile(
                  title: const Text('Aviso por voz'),
                  value: prefs.fuelVoiceEnabled,
                  onChanged: (v) =>
                      notifier.update((p) => p.copyWith(fuelVoiceEnabled: v)),
                ),
                _DistanceChips(
                  label: 'Mostrar aviso a',
                  value: prefs.fuelAnnounceMeters,
                  options: AlertPreferences.fuelAnnounceOptions,
                  onSelected: (m) => notifier.update(
                    (p) => p.copyWith(fuelAnnounceMeters: m),
                  ),
                ),
              ],
            ],
          ),
          _SectionCard(
            icon: Icons.toll_outlined,
            title: 'Peajes',
            children: [
              SwitchListTile(
                title: const Text('Avisos de peaje'),
                value: prefs.tollsEnabled,
                onChanged: (v) =>
                    notifier.update((p) => p.copyWith(tollsEnabled: v)),
              ),
              if (prefs.tollsEnabled) ...[
                SwitchListTile(
                  title: const Text('Mostrar en el mapa'),
                  value: prefs.tollShowOnMap,
                  onChanged: (v) =>
                      notifier.update((p) => p.copyWith(tollShowOnMap: v)),
                ),
                SwitchListTile(
                  title: const Text('Aviso por voz'),
                  value: prefs.tollVoiceEnabled,
                  onChanged: (v) =>
                      notifier.update((p) => p.copyWith(tollVoiceEnabled: v)),
                ),
                _DistanceChips(
                  label: 'Mostrar aviso a',
                  value: prefs.tollAnnounceMeters,
                  options: AlertPreferences.tollAnnounceOptions,
                  onSelected: (m) => notifier.update(
                    (p) => p.copyWith(tollAnnounceMeters: m),
                  ),
                ),
              ],
            ],
          ),
          _SectionCard(
            icon: Icons.turn_sharp_right,
            title: 'Curvas pronunciadas',
            children: [
              SwitchListTile(
                title: const Text('Detectar curvas'),
                value: prefs.curvesEnabled,
                onChanged: (v) =>
                    notifier.update((p) => p.copyWith(curvesEnabled: v)),
              ),
              if (prefs.curvesEnabled) ...[
                SwitchListTile(
                  title: const Text('Mostrar en el mapa'),
                  subtitle: const Text(
                    'Desactivado por defecto para no saturar',
                  ),
                  value: prefs.curvesShowOnMap,
                  onChanged: (v) =>
                      notifier.update((p) => p.copyWith(curvesShowOnMap: v)),
                ),
                SwitchListTile(
                  title: const Text('Aviso por voz'),
                  value: prefs.curvesVoiceEnabled,
                  onChanged: (v) =>
                      notifier.update((p) => p.copyWith(curvesVoiceEnabled: v)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(icon, color: colors.primary),
            title: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _DistanceChips extends StatelessWidget {
  const _DistanceChips({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final double value;
  final List<double> options;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text(formatAlertDistanceMeters(option)),
                  selected: (value - option).abs() < 0.5,
                  onSelected: (_) => onSelected(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MultiDistanceChips extends StatelessWidget {
  const _MultiDistanceChips({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final List<double> selected;
  final List<double> options;
  final ValueChanged<List<double>> onChanged;

  bool _isSelected(double option) =>
      selected.any((m) => (m - option).abs() < 0.5);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                FilterChip(
                  label: Text(formatAlertDistanceMeters(option)),
                  selected: _isSelected(option),
                  onSelected: (want) {
                    final next = List<double>.from(selected);
                    if (want) {
                      if (!_isSelected(option)) {
                        next.add(option);
                      }
                    } else {
                      // Mantener al menos una distancia.
                      if (next.length <= 1) {
                        return;
                      }
                      next.removeWhere((m) => (m - option).abs() < 0.5);
                    }
                    onChanged(next);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
