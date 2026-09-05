import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/core/widgets/app_brand_title.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/auth/presentation/providers/home_landing_provider.dart';
import 'package:moto_amg/features/auth/presentation/screens/home_hub_screen.dart';
import 'package:moto_amg/features/auth/presentation/widgets/account_menu_button.dart';
import 'package:moto_amg/features/groups/presentation/providers/group_providers.dart';
import 'package:moto_amg/features/groups/presentation/screens/group_options_screen.dart';
import 'package:moto_amg/features/groups/presentation/screens/my_groups_view.dart';
import 'package:moto_amg/features/groups/presentation/widgets/group_entry_dialogs.dart';
import 'package:moto_amg/features/intercom/presentation/widgets/intercom_session_binder.dart';
import 'package:moto_amg/features/map/presentation/screens/group_map_screen.dart';
import 'package:moto_amg/features/navigation/presentation/screens/navigation_hub_screen.dart';
import 'package:moto_amg/features/settings/presentation/widgets/radar_update_reminder_binder.dart';
import 'package:moto_amg/features/tracking/presentation/widgets/location_binder.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localSession = ref.watch(signedInUserProvider);
    final live = ref.watch(liveUserProvider(user.uid)).asData?.value;
    var effective = live == null
        ? user
        : live.copyWith(
            displayName: live.displayName.trim().isNotEmpty
                ? live.displayName
                : user.displayName,
          );
    // Tras crear/abrir grupo, el StateProvider local puede ir por delante.
    final localGroupId = localSession?.uid == effective.uid
        ? localSession?.currentGroupId
        : null;
    if ((effective.currentGroupId == null ||
            effective.currentGroupId!.isEmpty) &&
        localGroupId != null &&
        localGroupId.isNotEmpty) {
      effective = effective.copyWith(currentGroupId: localGroupId);
    }

    ref.listen(groupActionControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        },
      );
    });

    final mapOpen = ref.watch(groupMapSessionOpenProvider);

    final Widget body;
    if (effective.isInGroup && mapOpen) {
      final groupId = effective.currentGroupId!;
      body = LocationBinder(
        user: effective,
        groupId: groupId,
        child: IntercomSessionBinder(
          groupId: groupId,
          child: _InGroupView(
            user: effective,
            groupId: groupId,
          ),
        ),
      );
    } else if (effective.isAnonymous) {
      body = _GuestJoinView(user: effective);
    } else {
      final landing = ref.watch(homeLandingSectionProvider);
      body = landing == HomeLandingSection.groups
          ? MyGroupsView(user: effective)
          : HomeHubScreen(user: effective);
    }

    return RadarUpdateReminderBinder(child: body);
  }
}

class _GuestJoinView extends ConsumerWidget {
  const _GuestJoinView({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(groupActionControllerProvider).isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Theme.of(context).colorScheme.surface : HubStyle.surface;
    final onBg = isDark
        ? Theme.of(context).colorScheme.onSurface
        : HubStyle.title;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: onBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: const AppBrandTitle(),
        actions: const [
          AccountMenuButton(),
          SizedBox(width: 8),
        ],
        iconTheme: IconThemeData(color: onBg),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Hola, ${user.displayName}',
                      style: HubStyle.headline(),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        avatar: Icon(
                          Icons.badge_outlined,
                          size: 18,
                          color: HubStyle.accent,
                        ),
                        label: Text(
                          'Cuenta de invitado',
                          style: HubStyle.caption(color: HubStyle.title),
                        ),
                        backgroundColor: HubStyle.accent.withValues(alpha: 0.12),
                        side: BorderSide.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pide el código al que organiza la ruta. Al cerrar sesión se '
                      'borra todo y no se puede recuperar. Si quieres guardar grupos, '
                      'crea una cuenta con usuario o con correo.',
                      style: HubStyle.body(),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      style: HubStyle.filledButtonStyle(enabled: !busy),
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
          },
        ),
      ),
    );
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

    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final canPrepareRoute = groupAsync.valueOrNull?.isAdmin(user.uid) ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Theme.of(context).colorScheme.surface : HubStyle.surface;
    final onBg = isDark
        ? Theme.of(context).colorScheme.onSurface
        : HubStyle.title;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: onBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: landscape ? 44 : kToolbarHeight,
        iconTheme: IconThemeData(color: onBg),
        leading: user.isAnonymous
            ? null
            : IconButton(
                tooltip: 'Mis grupos',
                onPressed: busy
                    ? null
                    : () {
                        ref.read(homeLandingSectionProvider.notifier).state =
                            HomeLandingSection.groups;
                        ref
                            .read(groupActionControllerProvider.notifier)
                            .closeMap(user: user);
                      },
                icon: const Icon(Icons.arrow_back),
              ),
        title: landscape
            ? Text(
                memberCount > 0
                    ? '${groupName ?? AppConstants.appName} · $memberCount'
                    : (groupName ?? AppConstants.appName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HubStyle.pageTitle(color: onBg),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupName ?? AppConstants.appName,
                    style: HubStyle.pageTitle(color: onBg),
                  ),
                  if (memberCount > 0)
                    Text(
                      memberCount == 1 ? '1 motero' : '$memberCount moteros',
                      style: HubStyle.caption(),
                    ),
                ],
              ),
        actions: [
          if (canPrepareRoute)
            TextButton.icon(
              style: HubStyle.textButtonStyle(),
              onPressed: busy
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => NavigationHubScreen(
                            user: user.copyWith(currentGroupId: groupId),
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.route_outlined),
              label: const Text('Ruta'),
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
              backgroundColor: HubStyle.accent,
              label: Text('$memberCount'),
              child: Icon(Icons.groups_outlined, color: onBg),
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
            style: HubStyle.sectionTitle(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Prueba otra vez. Si sigue igual, continúa sin grupo y únete con el código.',
            style: HubStyle.body(),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          FilledButton(
            style: HubStyle.filledButtonStyle(),
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: HubStyle.outlinedButtonStyle(),
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
          Text('Este grupo ya está cerrado.', style: HubStyle.body()),
          const Spacer(),
          FilledButton(
            style: HubStyle.filledButtonStyle(),
            onPressed: onLeave,
            child: const Text('Volver'),
          ),
        ],
      ),
    );
  }
}
