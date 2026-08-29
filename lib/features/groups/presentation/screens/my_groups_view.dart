import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/widgets/app_brand_title.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/auth/presentation/widgets/account_menu_button.dart';
import 'package:loc_motos/features/groups/domain/entities/group_membership.dart';
import 'package:loc_motos/features/groups/presentation/providers/group_providers.dart';
import 'package:loc_motos/features/groups/presentation/widgets/group_entry_dialogs.dart';
import 'package:loc_motos/features/navigation/presentation/screens/navigation_hub_screen.dart';

class MyGroupsView extends ConsumerWidget {
  const MyGroupsView({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(myGroupsProvider(user.uid));
    final busy = ref.watch(groupActionControllerProvider).isLoading;
    final landscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const AppBrandTitle(),
        actions: const [AccountMenuButton()],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No se pudieron cargar tus grupos.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (groups) {
          final active = groups.where((group) => group.isActive).toList();
          if (landscape) {
            return _LandscapeBody(
              user: user,
              active: active,
              busy: busy,
              onCreate: () => _createGroup(context, ref),
              onJoin: () => _joinGroup(context, ref),
              onOpen: (groupId) => ref
                  .read(groupActionControllerProvider.notifier)
                  .openGroup(user: user, groupId: groupId),
              onNavigate: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NavigationHubScreen(user: user),
                  ),
                );
              },
            );
          }
          return _PortraitBody(
            user: user,
            active: active,
            busy: busy,
            onCreate: () => _createGroup(context, ref),
            onJoin: () => _joinGroup(context, ref),
            onOpen: (groupId) => ref
                .read(groupActionControllerProvider.notifier)
                .openGroup(user: user, groupId: groupId),
            onNavigate: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NavigationHubScreen(user: user),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createGroup(BuildContext context, WidgetRef ref) async {
    final name = await showCreateGroupDialog(context);
    if (name == null || !context.mounted) {
      return;
    }
    await ref
        .read(groupActionControllerProvider.notifier)
        .createGroup(user: user, name: name);
  }

  Future<void> _joinGroup(BuildContext context, WidgetRef ref) async {
    final code = await showJoinGroupDialog(context);
    if (code == null || !context.mounted) {
      return;
    }
    await ref
        .read(groupActionControllerProvider.notifier)
        .joinGroup(user: user, code: code);
  }
}

class _PortraitBody extends StatelessWidget {
  const _PortraitBody({
    required this.user,
    required this.active,
    required this.busy,
    required this.onCreate,
    required this.onJoin,
    required this.onOpen,
    required this.onNavigate,
  });

  final AppUser user;
  final List<GroupMembership> active;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final ValueChanged<String> onOpen;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: active.isEmpty
              ? _EmptyGroups(user: user)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: active.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 8),
                        child: Text(
                          'Elige el grupo de esta ruta. Puedes crear o unirte a más.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }
                    final group = active[index - 1];
                    return _GroupTile(
                      membership: group,
                      enabled: !busy,
                      onOpen: () => onOpen(group.groupId),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _ActionButtons(
              busy: busy,
              stretch: true,
              onCreate: onCreate,
              onJoin: onJoin,
              onNavigate: onNavigate,
            ),
          ),
        ),
      ],
    );
  }
}

class _LandscapeBody extends StatelessWidget {
  const _LandscapeBody({
    required this.user,
    required this.active,
    required this.busy,
    required this.onCreate,
    required this.onJoin,
    required this.onOpen,
    required this.onNavigate,
  });

  final AppUser user;
  final List<GroupMembership> active;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final ValueChanged<String> onOpen;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: active.isEmpty
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: SingleChildScrollView(
                          child: _EmptyGroups(user: user, compact: true),
                        ),
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tus grupos',
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Elige el grupo de esta ruta.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverList.separated(
                          itemCount: active.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final group = active[index];
                            return _GroupTile(
                              membership: group,
                              enabled: !busy,
                              onOpen: () => onOpen(group.groupId),
                            );
                          },
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 20),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: colors.outlineVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 20),
            SizedBox(
              width: 280,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Acciones',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Crear, unirte o ir a navegar.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 16),
                          _ActionButtons(
                            busy: busy,
                            stretch: true,
                            onCreate: onCreate,
                            onJoin: onJoin,
                            onNavigate: onNavigate,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.busy,
    required this.stretch,
    required this.onCreate,
    required this.onJoin,
    required this.onNavigate,
  });

  final bool busy;
  final bool stretch;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    final buttons = Column(
      crossAxisAlignment:
          stretch ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: busy ? null : onCreate,
          icon: const Icon(Icons.add),
          label: const Text('Crear grupo'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: busy ? null : onJoin,
          icon: const Icon(Icons.vpn_key_outlined),
          label: const Text('Unirme con un código'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: busy ? null : onNavigate,
          icon: const Icon(Icons.navigation_outlined),
          label: const Text('Navegación'),
        ),
        if (busy) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
    return buttons;
  }
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups({required this.user, this.compact = false});

  final AppUser user;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(compact ? 8 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment:
            compact ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Text(
            'Hola, ${user.displayName}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: compact ? 8 : 8),
          Text(
            compact
                ? 'Crea un grupo o únete con un código desde el panel de la derecha.'
                : 'Crea un grupo o únete con un código. Luego podrás tener varios y elegir cuál abrir.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.membership,
    required this.enabled,
    required this.onOpen,
  });

  final GroupMembership membership;
  final bool enabled;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        enabled: enabled,
        leading: CircleAvatar(
          child: Icon(membership.isOwner ? Icons.star : Icons.two_wheeler),
        ),
        title: Text(
          membership.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          membership.isOwner
              ? 'Creador · ${membership.code}'
              : membership.code,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: enabled ? onOpen : null,
      ),
    );
  }
}
