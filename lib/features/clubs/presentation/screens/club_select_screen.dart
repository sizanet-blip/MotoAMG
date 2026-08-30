import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/auth/presentation/providers/auth_providers.dart';
import 'package:loc_motos/features/clubs/domain/entities/moto_club.dart';
import 'package:loc_motos/features/clubs/presentation/providers/club_providers.dart';

class ClubSelectScreen extends ConsumerWidget {
  const ClubSelectScreen({
    super.key,
    required this.user,
    required this.memberships,
    this.allowBack = false,
  });

  final AppUser user;
  final List<MotoClubMembership> memberships;

  /// true si se abre desde el home para cambiar de peña.
  final bool allowBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(allowBack ? 'Cambiar club' : 'Elige tu club'),
        automaticallyImplyLeading: allowBack,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            allowBack
                ? 'Elige con qué club quieres seguir ahora.'
                : 'Perteneces a varios clubs. Elige con cuál entrar.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          for (final m in memberships)
            Card(
              child: ListTile(
                title: Text(
                  m.clubName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(m.isAdmin ? 'Administrador' : 'Miembro'),
                selected: m.clubId == user.currentClubId,
                trailing: const Icon(Icons.chevron_right),
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
            ),
        ],
      ),
    );
  }
}
