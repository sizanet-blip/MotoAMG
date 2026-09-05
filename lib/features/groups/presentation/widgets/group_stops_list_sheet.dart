import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/groups/domain/entities/group_stop.dart';
import 'package:moto_amg/features/groups/domain/services/group_stop_service.dart';
import 'package:moto_amg/features/groups/presentation/providers/group_providers.dart';
import 'package:moto_amg/features/groups/presentation/widgets/group_stop_widgets.dart';

/// Lista de paradas del grupo: ver, centrar en mapa y quitar.
Future<void> showGroupStopsListSheet({
  required BuildContext context,
  required String groupId,
  required AppUser user,
  required bool canManageStops,
  Future<void> Function(GroupStop stop)? onFocusStop,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.45,
      minChildSize: 0.28,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return GroupStopsListSheet(
          groupId: groupId,
          user: user,
          canManageStops: canManageStops,
          scrollController: scrollController,
          onFocusStop: onFocusStop,
        );
      },
    ),
  );
}

class GroupStopsListSheet extends ConsumerStatefulWidget {
  const GroupStopsListSheet({
    super.key,
    required this.groupId,
    required this.user,
    required this.canManageStops,
    this.scrollController,
    this.onFocusStop,
  });

  final String groupId;
  final AppUser user;
  final bool canManageStops;
  final ScrollController? scrollController;
  final Future<void> Function(GroupStop stop)? onFocusStop;

  @override
  ConsumerState<GroupStopsListSheet> createState() =>
      _GroupStopsListSheetState();
}

class _GroupStopsListSheetState extends ConsumerState<GroupStopsListSheet> {
  final _busyIds = <String>{};

  bool _canDelete(GroupStop stop) {
    return widget.canManageStops || stop.createdBy == widget.user.uid;
  }

  Future<void> _delete(GroupStop stop) async {
    if (_busyIds.contains(stop.id)) {
      return;
    }
    setState(() => _busyIds.add(stop.id));
    try {
      await ref.read(groupStopServiceProvider).clear(
            groupId: widget.groupId,
            stopId: stop.id,
          );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(stop.id));
      }
    }
  }

  Future<void> _confirmDelete(GroupStop stop) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HubStyle.surface,
        title: Text('Quitar parada', style: HubStyle.sectionTitle()),
        content: Text(
          '¿Quitar «${stop.type.shortLabel}» del mapa del grupo?',
          style: HubStyle.body(),
        ),
        actions: [
          TextButton(
            style: HubStyle.textButtonStyle(),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: HubStyle.filledButtonStyle(),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _delete(stop);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stopsAsync = ref.watch(groupStopsProvider(widget.groupId));
    final stops = stopsAsync.valueOrNull ?? const <GroupStop>[];

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Paradas del grupo', style: HubStyle.sectionTitle()),
                Text(
                  widget.canManageStops
                      ? (stops.isEmpty
                          ? 'Mantén pulsado el mapa para marcar una.'
                          : '${stops.length} en el mapa · pulsa para centrar · '
                              'papelera para quitar.')
                      : (stops.isEmpty
                          ? 'Nadie ha marcado paradas todavía.'
                          : '${stops.length} en el mapa · pulsa para ver en el mapa.'),
                  style: HubStyle.caption(),
                ),
              ],
            ),
          ),
          Expanded(
            child: stopsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(
                child: Text('No se pudieron cargar las paradas.'),
              ),
              data: (_) {
                if (stops.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        widget.canManageStops
                            ? 'Aún no hay paradas.\n'
                                'Acerca el mapa con + y mantén pulsado '
                                'donde quieras parar.'
                            : 'Nadie ha marcado paradas todavía.',
                        textAlign: TextAlign.center,
                        style: HubStyle.body(),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  itemCount: stops.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final stop = stops[index];
                    final author = (stop.displayName ?? '').trim();
                    final busy = _busyIds.contains(stop.id);
                    final canDelete = _canDelete(stop);

                    final focusStop = widget.onFocusStop;
                    return ListTile(
                      leading: Icon(iconForGroupStopType(stop.type)),
                      title: Text(stop.type.label),
                      subtitle: Text(
                        [
                          if (author.isNotEmpty) author,
                          _formatTime(stop.at),
                        ].join(' · '),
                      ),
                      onTap: focusStop == null
                          ? null
                          : () {
                              final stopToFocus = stop;
                              Navigator.of(context).pop();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                unawaited(focusStop(stopToFocus));
                              });
                            },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canDelete)
                            IconButton(
                              tooltip: 'Quitar parada',
                              onPressed: busy
                                  ? null
                                  : () => unawaited(_confirmDelete(stop)),
                              icon: busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.delete_outline),
                            ),
                          if (focusStop != null)
                            Icon(
                              Icons.my_location,
                              color: HubStyle.accent,
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTime(DateTime at) {
  final local = at.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
