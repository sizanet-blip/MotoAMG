import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/auth/presentation/widgets/account_menu_button.dart';
import 'package:loc_motos/features/groups/presentation/providers/group_providers.dart';
import 'package:loc_motos/features/groups/presentation/screens/group_options_screen.dart';
import 'package:loc_motos/features/groups/presentation/screens/my_groups_view.dart';
import 'package:loc_motos/features/groups/presentation/widgets/group_entry_dialogs.dart';
import 'package:loc_motos/features/map/presentation/screens/group_map_screen.dart';
import 'package:loc_motos/features/navigation/presentation/screens/navigation_hub_screen.dart';
import 'package:loc_motos/features/tracking/presentation/widgets/location_binder.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveUserProvider(user.uid)).asData?.value;
    final effective = live == null
        ? user
        : live.copyWith(
            displayName: live.displayName.trim().isNotEmpty
                ? live.displayName
                : user.displayName,
          );

    ref.listen(groupActionControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        },
      );
    });

    if (effective.isInGroup) {
      return LocationBinder(
        user: effective,
        groupId: effective.currentGroupId!,
        child: _InGroupView(
          user: effective,
          groupId: effective.currentGroupId!,
        ),
      );
    }
    if (effective.isAnonymous) {
      return _GuestJoinView(user: effective);
    }
    return MyGroupsView(user: effective);
  }
}

class _GuestJoinView extends ConsumerWidget {
  const _GuestJoinView({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(groupActionControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: const [AccountMenuButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Hola, ${user.displayName}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: const Icon(Icons.badge_outlined, size: 18),
                label: const Text('Cuenta de invitado'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pide el código al que organiza la ruta. Al cerrar sesión se '
              'borra todo y no se puede recuperar. Si quieres guardar grupos, '
              'crea una cuenta con usuario o con correo.',
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: busy ? null : () => _joinGroup(context, ref),
              icon: const Icon(Icons.vpn_key_outlined),
              label: const Text('Unirme con un código'),
            ),
            if (busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _joinGroup(BuildContext context, WidgetRef ref) async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const JoinGroupDialog(),
    );
    if (code == null || !context.mounted) {
      return;
    }
    await ref
        .read(groupActionControllerProvider.notifier)
        .joinGroup(user: user, code: code);
  }
}

class _InGroupView extends ConsumerWidget {
  const _InGroupView({required this.user, required this.groupId});

  final AppUser user;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(rideGroupProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    ref.watch(myGroupsProvider(user.uid));
    final busy = ref.watch(groupActionControllerProvider).isLoading;
    final memberCount = membersAsync.valueOrNull?.length ?? 0;
    final groupName = groupAsync.valueOrNull?.name;

    ref.listen(groupMembersProvider(groupId), (previous, next) {
      next.whenData((members) {
        if (members.isEmpty || members.any((member) => member.uid == user.uid)) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Te han quitado del grupo.')),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        ref
            .read(groupActionControllerProvider.notifier)
            .leaveGroup(user: user, groupId: groupId);
      });
    });

    return Scaffold(
      appBar: AppBar(
        leading: user.isAnonymous
            ? null
            : IconButton(
                tooltip: 'Mis grupos',
                onPressed: busy
                    ? null
                    : () => ref
                          .read(groupActionControllerProvider.notifier)
                          .closeMap(user: user),
                icon: const Icon(Icons.arrow_back),
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(groupName ?? AppConstants.appName),
            if (memberCount > 0)
              Text(
                memberCount == 1 ? '1 motero' : '$memberCount moteros',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Navegación',
            onPressed: busy
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NavigationHubScreen(user: user),
                      ),
                    );
                  },
            icon: const Icon(Icons.navigation_outlined),
          ),
          IconButton(
            tooltip: 'Opciones del grupo',
            onPressed: groupAsync.valueOrNull == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GroupOptionsScreen(
                          user: user,
                          groupId: groupId,
                        ),
                      ),
                    );
                  },
            icon: Badge(
              isLabelVisible: memberCount > 0,
              label: Text('$memberCount'),
              child: const Icon(Icons.groups_outlined),
            ),
          ),
          const AccountMenuButton(),
        ],
      ),
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _GroupLoadError(
          onRetry: () {
            ref.invalidate(rideGroupProvider(groupId));
            ref.invalidate(groupMembersProvider(groupId));
          },
          onLeave: busy
              ? null
              : () => ref
                    .read(groupActionControllerProvider.notifier)
                    .leaveGroup(user: user, groupId: groupId),
        ),
        data: (group) {
          if (group == null || !group.isActive) {
            return _ClosedGroupView(
              onLeave: busy
                  ? null
                  : () => ref
                        .read(groupActionControllerProvider.notifier)
                        .leaveGroup(user: user, groupId: groupId),
            );
          }
          return GroupMapView(user: user, groupId: groupId);
        },
      ),
    );
  }
}

class _GroupLoadError extends StatelessWidget {
  const _GroupLoadError({required this.onRetry, required this.onLeave});

  final VoidCallback onRetry;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(
            'No se pudo abrir el grupo.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Prueba otra vez. Si sigue igual, continúa sin grupo y únete con el código.',
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onLeave,
            child: const Text('Continuar sin grupo'),
          ),
        ],
      ),
    );
  }
}

class _ClosedGroupView extends StatelessWidget {
  const _ClosedGroupView({required this.onLeave});

  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Este grupo ya está cerrado.'),
          const Spacer(),
          FilledButton(onPressed: onLeave, child: const Text('Volver')),
        ],
      ),
    );
  }
}
