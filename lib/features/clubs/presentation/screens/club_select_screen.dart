import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/clubs/domain/entities/moto_club.dart';
import 'package:moto_amg/features/clubs/presentation/providers/club_providers.dart';

class ClubSelectScreen extends ConsumerWidget {
  const ClubSelectScreen({
    super.key,
    required this.user,
    required this.memberships,
    this.allowBack = false,
  });

  final AppUser user;
  final List<MotoClubMembership> memberships;

  /// true si se abre desde el home para cambiar de club.
  final bool allowBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(
        titleText: allowBack ? 'Cambiar club o grupo' : 'Elige tu club o grupo',
        automaticallyImplyLeading: allowBack,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            allowBack
                ? 'Elige con qué club o grupo quieres seguir ahora.'
                : 'Perteneces a varios. Elige con cuál entrar.',
            style: HubStyle.body(),
          ),
          const SizedBox(height: 16),
          for (final m in memberships) ...[
            _ClubSelectCard(
              name: m.clubName,
              role: m.isAdmin ? 'Administrador' : 'Miembro',
              selected: m.clubId == user.currentClubId,
              isDark: isDark,
              onTap: () async {
                await ref.read(clubRemoteDataSourceProvider).setActiveClub(
                      uid: user.uid,
                      clubId: m.clubId,
                    );
                final local = ref.read(signedInUserProvider);
                if (local != null && local.uid == user.uid) {
                  ref.read(signedInUserProvider.notifier).state =
                      local.copyWith(
                    currentClubId: m.clubId,
                    clearPendingClubRequestId: true,
                  );
                }
                if (allowBack && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ClubSelectCard extends StatelessWidget {
  const _ClubSelectCard({
    required this.name,
    required this.role,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String name;
  final String role;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : HubStyle.cardShadow,
        border: selected
            ? Border.all(color: HubStyle.accent, width: 1.6)
            : null,
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
                  decoration: BoxDecoration(
                    color: selected
                        ? HubStyle.accent
                        : HubStyle.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    color: selected ? Colors.white : HubStyle.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: HubStyle.sectionTitle()),
                      const SizedBox(height: 2),
                      Text(role, style: HubStyle.caption()),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
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
