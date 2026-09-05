import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/utils/distance_format.dart';
import 'package:moto_amg/features/groups/data/repositories/group_pack_alert_repository.dart';
import 'package:moto_amg/features/groups/presentation/providers/group_providers.dart';

/// Configuración general de grupo en ruta (avisos + qué motos ver).
class GroupRideSettingsScreen extends ConsumerWidget {
  const GroupRideSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(groupPackAlertProvider);
    final controller = ref.read(groupPackAlertProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final mutedNow = prefs.isPackAlertsMutedAt(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Grupo en ruta')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Motos en el mapa',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.groups_outlined),
            title: const Text('Mostrar grupo al navegar'),
            subtitle: const Text(
              'Al abrir la ruta del grupo, ver las motos en el mapa. '
              'También puedes activarlo o quitarlo con el botón del grupo '
              'mientras navegas.',
            ),
            value: prefs.showGroupOnNavigation,
            onChanged: (value) =>
                unawaited(controller.setShowGroupOnNavigation(value)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.navigation_outlined),
            title: const Text('Navegar con Waze o Google Maps'),
            subtitle: const Text(
              'En el mapa de grupo verás Waze/Maps como opción principal '
              'y MotoAMG solo para seguir al pelotón.',
            ),
            value: prefs.preferExternalNavigation,
            onChanged: (value) =>
                unawaited(controller.setPreferExternalNavigation(value)),
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Qué motos mostrar',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<GroupMateDisplayMode>(
              segments: [
                ButtonSegment(
                  value: GroupMateDisplayMode.all,
                  label: Text(GroupMateDisplayMode.all.label),
                  icon: const Icon(Icons.motorcycle_outlined),
                ),
                ButtonSegment(
                  value: GroupMateDisplayMode.cabeceraCola,
                  label: const Text('Cabecera y cola'),
                  icon: const Icon(Icons.filter_alt_outlined),
                ),
              ],
              selected: {prefs.mateDisplayMode},
              onSelectionChanged: (selected) {
                unawaited(controller.setMateDisplayMode(selected.first));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              prefs.mateDisplayMode.subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Avisos del pelotón',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.campaign_outlined),
            title: const Text('Avisar si alguien se queda'),
            subtitle: const Text(
              'Vibración y voz cuando un compañero se aleja de ti. '
              'Las emergencias no se silencian.',
            ),
            value: prefs.enabled,
            onChanged: (value) => unawaited(controller.setEnabled(value)),
          ),
          if (prefs.enabled) ...[
            if (mutedNow)
              ListTile(
                leading: const Icon(Icons.notifications_off_outlined),
                title: const Text('Avisos de distancia silenciados'),
                subtitle: Text(
                  'Hasta ${_formatMuteUntil(prefs.packAlertsMutedUntil!)}',
                ),
                trailing: TextButton(
                  onPressed: () =>
                      unawaited(controller.clearPackAlertsMute()),
                  child: const Text('Reactivar'),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final minutes in [5, 10, 15])
                      ActionChip(
                        avatar:
                            const Icon(Icons.notifications_paused, size: 18),
                        label: Text('Silenciar $minutes min'),
                        onPressed: () => unawaited(
                          controller.mutePackAlertsFor(
                            Duration(minutes: minutes),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ListTile(
              title: const Text('Se queda atrás'),
              subtitle: Text(
                'Aviso a partir de ${formatRideDistance(prefs.behindMeters)}',
              ),
              trailing: Text(
                formatRideDistance(prefs.behindMeters),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Slider(
              value: prefs.behindMeters.clamp(
                GroupPackAlertPreferences.minBehindMeters,
                GroupPackAlertPreferences.maxBehindMeters,
              ),
              min: GroupPackAlertPreferences.minBehindMeters,
              max: GroupPackAlertPreferences.maxBehindMeters,
              divisions: 36,
              label: formatRideDistance(prefs.behindMeters),
              onChanged: (value) =>
                  unawaited(controller.setBehindMeters(value)),
            ),
            ListTile(
              title: const Text('Muy lejos'),
              subtitle: Text(
                'Aviso más fuerte a partir de ${formatRideDistance(prefs.farMeters)}',
              ),
              trailing: Text(
                formatRideDistance(prefs.farMeters),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Slider(
              value: prefs.farMeters.clamp(
                prefs.behindMeters + GroupPackAlertPreferences.minFarGapMeters,
                6000,
              ),
              min: prefs.behindMeters +
                  GroupPackAlertPreferences.minFarGapMeters,
              max: 6000,
              divisions: 40,
              label: formatRideDistance(prefs.farMeters),
              onChanged: (value) => unawaited(controller.setFarMeters(value)),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => unawaited(controller.reset()),
              child: const Text('Restablecer'),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatMuteUntil(DateTime at) {
  final h = at.hour.toString().padLeft(2, '0');
  final m = at.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
