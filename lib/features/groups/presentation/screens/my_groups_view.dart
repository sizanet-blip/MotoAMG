import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/auth/presentation/providers/home_landing_provider.dart';
import 'package:moto_amg/features/auth/presentation/widgets/account_menu_button.dart';
import 'package:moto_amg/features/clubs/domain/entities/moto_club.dart';
import 'package:moto_amg/features/clubs/presentation/providers/club_providers.dart';
import 'package:moto_amg/features/clubs/presentation/screens/club_entry_screen.dart';
import 'package:moto_amg/features/groups/domain/entities/group_membership.dart';
import 'package:moto_amg/features/groups/presentation/providers/group_providers.dart';
import 'package:moto_amg/features/groups/presentation/widgets/group_entry_dialogs.dart';
import 'package:moto_amg/features/navigation/presentation/screens/navigation_hub_screen.dart';

class MyGroupsView extends ConsumerWidget {
  const MyGroupsView({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(myGroupsProvider(user.uid));
    final membershipsAsync = ref.watch(myClubMembershipsProvider);
    final busy = ref.watch(groupActionControllerProvider).isLoading;
    final landscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final clubMemberships =
        membershipsAsync.asData?.value ?? const <MotoClubMembership>[];
    final activeClubName = _activeClubName(user, clubMemberships);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        ref.read(homeLandingSectionProvider.notifier).state =
            HomeLandingSection.hub;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? null
            : HubStyle.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? null
              : HubStyle.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            tooltip: 'Inicio',
            onPressed: () {
              ref.read(homeLandingSectionProvider.notifier).state =
                  HomeLandingSection.hub;
            },
            icon: const Icon(Icons.arrow_back_rounded, color: HubStyle.title),
          ),
          title: Row(
            children: [
              Text('Mis grupos', style: HubStyle.pageTitle()),
              if (activeClubName != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    activeClubName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: HubStyle.caption(),
                  ),
                ),
              ],
            ],
          ),
          actions: const [
            AccountMenuButton(),
            SizedBox(width: 8),
          ],
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
          final clubId = user.currentClubId;
          final membershipsReady = membershipsAsync.hasValue;
          // currentClubId huérfano (sin membresía en Firestore) ≠ estar en club.
          final membershipOk = clubId != null &&
              clubId.isNotEmpty &&
              (!membershipsReady ||
                  clubMemberships.any((m) => m.clubId == clubId));
          final inClub = user.isAnonymous || (user.isInClub && membershipOk);
          final active = inClub
              ? groups.where((group) {
                  if (!group.isActive) {
                    return false;
                  }
                  if (user.isAnonymous) {
                    return true;
                  }
                  if (clubId == null || clubId.isEmpty) {
                    return false;
                  }
                  return group.clubId == clubId;
                }).toList()
              : const <GroupMembership>[];
          final showClubCta =
              user.allowSoloNavigation && !inClub && !user.isAnonymous;
          void openClubEntry() {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ClubEntryScreen(
                  user: user,
                  canDismiss: true,
                ),
              ),
            );
          }

          Future<void> selectClub(MotoClubMembership club) async {
            if (club.clubId == user.currentClubId) {
              return;
            }
            await ref.read(clubRemoteDataSourceProvider).setActiveClub(
                  uid: user.uid,
                  clubId: club.clubId,
                );
            final local = ref.read(signedInUserProvider);
            if (local != null && local.uid == user.uid) {
              ref.read(signedInUserProvider.notifier).state = local.copyWith(
                currentClubId: club.clubId,
                clearPendingClubRequestId: true,
              );
            }
            ref.read(groupMapSessionOpenProvider.notifier).state = false;
          }

          if (landscape) {
            return _LandscapeBody(
              user: user,
              active: active,
              busy: busy,
              showClubCta: showClubCta,
              hideGroupActions: !inClub,
              clubMemberships: clubMemberships,
              onSelectClub: selectClub,
              onCreate: () => _createGroup(context, ref),
              onJoin: () => _joinGroup(context, ref),
              onOpen: (groupId) => ref
                  .read(groupActionControllerProvider.notifier)
                  .openGroup(user: user, groupId: groupId),
              onDismissGroup: (membership) =>
                  _dismissGroup(context, ref, membership),
              onNavigate: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NavigationHubScreen(user: user),
                  ),
                );
              },
              onClubEntry: openClubEntry,
            );
          }
          return _PortraitBody(
            user: user,
            active: active,
            busy: busy,
            showClubCta: showClubCta,
            hideGroupActions: !inClub,
            clubMemberships: clubMemberships,
            onSelectClub: selectClub,
            onCreate: () => _createGroup(context, ref),
            onJoin: () => _joinGroup(context, ref),
            onOpen: (groupId) => ref
                .read(groupActionControllerProvider.notifier)
                .openGroup(user: user, groupId: groupId),
            onDismissGroup: (membership) =>
                _dismissGroup(context, ref, membership),
            onNavigate: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NavigationHubScreen(user: user),
                ),
              );
            },
            onClubEntry: openClubEntry,
          );
        },
      ),
    ),
    );
  }

  String? _activeClubName(AppUser user, List<MotoClubMembership> memberships) {
    final id = user.currentClubId;
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final m in memberships) {
      if (m.clubId == id) {
        return m.clubName;
      }
    }
    return null;
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

  Future<bool> _dismissGroup(
    BuildContext context,
    WidgetRef ref,
    GroupMembership membership,
  ) async {
    final isOwner = membership.isOwner;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HubStyle.surface,
        title: Text(
          isOwner ? '¿Eliminar el grupo?' : '¿Salir del grupo?',
          style: HubStyle.sectionTitle(),
        ),
        content: Text(
          isOwner
              ? 'Se borrará «${membership.name}» (${membership.code}) para todos.'
              : 'Dejarás de ver «${membership.name}» en este club o grupo.',
          style: HubStyle.body(),
        ),
        actions: [
          TextButton(
            style: HubStyle.textButtonStyle(),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: isOwner
                ? HubStyle.filledButtonStyle().copyWith(
                    backgroundColor: WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.error,
                    ),
                    foregroundColor: WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.onError,
                    ),
                  )
                : HubStyle.filledButtonStyle(),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isOwner ? 'Eliminar' : 'Salir'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      return false;
    }
    try {
      if (isOwner) {
        await ref.read(groupActionControllerProvider.notifier).deleteGroup(
              user: user,
              groupId: membership.groupId,
            );
      } else {
        await ref.read(groupActionControllerProvider.notifier).leaveGroup(
              user: user,
              groupId: membership.groupId,
            );
      }
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isOwner
                  ? 'No se pudo eliminar el grupo.'
                  : 'No se pudo salir del grupo.',
            ),
          ),
        );
      }
      return false;
    }
  }
}

class _PortraitBody extends StatelessWidget {
  const _PortraitBody({
    required this.user,
    required this.active,
    required this.busy,
    required this.showClubCta,
    required this.hideGroupActions,
    required this.clubMemberships,
    required this.onSelectClub,
    required this.onCreate,
    required this.onJoin,
    required this.onOpen,
    required this.onDismissGroup,
    required this.onNavigate,
    required this.onClubEntry,
  });

  final AppUser user;
  final List<GroupMembership> active;
  final bool busy;
  final bool showClubCta;
  final bool hideGroupActions;
  final List<MotoClubMembership> clubMemberships;
  final ValueChanged<MotoClubMembership> onSelectClub;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final ValueChanged<String> onOpen;
  final Future<bool> Function(GroupMembership membership) onDismissGroup;
  final VoidCallback onNavigate;
  final VoidCallback onClubEntry;

  @override
  Widget build(BuildContext context) {
    final showClubSwitcher = clubMemberships.length > 1;
    return Column(
      children: [
        Expanded(
          child: hideGroupActions
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    if (showClubCta) _ClubInviteBanner(onTap: onClubEntry),
                    const SizedBox(height: 24),
                    Text(
                      'Hola, ${user.displayName}',
                      style: HubStyle.headline(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Únete a un club o grupo para crear o unirte a salidas. '
                      'Mientras, puedes usar la navegación individual.',
                      style: HubStyle.body(),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  children: [
                    if (showClubSwitcher) ...[
                      _ClubSwitcher(
                        clubs: clubMemberships,
                        activeClubId: user.currentClubId,
                        onSelect: onSelectClub,
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (showClubCta) ...[
                      _ClubInviteBanner(onTap: onClubEntry),
                      const SizedBox(height: 12),
                    ],
                    if (active.isEmpty)
                      _EmptyGroups(user: user)
                    else ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, top: 4),
                        child: Text(
                          'Elige el grupo de esta ruta. Puedes crear o unirte a más.',
                          style: HubStyle.body(),
                        ),
                      ),
                      for (final group in active) ...[
                        _GroupTile(
                          membership: group,
                          enabled: !busy,
                          onOpen: () => onOpen(group.groupId),
                          onDismiss: () => onDismissGroup(group),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ],
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: _ActionButtons(
              busy: busy,
              stretch: true,
              showSoloNavigation: user.allowSoloNavigation,
              showGroupActions: !hideGroupActions,
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
    required this.showClubCta,
    required this.hideGroupActions,
    required this.clubMemberships,
    required this.onSelectClub,
    required this.onCreate,
    required this.onJoin,
    required this.onOpen,
    required this.onDismissGroup,
    required this.onNavigate,
    required this.onClubEntry,
  });

  final AppUser user;
  final List<GroupMembership> active;
  final bool busy;
  final bool showClubCta;
  final bool hideGroupActions;
  final List<MotoClubMembership> clubMemberships;
  final ValueChanged<MotoClubMembership> onSelectClub;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final ValueChanged<String> onOpen;
  final Future<bool> Function(GroupMembership membership) onDismissGroup;
  final VoidCallback onNavigate;
  final VoidCallback onClubEntry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final showClubSwitcher = clubMemberships.length > 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: hideGroupActions
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showClubCta) ...[
                                _ClubInviteBanner(onTap: onClubEntry),
                                const SizedBox(height: 16),
                              ],
                              Text(
                                'Hola, ${user.displayName}',
                                style: HubStyle.headline(),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Únete a un club o grupo para usar salidas compartidas.',
                                style: HubStyle.body(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        if (showClubSwitcher)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ClubSwitcher(
                                clubs: clubMemberships,
                                activeClubId: user.currentClubId,
                                onSelect: onSelectClub,
                              ),
                            ),
                          ),
                        if (showClubCta)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ClubInviteBanner(onTap: onClubEntry),
                            ),
                          ),
                        if (active.isEmpty)
                          SliverToBoxAdapter(
                            child: _EmptyGroups(user: user, compact: true),
                          )
                        else ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tus grupos',
                                    style: HubStyle.sectionTitle(),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Elige el grupo de esta ruta.',
                                    style: HubStyle.body(),
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
                                onDismiss: () => onDismissGroup(group),
                              );
                            },
                          ),
                        ],
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
                            style: HubStyle.sectionTitle(),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hideGroupActions
                                ? 'Navegación individual o únete a un club o grupo.'
                                : (user.allowSoloNavigation
                                    ? 'Crear, unirte o ir a navegar.'
                                    : 'Crear grupo o unirte con un código.'),
                            style: HubStyle.caption(),
                          ),
                          const SizedBox(height: 16),
                          _ActionButtons(
                            busy: busy,
                            stretch: true,
                            showSoloNavigation: user.allowSoloNavigation,
                            showGroupActions: !hideGroupActions,
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

class _ClubSwitcher extends StatelessWidget {
  const _ClubSwitcher({
    required this.clubs,
    required this.activeClubId,
    required this.onSelect,
  });

  final List<MotoClubMembership> clubs;
  final String? activeClubId;
  final ValueChanged<MotoClubMembership> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = clubs.length == 1 ? 'Tu club o grupo' : 'Tus clubs o grupos';
    MotoClubMembership? selected;
    for (final club in clubs) {
      if (club.clubId == activeClubId) {
        selected = club;
        break;
      }
    }
    selected ??= clubs.isEmpty ? null : clubs.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: HubStyle.caption(),
        ),
        const SizedBox(height: 6),
        DropdownMenu<String>(
          key: ValueKey(selected?.clubId ?? 'none'),
          initialSelection: selected?.clubId,
          expandedInsets: EdgeInsets.zero,
          requestFocusOnTap: false,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.45),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: HubStyle.accent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
          trailingIcon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: colors.onSurfaceVariant,
          ),
          selectedTrailingIcon: Icon(
            Icons.keyboard_arrow_up_rounded,
            color: colors.onSurfaceVariant,
          ),
          textStyle: HubStyle.sectionTitle(),
          dropdownMenuEntries: [
            for (final club in clubs)
              DropdownMenuEntry<String>(
                value: club.clubId,
                label: club.clubName,
                labelWidget: Text(
                  club.clubName,
                  style: TextStyle(
                    fontWeight: club.clubId == activeClubId
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
          onSelected: (id) {
            if (id == null) {
              return;
            }
            for (final club in clubs) {
              if (club.clubId == id) {
                onSelect(club);
                return;
              }
            }
          },
        ),
      ],
    );
  }
}

class _ClubInviteBanner extends StatelessWidget {
  const _ClubInviteBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : HubStyle.cardShadow,
      ),
      child: Material(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : HubStyle.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: HubStyle.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Únete a un club o grupo, o registra el tuyo',
                    style: HubStyle.sectionTitle(),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: HubStyle.accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.busy,
    required this.stretch,
    required this.showSoloNavigation,
    required this.showGroupActions,
    required this.onCreate,
    required this.onJoin,
    required this.onNavigate,
  });

  final bool busy;
  final bool stretch;
  final bool showSoloNavigation;
  final bool showGroupActions;
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
        if (showGroupActions) ...[
          FilledButton.icon(
            onPressed: busy ? null : onCreate,
            style: HubStyle.filledButtonStyle(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear grupo'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : onJoin,
            style: HubStyle.outlinedButtonStyle(),
            icon: const Icon(Icons.vpn_key_outlined),
            label: const Text('Unirme con un código'),
          ),
        ],
        if (showSoloNavigation) ...[
          if (showGroupActions) const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : onNavigate,
            style: HubStyle.outlinedButtonStyle(),
            icon: const Icon(Icons.near_me_rounded),
            label: const Text('Navegación'),
          ),
        ],
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
      padding: EdgeInsets.all(compact ? 8 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment:
            compact ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Text(
            'Hola, ${user.displayName}',
            style: HubStyle.headline(),
          ),
          const SizedBox(height: 8),
          Text(
            compact
                ? 'Crea un grupo o únete con un código desde el panel de la derecha.'
                : 'Crea un grupo o únete con un código. Luego podrás tener varios y elegir cuál abrir.',
            style: HubStyle.body(),
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
    required this.onDismiss,
  });

  final GroupMembership membership;
  final bool enabled;
  final VoidCallback onOpen;
  final Future<bool> Function() onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dismissible(
      key: ValueKey(membership.groupId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              membership.isOwner ? 'Eliminar' : 'Salir',
              style: HubStyle.sectionTitle(color: colors.onErrorContainer),
            ),
            const SizedBox(width: 8),
            Icon(
              membership.isOwner ? Icons.delete_outline : Icons.logout,
              color: colors.onErrorContainer,
            ),
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? null : HubStyle.cardShadow,
        ),
        child: Material(
          color: isDark ? colors.surfaceContainerHighest : HubStyle.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onOpen : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: enabled
                          ? HubStyle.accent
                          : HubStyle.accent.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      membership.isOwner
                          ? Icons.star_rounded
                          : Icons.two_wheeler_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          membership.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HubStyle.sectionTitle(
                            color: enabled
                                ? (isDark ? colors.onSurface : HubStyle.title)
                                : HubStyle.subtitle,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          membership.isOwner
                              ? 'Creador · ${membership.code}'
                              : membership.code,
                          style: HubStyle.caption(),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: enabled
                        ? HubStyle.accent
                        : HubStyle.accent.withValues(alpha: 0.4),
                    size: 26,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
