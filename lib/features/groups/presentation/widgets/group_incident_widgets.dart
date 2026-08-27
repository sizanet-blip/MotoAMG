import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loc_motos/features/groups/domain/entities/group_incident.dart';
import 'package:url_launcher/url_launcher.dart';

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
  });

  final bool hasOwnAlert;
  final VoidCallback onEmergency;
  final VoidCallback onBreakdown;
  final VoidCallback onSeparated;
  final VoidCallback onClear;
  final VoidCallback? onWait;
  final bool showWait;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasOwnAlert) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
                onPressed: enabled ? onClear : null,
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text(
                  'Ya estoy OK',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (showWait && onWait != null) ...[
              OutlinedButton.icon(
                onPressed: enabled ? onWait : null,
                icon: const Icon(Icons.groups_rounded, size: 18),
                label: const Text('Esperar / reunir'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6A1B9A),
                  side: const BorderSide(color: Color(0xFF6A1B9A)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
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
      ),
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
class GroupIncidentBanner extends StatelessWidget {
  const GroupIncidentBanner({
    super.key,
    required this.incident,
    this.onDismiss,
    this.canClear = false,
    this.onClear,
  });

  final GroupIncident incident;
  final VoidCallback? onDismiss;
  final bool canClear;
  final VoidCallback? onClear;

  Color get _color {
    if (incident.type != GroupIncidentType.emergencia) {
      return switch (incident.type) {
        GroupIncidentType.averia => const Color(0xFFEF6C00),
        GroupIncidentType.separado => const Color(0xFF1565C0),
        GroupIncidentType.espera => const Color(0xFF6A1B9A),
        GroupIncidentType.emergencia => const Color(0xFFC62828),
      };
    }
    return switch (incident.severity) {
      GroupIncidentSeverity.critica => const Color(0xFFB71C1C),
      GroupIncidentSeverity.alta => const Color(0xFFC62828),
      GroupIncidentSeverity.moderada => const Color(0xFFE53935),
      GroupIncidentSeverity.leve => const Color(0xFFEF5350),
      null => const Color(0xFFC62828),
    };
  }

  @override
  Widget build(BuildContext context) {
    final name = (incident.displayName ?? 'Motero').trim();
    final title = incident.type == GroupIncidentType.emergencia
        ? '${incident.type.label} · ${incident.severity?.shortBanner ?? 'GRAVE'}'
        : incident.type.label;
    final coords =
        '${incident.point.lat.toStringAsFixed(5)}, ${incident.point.lng.toStringAsFixed(5)}';

    return Material(
      elevation: 3,
      color: _color,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$name · $title',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    tooltip: 'Ocultar solo en este móvil',
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
              ],
            ),
            if (incident.type == GroupIncidentType.emergencia &&
                (incident.severity == GroupIncidentSeverity.critica ||
                    incident.severity == GroupIncidentSeverity.alta)) ...[
              Text(
                coords,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (incident.isCriticalEmergency)
                    _BannerAction(
                      label: 'Llamar 112',
                      onTap: () => launchUrl(Uri.parse('tel:112')),
                    ),
                  _BannerAction(
                    label: 'Copiar ubicación',
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: coords));
                    },
                  ),
                  _BannerAction(
                    label: 'Abrir mapas',
                    onTap: () {
                      final uri = Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=${incident.point.lat},${incident.point.lng}',
                      );
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                  ),
                ],
              ),
            ],
            if (canClear && onClear != null) ...[
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _color,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: onClear,
                child: const Text(
                  'Ya estoy OK · quitar aviso',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BannerAction extends StatelessWidget {
  const _BannerAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white24,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

Future<bool> confirmGroupIncident(
  BuildContext context, {
  required GroupIncidentType type,
}) async {
  final ok = await showDialog<bool>(
    context: context,
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
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Gravedad de la emergencia',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
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
        ),
      );
    },
  );
}
