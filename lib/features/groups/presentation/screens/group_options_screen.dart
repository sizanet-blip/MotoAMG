import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:loc_motos/core/utils/distance_format.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/groups/domain/entities/group_member.dart';
import 'package:loc_motos/features/groups/domain/entities/ride_group.dart';
import 'package:loc_motos/features/groups/presentation/providers/group_providers.dart';
import 'package:loc_motos/features/tracking/domain/entities/device_position.dart';
import 'package:loc_motos/features/tracking/domain/entities/live_location.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';

class GroupOptionsScreen extends ConsumerWidget {
  const GroupOptionsScreen({
    super.key,
    required this.user,
    required this.groupId,
  });

  final AppUser user;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(rideGroupProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    final busy = ref.watch(groupActionControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Grupo')),
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudieron cargar las opciones del grupo.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (group) {
          if (group == null || !group.isActive) {
            return const Center(child: Text('Este grupo ya está cerrado.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(group.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                group.isOwner(user.uid)
                    ? 'Eres el creador. Aquí gestionas el código y los moteros.'
                    : 'Comparte el código para que se unan más moteros.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _InviteCodeCard(code: group.code),
              const SizedBox(height: 24),
              Text('Moteros', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => const Text('No se pudo cargar la lista.'),
                data: (members) => _MembersCard(
                  user: user,
                  group: group,
                  members: members,
                  groupId: groupId,
                  busy: busy,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'La ubicación se sigue enviando con la pantalla apagada. '
                'Verás una notificación de LocMotos mientras estés en el grupo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => _confirmLeave(context, ref, group),
                icon: Icon(
                  group.isOwner(user.uid) ? Icons.meeting_room_outlined : Icons.logout,
                ),
                label: Text(
                  group.isOwner(user.uid)
                      ? 'Cerrar y salir del grupo'
                      : 'Salir del grupo',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    RideGroup group,
  ) async {
    final isOwner = group.isOwner(user.uid);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isOwner ? '¿Cerrar el grupo?' : '¿Salir del grupo?'),
        content: Text(
          isOwner
              ? 'Si sales, el grupo se cierra y el código dejará de valer.'
              : 'Podrás unirte otra vez con el código.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref
          .read(groupActionControllerProvider.notifier)
          .leaveGroup(user: user, groupId: groupId);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Código de invitación',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    code,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copiar código',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código copiado')),
                  );
                }
              },
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersCard extends ConsumerWidget {
  const _MembersCard({
    required this.user,
    required this.group,
    required this.members,
    required this.groupId,
    required this.busy,
  });

  final AppUser user;
  final RideGroup group;
  final List<GroupMember> members;
  final String groupId;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (members.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Aún no hay moteros en el grupo.'),
        ),
      );
    }

    final locations =
        ref.watch(groupLocationsProvider(groupId)).valueOrNull ??
        const <LiveLocation>[];
    final own = ref.watch(ownDevicePositionProvider);
    final byUid = {for (final location in locations) location.uid: location};
    final isOwner = group.isOwner(user.uid);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < members.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _MemberTile(
              member: members[i],
              isMe: members[i].uid == user.uid,
              isCreator: group.isOwner(members[i].uid),
              distanceLabel: _distanceLabel(
                member: members[i],
                own: own,
                location: byUid[members[i].uid],
              ),
              canRemove: isOwner && members[i].uid != user.uid && !busy,
              onRemove: () => _confirmRemove(context, ref, members[i]),
            ),
          ],
        ],
      ),
    );
  }

  String? _distanceLabel({
    required GroupMember member,
    required OwnDevicePosition? own,
    required LiveLocation? location,
  }) {
    if (member.uid == user.uid || own == null || location == null) {
      return null;
    }
    return formatRideDistance(
      Geolocator.distanceBetween(own.lat, own.lng, location.lat, location.lng),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Quitar a ${member.displayName}?'),
        content: const Text(
          'Dejará de ver la ruta. Podrá volver a entrar con el código.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      return;
    }
    await ref
        .read(groupActionControllerProvider.notifier)
        .removeMember(owner: user, groupId: groupId, member: member);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Has quitado a ${member.displayName}')),
      );
    }
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.isCreator,
    required this.distanceLabel,
    required this.canRemove,
    required this.onRemove,
  });

  final GroupMember member;
  final bool isMe;
  final bool isCreator;
  final String? distanceLabel;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final name = member.displayName.trim().isEmpty
        ? 'Motero'
        : member.displayName.trim();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final subtitleParts = <String>[
      if (isMe) 'Tú',
      if (isCreator) 'Creador',
      if (member.bikeLabel.isNotEmpty) member.bikeLabel,
      if (member.bikePlate != null && member.bikePlate!.trim().isNotEmpty)
        member.bikePlate!.trim().toUpperCase(),
      ?distanceLabel,
    ];

    return ListTile(
      leading: CircleAvatar(child: Text(initial)),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
      trailing: canRemove
          ? IconButton(
              tooltip: 'Quitar del grupo',
              onPressed: onRemove,
              icon: const Icon(Icons.person_remove_outlined),
            )
          : null,
    );
  }
}
