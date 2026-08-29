import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/widgets/keyboard_safe_sheet_body.dart';
import 'package:loc_motos/features/groups/domain/entities/group_incident.dart';
import 'package:loc_motos/features/groups/domain/services/critical_emergency_actions.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/settings/data/repositories/emergency_contacts_repository.dart';
import 'package:loc_motos/features/settings/presentation/providers/settings_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Color de la advertencia (mismo que el banner).
Color groupIncidentColor({
  GroupIncidentType? type,
  GroupIncidentSeverity? severity,
}) {
  if (type == null) {
    return const Color(0xFF2E7D32);
  }
  if (type != GroupIncidentType.emergencia) {
    return switch (type) {
      GroupIncidentType.averia => const Color(0xFFEF6C00),
      GroupIncidentType.separado => const Color(0xFF1565C0),
      GroupIncidentType.espera => const Color(0xFF6A1B9A),
      GroupIncidentType.emergencia => const Color(0xFFC62828),
    };
  }
  return switch (severity) {
    GroupIncidentSeverity.critica => const Color(0xFFB71C1C),
    GroupIncidentSeverity.alta => const Color(0xFFC62828),
    GroupIncidentSeverity.moderada => const Color(0xFFE53935),
    GroupIncidentSeverity.leve => const Color(0xFFEF5350),
    null => const Color(0xFFC62828),
  };
}

/// Barra inferior de incidencias del grupo.
class GroupIncidentActionsBar extends StatelessWidget {
  const GroupIncidentActionsBar({
    super.key,
    required this.hasOwnAlert,
    required this.onEmergency,
    required this.onBreakdown,
    required this.onSeparated,
    required this.onClear,
    this.onWait,
    this.showWait = false,
    this.enabled = true,
    this.compact = false,
    this.embedded = false,
    this.vertical = false,
    this.tight = false,
    this.ownAlertColor,
  });

  final bool hasOwnAlert;
  final VoidCallback onEmergency;
  final VoidCallback onBreakdown;
  final VoidCallback onSeparated;
  final VoidCallback onClear;
  final VoidCallback? onWait;
  final bool showWait;
  final bool enabled;

  /// Landscape / poco alto: una sola fila compacta.
  final bool compact;

  /// Dentro de un panel compartido (sin Material propio).
  final bool embedded;

  /// Landscape: columna de iconos en el lateral.
  final bool vertical;

  /// Iconos pequeños, sin Expanded (una fila junto a otros botones).
  final bool tight;

  /// Color del aviso propio (fondo del botón OK / check blanco).
  final Color? ownAlertColor;

  Color get _okColor => ownAlertColor ?? const Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final content = vertical
        ? _buildVertical(context)
        : tight
            ? _buildTight(context)
            : compact
                ? _buildCompact(context)
                : _buildExpanded(context);
    if (embedded) {
      return content;
    }
    return Material(
      elevation: compact || vertical ? 4 : 6,
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(compact || vertical ? 14 : 16),
      child: content,
    );
  }

  Widget _buildVertical(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasOwnAlert) ...[
            _SideIncidentIcon(
              color: _okColor,
              icon: Icons.check_rounded,
              tooltip: 'Ya estoy OK',
              onPressed: enabled ? onClear : null,
            ),
            const SizedBox(height: 6),
          ],
          if (showWait && onWait != null) ...[
            _SideIncidentIcon(
              color: const Color(0xFF8E24AA),
              icon: Icons.front_hand_rounded,
              tooltip: 'Esperar / reunir',
              onPressed: enabled ? onWait : null,
            ),
            const SizedBox(height: 6),
          ],
          _SideIncidentIcon(
            color: const Color(0xFFC62828),
            icon: Icons.emergency_rounded,
            tooltip: 'Emergencia',
            onPressed: enabled ? onEmergency : null,
          ),
          const SizedBox(height: 6),
          _SideIncidentIcon(
            color: const Color(0xFFEF6C00),
            icon: Icons.car_crash_outlined,
            tooltip: 'Avería',
            onPressed: enabled ? onBreakdown : null,
          ),
          const SizedBox(height: 6),
          _SideIncidentIcon(
            color: const Color(0xFF1565C0),
            icon: Icons.person_search_rounded,
            tooltip: 'Separado',
            onPressed: enabled ? onSeparated : null,
          ),
        ],
      ),
    );
  }

  Widget _buildExpanded(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showWait && onWait != null) ...[
            FilledButton.icon(
              onPressed: enabled ? onWait : null,
              icon: const Icon(Icons.front_hand_rounded, size: 18),
              label: const Text('Esperar / reunir'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8E24AA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: const Size(0, 36),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasOwnAlert) ...[
                _SideIncidentIcon(
                  color: _okColor,
                  icon: Icons.check_rounded,
                  tooltip: 'Ya estoy OK',
                  onPressed: enabled ? onClear : null,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: _IncidentButton(
                  label: 'Emergencia',
                  color: const Color(0xFFC62828),
                  icon: Icons.emergency_rounded,
                  onPressed: enabled ? onEmergency : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _IncidentButton(
                  label: 'Avería',
                  color: const Color(0xFFEF6C00),
                  icon: Icons.car_crash_outlined,
                  onPressed: enabled ? onBreakdown : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _IncidentButton(
                  label: 'Separado',
                  color: const Color(0xFF1565C0),
                  icon: Icons.person_search_rounded,
                  onPressed: enabled ? onSeparated : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTight(BuildContext context) {
    Widget btn({
      required Color color,
      required IconData icon,
      required String tooltip,
      required VoidCallback? onPressed,
    }) {
      return IconButton.filled(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          visualDensity: VisualDensity.compact,
          minimumSize: const Size(32, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
        ),
        icon: Icon(icon, size: 18),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasOwnAlert) ...[
          btn(
            color: _okColor,
            icon: Icons.check_rounded,
            tooltip: 'Ya estoy OK',
            onPressed: enabled ? onClear : null,
          ),
          const SizedBox(width: 4),
        ],
        if (showWait && onWait != null) ...[
          btn(
            color: const Color(0xFF8E24AA),
            icon: Icons.groups_rounded,
            tooltip: 'Esperar / reunir',
            onPressed: enabled ? onWait : null,
          ),
          const SizedBox(width: 4),
        ],
        btn(
          color: const Color(0xFFC62828),
          icon: Icons.emergency_rounded,
          tooltip: 'Emergencia',
          onPressed: enabled ? onEmergency : null,
        ),
        const SizedBox(width: 4),
        btn(
          color: const Color(0xFFEF6C00),
          icon: Icons.car_crash_outlined,
          tooltip: 'Avería',
          onPressed: enabled ? onBreakdown : null,
        ),
        const SizedBox(width: 4),
        btn(
          color: const Color(0xFF1565C0),
          icon: Icons.person_search_rounded,
          tooltip: 'Separado',
          onPressed: enabled ? onSeparated : null,
        ),
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        children: [
          if (hasOwnAlert) ...[
            _SideIncidentIcon(
              color: _okColor,
              icon: Icons.check_rounded,
              tooltip: 'Ya estoy OK',
              onPressed: enabled ? onClear : null,
            ),
            const SizedBox(width: 4),
          ],
          if (showWait && onWait != null) ...[
            Expanded(
              child: FilledButton(
                onPressed: enabled ? onWait : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8E24AA),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Icon(Icons.front_hand_rounded, size: 18),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: _CompactIncidentIcon(
              color: const Color(0xFFC62828),
              icon: Icons.emergency_rounded,
              onPressed: enabled ? onEmergency : null,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _CompactIncidentIcon(
              color: const Color(0xFFEF6C00),
              icon: Icons.car_crash_outlined,
              onPressed: enabled ? onBreakdown : null,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _CompactIncidentIcon(
              color: const Color(0xFF1565C0),
              icon: Icons.person_search_rounded,
              onPressed: enabled ? onSeparated : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactIncidentIcon extends StatelessWidget {
  const _CompactIncidentIcon({
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  final Color color;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: Icon(icon, size: 20),
    );
  }
}

class _SideIncidentIcon extends StatelessWidget {
  const _SideIncidentIcon({
    required this.color,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Color color;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  static const _size = 44.0;

  @override
  Widget build(BuildContext context) {
    // IconButton.filled se estira con constraints altos (landscape) y pinta
    // una franja de color; usamos un botón de tamaño fijo como el mapa.
    final button = Material(
      color: onPressed == null ? color.withValues(alpha: 0.45) : color,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: _size,
          height: _size,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
    return Tooltip(
      message: tooltip,
      child: button,
    );
  }
}

class _IncidentButton extends StatelessWidget {
  const _IncidentButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        minimumSize: const Size(0, 40),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

/// Banner compacto de alerta (no tapa el mapa).
class GroupIncidentBanner extends ConsumerWidget {
  const GroupIncidentBanner({
    super.key,
    required this.incident,
    this.onDismiss,
    this.isOwnIncident = false,
    this.onClear,
    this.compact = false,
    this.landscape = false,
  });

  final GroupIncident incident;

  /// Oculta el banner solo en este móvil (el aviso sigue activo en el grupo).
  final VoidCallback? onDismiss;

  /// El aviso es tuyo → botón «Ya estoy OK» (quita el aviso para todo el grupo).
  final bool isOwnIncident;
  final VoidCallback? onClear;
  final bool compact;

  /// Horizontal: una sola fila baja que no tapa los botones laterales.
  final bool landscape;

  Color get _color => groupIncidentColor(
        type: incident.type,
        severity: incident.severity,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = (incident.displayName ?? 'Motero').trim();
    final title = incident.type == GroupIncidentType.emergencia
        ? '${incident.type.label} · ${incident.severity?.shortBanner ?? 'GRAVE'}'
        : incident.type.label;
    final coords =
        '${incident.point.lat.toStringAsFixed(5)}, ${incident.point.lng.toStringAsFixed(5)}';
    final personName = name.isEmpty ? 'Motero' : name;
    final ownContacts = isOwnIncident && incident.isCriticalEmergency
        ? ref.watch(emergencyContactsProvider).validContacts
        : const <EmergencyContact>[];
    final showEmergencyActions = incident.type == GroupIncidentType.emergencia &&
        (incident.severity == GroupIncidentSeverity.critica ||
            incident.severity == GroupIncidentSeverity.alta);

    if (landscape) {
      return _buildLandscape(
        context,
        name: name,
        title: title,
        personName: personName,
        ownContacts: ownContacts,
        showEmergencyActions: showEmergencyActions,
      );
    }

    return Material(
      elevation: 3,
      color: _color,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 8 : 12,
          compact ? 6 : 8,
          compact ? 2 : 4,
          compact ? 6 : 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: compact ? 18 : 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$name · $title',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 12 : 13,
                    ),
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    tooltip: 'Ocultar en mi pantalla (el aviso sigue activo)',
                    onPressed: onDismiss,
                    visualDensity: VisualDensity.compact,
                    iconSize: compact ? 18 : 24,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
              ],
            ),
            if (showEmergencyActions) ...[
              Text(
                coords,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _emergencyActionChips(
                  context,
                  personName: personName,
                  ownContacts: ownContacts,
                ),
              ),
            ],
            if (isOwnIncident && onClear != null) ...[
              SizedBox(height: compact ? 6 : 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _color,
                  padding: EdgeInsets.symmetric(vertical: compact ? 6 : 10),
                  minimumSize: Size(0, compact ? 32 : 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onClear,
                child: Text(
                  compact ? 'Ya estoy OK' : 'Ya estoy OK · quitar aviso',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 12 : 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLandscape(
    BuildContext context, {
    required String name,
    required String title,
    required String personName,
    required List<EmergencyContact> ownContacts,
    required bool showEmergencyActions,
  }) {
    return Material(
      elevation: 3,
      color: _color,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$name · $title',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isOwnIncident && onClear != null) ...[
                  const SizedBox(width: 6),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _color,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onClear,
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (onDismiss != null)
                  IconButton(
                    tooltip: 'Ocultar en mi pantalla',
                    onPressed: onDismiss,
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
              ],
            ),
            if (showEmergencyActions) ...[
              const SizedBox(height: 2),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final chip in _emergencyActionChips(
                      context,
                      personName: personName,
                      ownContacts: ownContacts,
                      dense: true,
                    )) ...[
                      chip,
                      const SizedBox(width: 4),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _emergencyActionChips(
    BuildContext context, {
    required String personName,
    required List<EmergencyContact> ownContacts,
    bool dense = false,
  }) {
    return [
      if (incident.isCriticalEmergency)
        _BannerAction(
          label: '112',
          dense: dense,
          onTap: () => unawaited(
            CriticalEmergencyActions.open112Dialer(),
          ),
        ),
      _BannerAction(
        label: dense ? 'Copiar' : 'Copiar ubicación',
        dense: dense,
        onTap: () async {
          await CriticalEmergencyActions.copyLocation(
            displayName: personName,
            point: incident.point,
          );
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ubicación copiada')),
          );
        },
      ),
      _BannerAction(
        label: dense ? 'Mapas' : 'Abrir mapas',
        dense: dense,
        onTap: () {
          launchUrl(
            CriticalEmergencyActions.mapsSearchUri(incident.point),
            mode: LaunchMode.externalApplication,
          );
        },
      ),
      if (ownContacts.isNotEmpty)
        _BannerAction(
          label: dense ? 'Avisar' : 'Avisar contacto',
          dense: dense,
          onTap: () => unawaited(
            _notifyEmergencyContact(
              context,
              contacts: ownContacts,
              displayName: personName,
              point: incident.point,
            ),
          ),
        ),
    ];
  }
}

Future<void> _notifyEmergencyContact(
  BuildContext context, {
  required List<EmergencyContact> contacts,
  required String displayName,
  required GeoPoint point,
}) async {
  EmergencyContact contact = contacts.first;
  if (contacts.length > 1) {
    final picked = await showModalBottomSheet<EmergencyContact>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('¿A quién avisas?')),
              for (final c in contacts)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(c.name),
                  subtitle: Text(c.phone),
                  onTap: () => Navigator.pop(context, c),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null || !context.mounted) {
      return;
    }
    contact = picked;
  }

  final channel = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Avisar a ${contact.name}'),
              subtitle: const Text('Elige SMS o WhatsApp (manual)'),
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: const Text('SMS'),
              onTap: () => Navigator.pop(context, 'sms'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('WhatsApp'),
              onTap: () => Navigator.pop(context, 'whatsapp'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
  if (channel == null || !context.mounted) {
    return;
  }

  final body = CriticalEmergencyActions.locationClipboardMessage(
    displayName: displayName,
    point: point,
  );
  final ok = channel == 'whatsapp'
      ? await CriticalEmergencyActions.openWhatsApp(
          contact: contact,
          body: body,
        )
      : await CriticalEmergencyActions.openSms(
          contact: contact,
          body: body,
        );
  if (!context.mounted) {
    return;
  }
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo abrir la app. Prueba a copiar la ubicación.'),
      ),
    );
  }
}

class _BannerAction extends StatelessWidget {
  const _BannerAction({
    required this.label,
    required this.onTap,
    this.dense = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white24,
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 10,
          vertical: dense ? 2 : 4,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: dense ? VisualDensity.compact : null,
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(fontSize: dense ? 11 : 12),
      ),
    );
  }
}

Future<bool> confirmGroupIncident(
  BuildContext context, {
  required GroupIncidentType type,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text('¿Avisar: ${type.label}?'),
      content: Text(
        type == GroupIncidentType.espera
            ? 'Todo el grupo verá que pedís esperar o reunirnos.'
            : 'Todo el grupo verá el aviso en el mapa. Úsalo solo si hace falta.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Avisar'),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<GroupIncidentSeverity?> pickEmergencySeverity(
  BuildContext context,
) async {
  return showModalBottomSheet<GroupIncidentSeverity>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return KeyboardSafeSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Gravedad de la emergencia',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Si eliges Urgente · 112 se avisará al grupo y se abrirá el marcador del 112.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            for (final s in GroupIncidentSeverity.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: s == GroupIncidentSeverity.critica
                        ? const Color(0xFFB71C1C)
                        : const Color(0xFFC62828),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context, s),
                  child: Text(s.label),
                ),
              ),
          ],
        ),
      );
    },
  );
}
