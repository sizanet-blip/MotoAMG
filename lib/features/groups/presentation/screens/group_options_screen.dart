import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moto_amg/core/utils/distance_format.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/groups/domain/entities/group_member.dart';
import 'package:moto_amg/features/groups/domain/entities/ride_group.dart';
import 'package:moto_amg/features/groups/domain/entities/ride_role.dart';
import 'package:moto_amg/features/groups/presentation/providers/group_providers.dart';
import 'package:moto_amg/features/tracking/domain/entities/device_position.dart';
import 'package:moto_amg/features/tracking/domain/entities/live_location.dart';
import 'package:moto_amg/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

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
        error: (error, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
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
          final iAmAdmin = group.isAdmin(user.uid);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(group.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                group.isOwner(user.uid)
                    ? 'Eres el creador. Gestionas admins, ruta y roles de marcha.'
                    : iAmAdmin
                        ? 'Eres administrador: puedes publicar la ruta y asignar cabecera/cola.'
                        : 'Comparte el código para que se unan más moteros.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _InviteCodeCard(code: group.code),
              const SizedBox(height: 24),
              if (group.isOwner(user.uid)) ...[
                Text(
                  'Intercom del pelotón',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.headset_mic_outlined),
                  title: const Text('Activar intercom del grupo'),
                  subtitle: Text(
                    group.intercomEnabled
                        ? 'Canal de voz activo: en el mapa solo se controla Hablar y Oír.'
                        : 'Solo tú puedes encenderlo. El resto se une al abrirlo.',
                  ),
                  value: group.intercomEnabled,
                  onChanged: busy
                      ? null
                      : (value) {
                          ref
                              .read(groupActionControllerProvider.notifier)
                              .setGroupIntercomEnabled(
                                actor: user,
                                groupId: groupId,
                                enabled: value,
                              );
                        },
                ),
                const SizedBox(height: 16),
              ] else if (group.intercomEnabled) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.headset_mic,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Intercom del grupo activo'),
                  subtitle: const Text(
                    'En el mapa puedes silenciar Hablar u Oír. '
                    'Lo apaga solo el creador.',
                  ),
                ),
                const SizedBox(height: 16),
              ],
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
                'Verás una notificación de MotoAMG mientras estés en el grupo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              if (group.isOwner(user.uid)) ...[
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _confirmDeleteGroup(context, ref, group),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Eliminar grupo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Se borra el grupo, el código y la ruta compartida. '
                  'No se puede deshacer.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _confirmLeave(context, ref),
                  icon: const Icon(Icons.logout),
                  label: const Text('Salir del grupo'),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir del grupo?'),
        content: const Text('Podrás unirte otra vez con el código.'),
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

  Future<void> _confirmDeleteGroup(
    BuildContext context,
    WidgetRef ref,
    RideGroup group,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar el grupo?'),
        content: Text(
          'Se borrará «${group.name}», el código ${group.code} y la ruta '
          'compartida. Los demás moteros dejarán de verlo.\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref
          .read(groupActionControllerProvider.notifier)
          .deleteGroup(user: user, groupId: groupId);
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final shareText =
        'Únete a mi grupo en MotoAMG.\nCódigo: $code';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Código de invitación',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Text(
              code,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Center(
              child: QrImageView(
                data: code,
                version: QrVersions.auto,
                size: 160,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enséñalo en el parking o bar. El otro motero escribe el código en la app.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Código copiado')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(text: shareText),
                    ),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Compartir'),
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
    final iAmAdmin = group.isAdmin(user.uid);
    final iAmOwner = group.isOwner(user.uid);

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
              isAdmin: group.isAdmin(members[i].uid),
              distanceLabel: _distanceLabel(
                member: members[i],
                own: own,
                location: byUid[members[i].uid],
              ),
              canManage: iAmAdmin && !busy,
              canManageAdmins: iAmOwner && !busy,
              canRemove: iAmAdmin &&
                  members[i].uid != user.uid &&
                  !group.isOwner(members[i].uid) &&
                  !busy,
              onRemove: () => _confirmRemove(context, ref, members[i]),
              onSetAdmin: (value) => ref
                  .read(groupActionControllerProvider.notifier)
                  .setMemberAdmin(
                    actor: user,
                    groupId: groupId,
                    memberUid: members[i].uid,
                    isAdmin: value,
                  ),
              onSetRideRole: (role) => ref
                  .read(groupActionControllerProvider.notifier)
                  .setMemberRideRole(
                    actor: user,
                    groupId: groupId,
                    memberUid: members[i].uid,
                    role: role,
                  ),
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
    await ref.read(groupActionControllerProvider.notifier).removeMember(
          owner: user,
          groupId: groupId,
          member: member,
        );
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
    required this.isAdmin,
    required this.distanceLabel,
    required this.canManage,
    required this.canManageAdmins,
    required this.canRemove,
    required this.onRemove,
    required this.onSetAdmin,
    required this.onSetRideRole,
  });

  final GroupMember member;
  final bool isMe;
  final bool isCreator;
  final bool isAdmin;
  final String? distanceLabel;
  final bool canManage;
  final bool canManageAdmins;
  final bool canRemove;
  final VoidCallback onRemove;
  final ValueChanged<bool> onSetAdmin;
  final ValueChanged<RideRole?> onSetRideRole;

  @override
  Widget build(BuildContext context) {
    final name = member.displayName.trim().isEmpty
        ? 'Motero'
        : member.displayName.trim();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final chips = <Widget>[
      if (isMe) const _RoleChip(label: 'Tú', color: Color(0xFF1565C0)),
      if (isCreator)
        const _RoleChip(label: 'Creador', color: Color(0xFF6A1B9A)),
      if (isAdmin && !isCreator)
        const _RoleChip(label: 'Admin', color: Color(0xFF00838F)),
      if (member.rideRole == RideRole.cabecera)
        const _RoleChip(label: 'Cabecera', color: Color(0xFF2E7D32)),
      if (member.rideRole == RideRole.cola)
        const _RoleChip(label: 'Cola', color: Color(0xFFEF6C00)),
    ];
    final subtitleParts = <String>[
      if (member.bikeLabel.isNotEmpty) member.bikeLabel,
      if (member.bikePlate != null && member.bikePlate!.trim().isNotEmpty)
        member.bikePlate!.trim().toUpperCase(),
      ?distanceLabel,
    ];

    return ListTile(
      leading: CircleAvatar(child: Text(initial)),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 4, runSpacing: 4, children: chips),
          ],
          if (subtitleParts.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(subtitleParts.join(' · ')),
          ],
        ],
      ),
      isThreeLine: chips.isNotEmpty && subtitleParts.isNotEmpty,
      trailing: canManage
          ? PopupMenuButton<_MemberAction>(
              tooltip: 'Gestionar',
              onSelected: (action) {
                switch (action) {
                  case _MemberAction.makeAdmin:
                    onSetAdmin(true);
                  case _MemberAction.removeAdmin:
                    onSetAdmin(false);
                  case _MemberAction.cabecera:
                    onSetRideRole(RideRole.cabecera);
                  case _MemberAction.cola:
                    onSetRideRole(RideRole.cola);
                  case _MemberAction.clearRole:
                    onSetRideRole(null);
                  case _MemberAction.remove:
                    onRemove();
                }
              },
              itemBuilder: (context) => [
                if (canManageAdmins && !isCreator) ...[
                  PopupMenuItem(
                    value: isAdmin
                        ? _MemberAction.removeAdmin
                        : _MemberAction.makeAdmin,
                    child: Text(
                      isAdmin ? 'Quitar administrador' : 'Hacer administrador',
                    ),
                  ),
                ],
                const PopupMenuItem(
                  value: _MemberAction.cabecera,
                  child: Text('Asignar cabecera'),
                ),
                const PopupMenuItem(
                  value: _MemberAction.cola,
                  child: Text('Asignar cola'),
                ),
                if (member.rideRole != null)
                  const PopupMenuItem(
                    value: _MemberAction.clearRole,
                    child: Text('Quitar rol de marcha'),
                  ),
                if (canRemove)
                  const PopupMenuItem(
                    value: _MemberAction.remove,
                    child: Text('Quitar del grupo'),
                  ),
              ],
            )
          : null,
    );
  }
}

enum _MemberAction {
  makeAdmin,
  removeAdmin,
  cabecera,
  cola,
  clearRole,
  remove,
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
