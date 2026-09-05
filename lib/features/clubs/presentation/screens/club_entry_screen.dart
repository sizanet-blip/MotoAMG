import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/clubs/presentation/screens/join_club_screen.dart';
import 'package:moto_amg/features/clubs/presentation/screens/register_club_screen.dart';

/// Puerta de entrada: invitación o registrar peña.
class ClubEntryScreen extends ConsumerWidget {
  const ClubEntryScreen({
    super.key,
    required this.user,
    this.canDismiss = false,
  });

  final AppUser user;

  /// true si se abre desde el home (navegación individual sin peña).
  final bool canDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(
        titleText: 'Clubes o peña',
        automaticallyImplyLeading: canDismiss,
        actions: [
          if (!canDismiss)
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () =>
                  ref.read(authActionControllerProvider.notifier).signOut(),
              icon: const Icon(Icons.logout_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Text(
            canDismiss ? 'Únete a la comunidad' : '¿Cómo quieres entrar?',
            style: HubStyle.headline(),
          ),
          const SizedBox(height: 8),
          Text(
            canDismiss
                ? 'Puedes seguir usando la navegación individual. '
                    'Si te unes o registras una peña, tendrás grupos de ruta.'
                : 'Puedes unirte a una peña existente con un código de '
                    'invitación o solicitar la creación de una nueva peña.',
            style: HubStyle.body(),
          ),
          const SizedBox(height: 28),
          _ClubOptionCard(
            icon: Icons.confirmation_number_outlined,
            title: 'Unirme con código de invitación',
            subtitle:
                'Introduce el código de invitación para unirte a una peña existente.',
            isDark: isDark,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => JoinClubScreen(user: user),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _ClubOptionCard(
            icon: Icons.groups_rounded,
            title: 'Solicitar alta de peña',
            subtitle:
                'Solicita la creación de una nueva peña y empieza a organizar rodadas.',
            isDark: isDark,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RegisterClubScreen(user: user),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClubOptionCard extends StatelessWidget {
  const _ClubOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.white;
    final titleColor =
        isDark ? Theme.of(context).colorScheme.onSurface : HubStyle.title;
    final subtitleColor = isDark
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : HubStyle.subtitle;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : HubStyle.cardShadow,
      ),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 8, 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: HubStyle.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: HubStyle.sectionTitle(color: titleColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: HubStyle.caption(color: subtitleColor),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: HubStyle.accent,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
