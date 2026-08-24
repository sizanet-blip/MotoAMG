import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/auth/presentation/widgets/account_menu_button.dart';
import 'package:loc_motos/features/groups/domain/entities/group_membership.dart';
import 'package:loc_motos/features/groups/presentation/providers/group_providers.dart';
import 'package:loc_motos/features/groups/presentation/widgets/group_entry_dialogs.dart';

class MyGroupsView extends ConsumerWidget {
  const MyGroupsView({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(myGroupsProvider(user.uid));
    final busy = ref.watch(groupActionControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: const [AccountMenuButton()],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudieron cargar tus grupos.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (groups) {
          final active = groups.where((group) => group.isActive).toList();
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
                            onOpen: () => ref
                                .read(groupActionControllerProvider.notifier)
                                .openGroup(user: user, groupId: group.groupId),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: busy ? null : () => _createGroup(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Crear grupo'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => _joinGroup(context, ref),
                        icon: const Icon(Icons.vpn_key_outlined),
                        label: const Text('Unirme con un código'),
                      ),
                      if (busy) ...[
                        const SizedBox(height: 12),
                        const Center(child: CircularProgressIndicator()),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createGroup(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => CreateGroupDialog(defaultName: 'Ruta de ${user.displayName}'),
    );
    if (name == null || !context.mounted) {
      return;
    }
    await ref
        .read(groupActionControllerProvider.notifier)
        .createGroup(user: user, name: name);
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

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Hola, ${user.displayName}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Crea un grupo o únete con un código. Luego podrás tener varios y elegir cuál abrir.',
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
        title: Text(membership.name, maxLines: 1, overflow: TextOverflow.ellipsis),
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
