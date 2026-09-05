import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
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
    final mutedNow = prefs.isPackAlertsMutedAt(DateTime.now());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(titleText: 'Grupo en ruta'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Motos en el mapa', style: HubStyle.sectionTitle()),
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
            activeThumbColor: HubStyle.accent,
            activeTrackColor: HubStyle.accent.withValues(alpha: 0.45),
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
            activeThumbColor: HubStyle.accent,
            activeTrackColor: HubStyle.accent.withValues(alpha: 0.45),
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Qué motos mostrar', style: HubStyle.caption()),
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
              style: HubStyle.caption(),
            ),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Avisos del pelotón', style: HubStyle.sectionTitle()),
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
            activeThumbColor: HubStyle.accent,
            activeTrackColor: HubStyle.accent.withValues(alpha: 0.45),
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
                  style: HubStyle.textButtonStyle(),
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
                style: HubStyle.sectionTitle(color: HubStyle.accent),
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
              activeColor: HubStyle.accent,
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
                style: HubStyle.sectionTitle(color: HubStyle.accent),
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
              activeColor: HubStyle.accent,
              onChanged: (value) => unawaited(controller.setFarMeters(value)),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: HubStyle.textButtonStyle(),
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
