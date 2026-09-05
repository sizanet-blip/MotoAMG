import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/core/widgets/app_popup_menu.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/auth/presentation/screens/profile_screen.dart';
import 'package:moto_amg/features/auth/presentation/widgets/reveal_recovery_key_dialog.dart';
import 'package:moto_amg/features/settings/presentation/screens/settings_screen.dart';

class AccountMenuButton extends ConsumerWidget {
  const AccountMenuButton({
    super.key,
    this.icon,
  });

  /// Si es null, muestra el avatar de la cuenta (comportamiento habitual).
  final IconData? icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = ref.watch(signedInUserProvider);
    final remote = ref.watch(authStateProvider).asData?.value;
    final user = resolveSessionUser(local, remote);
    final isGuest = user?.isAnonymous == true;
    final username = user?.username?.trim().isNotEmpty == true
        ? user!.username!.trim()
        : (user?.isUsernameAccount == true ? user!.displayName.trim() : '');

    return PopupMenuButton<String>(
      tooltip: 'Cuenta',
      offset: AppPopupMenus.offset,
      elevation: AppPopupMenus.elevation,
      shadowColor: AppPopupMenus.shadowColor,
      surfaceTintColor: AppPopupMenus.surfaceTintOf(context),
      color: AppPopupMenus.colorOf(context),
      shape: AppPopupMenus.shapeOf(context),
      padding: EdgeInsets.zero,
      icon: icon != null
          ? Icon(icon, color: HubStyle.title)
          : Builder(
              builder: (context) {
                final photoUrl = user?.photoUrl;
                final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
                return CircleAvatar(
                  radius: 16,
                  backgroundColor: HubStyle.accent.withValues(alpha: 0.14),
                  foregroundColor: HubStyle.accent,
                  backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                  child: hasPhoto
                      ? null
                      : Icon(
                          isGuest
                              ? Icons.person_outline_rounded
                              : Icons.person_rounded,
                          size: 18,
                        ),
                );
              },
            ),
      onSelected: (value) {
        if (value == 'logout') {
          ref.read(authActionControllerProvider.notifier).signOut();
        } else if (value == 'recovery' && username.isNotEmpty) {
          RevealRecoveryKeyDialog.show(context, username: username);
        } else if (value == 'profile' && user != null) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProfileScreen(user: user),
            ),
          );
        } else if (value == 'settings') {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SettingsScreen(),
            ),
          );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: _AccountMenuHeader(user: user, isGuest: isGuest),
        ),
        const PopupMenuDivider(height: 1),
        appPopupMenuItem(
          value: 'profile',
          icon: Icons.badge_outlined,
          label: 'Mi perfil',
          tint: HubStyle.accent,
        ),
        appPopupMenuItem(
          value: 'settings',
          icon: Icons.settings_outlined,
          label: 'Configuración',
          tint: HubStyle.accent,
        ),
        if (username.isNotEmpty)
          appPopupMenuItem(
            value: 'recovery',
            icon: Icons.key_outlined,
            label: 'Clave de recuperación',
            tint: HubStyle.accent,
          ),
        const PopupMenuDivider(height: 8),
        appPopupMenuItem(
          value: 'logout',
          icon: Icons.logout_rounded,
          label: isGuest ? 'Salir de invitado' : 'Cerrar sesión',
          destructive: true,
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
        ),
      ],
    );
  }
}

class _AccountMenuHeader extends StatelessWidget {
  const _AccountMenuHeader({
    required this.user,
    required this.isGuest,
  });

  final AppUser? user;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final name = (user?.displayName.trim().isNotEmpty == true)
        ? user!.displayName.trim()
        : (isGuest ? 'Invitado' : 'Cuenta');
    final subtitle = isGuest
        ? 'Sesión temporal'
        : (user?.email?.trim().isNotEmpty == true
            ? user!.email!.trim()
            : (user?.username?.trim().isNotEmpty == true
                ? '@${user!.username!.trim()}'
                : AppConstants.appName));
    final photoUrl = user?.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: HubStyle.accent,
          foregroundColor: Colors.white,
          backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
          child: hasPhoto
              ? null
              : Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: HubStyle.sectionTitle(color: Colors.white),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HubStyle.sectionTitle(),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HubStyle.caption(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
