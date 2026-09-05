import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errorColor = Theme.of(context).colorScheme.error;

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(titleText: 'Grupo'),
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudieron cargar las opciones del grupo.',
              textAlign: TextAlign.center,
              style: HubStyle.body(),
            ),
          ),
        ),
        data: (group) {
          if (group == null || !group.isActive) {
            return Center(
              child: Text('Este grupo ya está cerrado.', style: HubStyle.body()),
            );
          }
          final iAmAdmin = group.isAdmin(user.uid);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(group.name, style: HubStyle.headline()),
              const SizedBox(height: 6),
              Text(
                group.isOwner(user.uid)
                    ? 'Eres el creador. Gestionas admins, ruta y roles de marcha.'
                    : iAmAdmin
                        ? 'Eres administrador: puedes publicar la ruta y asignar cabecera/cola.'
                        : 'Comparte el código para que se unan más moteros.',
                style: HubStyle.body(),
              ),
              const SizedBox(height: 16),
              _InviteCodeCard(code: group.code, isDark: isDark),
              const SizedBox(height: 24),
              if (group.isOwner(user.uid)) ...[
                Text('Intercom del pelotón', style: HubStyle.sectionTitle()),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: HubStyle.accent,
                  secondary: const Icon(
                    Icons.headset_mic_outlined,
                    color: HubStyle.accent,
                  ),
                  title: Text(
                    'Activar intercom del grupo',
                    style: HubStyle.body(color: HubStyle.title),
                  ),
                  subtitle: Text(
                    group.intercomEnabled
                        ? 'Canal de voz activo: en el mapa solo se controla Hablar y Oír.'
                        : 'Solo tú puedes encenderlo. El resto se une al abrirlo.',
                    style: HubStyle.caption(),
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
                  leading: const Icon(
                    Icons.headset_mic,
                    color: HubStyle.accent,
                  ),
                  title: Text(
                    'Intercom del grupo activo',
                    style: HubStyle.body(color: HubStyle.title),
                  ),
                  subtitle: Text(
                    'En el mapa puedes silenciar Hablar u Oír. '
                    'Lo apaga solo el creador.',
                    style: HubStyle.caption(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text('Moteros', style: HubStyle.sectionTitle()),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => Text(
                  'No se pudo cargar la lista.',
                  style: HubStyle.body(),
                ),
                data: (members) => _MembersCard(
                  user: user,
                  group: group,
                  members: members,
                  groupId: groupId,
                  busy: busy,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'La ubicación se sigue enviando con la pantalla apagada. '
                'Verás una notificación de MotoAMG mientras estés en el grupo.',
                style: HubStyle.caption(),
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
                    foregroundColor: errorColor,
                    side: BorderSide(color: errorColor, width: 1.4),
                    textStyle: HubStyle.body(color: errorColor).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Se borra el grupo, el código y la ruta compartida. '
                  'No se puede deshacer.',
                  style: HubStyle.caption(),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _confirmLeave(context, ref),
                  style: HubStyle.outlinedButtonStyle(),
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
        backgroundColor: HubStyle.surface,
        title: Text('¿Salir del grupo?', style: HubStyle.sectionTitle()),
        content: Text(
          'Podrás unirte otra vez con el código.',
          style: HubStyle.body(),
        ),
        actions: [
          TextButton(
            style: HubStyle.textButtonStyle(),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: HubStyle.filledButtonStyle(),
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
        backgroundColor: HubStyle.surface,
        title: Text('¿Eliminar el grupo?', style: HubStyle.sectionTitle()),
        content: Text(
          'Se borrará «${group.name}», el código ${group.code} y la ruta '
          'compartida. Los demás moteros dejarán de verlo.\n\n'
          'Esta acción no se puede deshacer.',
          style: HubStyle.body(),
        ),
        actions: [
          TextButton(
            style: HubStyle.textButtonStyle(),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: HubStyle.filledButtonStyle().copyWith(
              backgroundColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.error,
              ),
              foregroundColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.onError,
              ),
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
  const _InviteCodeCard({required this.code, required this.isDark});

  final String code;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final shareText =
        'Únete a mi grupo en MotoAMG.\nCódigo: $code';
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : HubStyle.cardShadow,
      ),
      child: Material(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Código de invitación', style: HubStyle.caption()),
              const SizedBox(height: 8),
              Text(
                code,
                textAlign: TextAlign.center,
                style: HubStyle.headline(color: HubStyle.accent).copyWith(
                  letterSpacing: 4,
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
                style: HubStyle.caption(),
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
                      style: HubStyle.outlinedButtonStyle(),
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
                      style: HubStyle.filledButtonStyle(),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Compartir'),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
    required this.isDark,
  });

  final AppUser user;
  final RideGroup group;
  final List<GroupMember> members;
  final String groupId;
  final bool busy;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (members.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? null : HubStyle.cardShadow,
        ),
        child: Material(
          color: isDark
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Aún no hay moteros en el grupo.',
              style: HubStyle.body(),
            ),
          ),
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

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : HubStyle.cardShadow,
      ),
      child: Material(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        backgroundColor: HubStyle.surface,
        title: Text(
          '¿Quitar a ${member.displayName}?',
          style: HubStyle.sectionTitle(),
        ),
        content: Text(
          'Dejará de ver la ruta. Podrá volver a entrar con el código.',
          style: HubStyle.body(),
        ),
        actions: [
          TextButton(
            style: HubStyle.textButtonStyle(),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: HubStyle.filledButtonStyle(),
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
      if (isMe) const _RoleChip(label: 'Tú', color: HubStyle.accent),
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
      leading: CircleAvatar(
        backgroundColor: HubStyle.accent,
        foregroundColor: Colors.white,
        child: Text(
          initial,
          style: HubStyle.sectionTitle(color: Colors.white),
        ),
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: HubStyle.sectionTitle(),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 4, runSpacing: 4, children: chips),
          ],
          if (subtitleParts.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(subtitleParts.join(' · '), style: HubStyle.caption()),
          ],
        ],
      ),
      isThreeLine: chips.isNotEmpty && subtitleParts.isNotEmpty,
      trailing: canManage
          ? PopupMenuButton<_MemberAction>(
              tooltip: 'Gestionar',
              icon: const Icon(Icons.more_vert_rounded, color: HubStyle.title),
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
                      style: HubStyle.body(color: HubStyle.title),
                    ),
                  ),
                ],
                PopupMenuItem(
                  value: _MemberAction.cabecera,
                  child: Text(
                    'Asignar cabecera',
                    style: HubStyle.body(color: HubStyle.title),
                  ),
                ),
                PopupMenuItem(
                  value: _MemberAction.cola,
                  child: Text(
                    'Asignar cola',
                    style: HubStyle.body(color: HubStyle.title),
                  ),
                ),
                if (member.rideRole != null)
                  PopupMenuItem(
                    value: _MemberAction.clearRole,
                    child: Text(
                      'Quitar rol de marcha',
                      style: HubStyle.body(color: HubStyle.title),
                    ),
                  ),
                if (canRemove)
                  PopupMenuItem(
                    value: _MemberAction.remove,
                    child: Text(
                      'Quitar del grupo',
                      style: HubStyle.body(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
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
