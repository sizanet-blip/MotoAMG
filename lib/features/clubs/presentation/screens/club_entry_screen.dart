import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu club'),
        automaticallyImplyLeading: canDismiss,
        actions: [
          if (!canDismiss)
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () =>
                  ref.read(authActionControllerProvider.notifier).signOut(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        children: [
          Text(
            canDismiss ? 'Únete a un club' : '¿Cómo quieres entrar?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            canDismiss
                ? 'Puedes seguir usando la navegación individual. '
                    'Si te unes o registras un club, tendrás grupos de ruta.'
                : 'MotoAMG funciona por clubs. Elige una opción.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 28),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              leading: CircleAvatar(
                backgroundColor: colors.primaryContainer,
                child: Icon(Icons.link, color: colors.onPrimaryContainer),
              ),
              title: const Text(
                'Me han invitado a un club',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Usa el enlace o el código que te han pasado'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => JoinClubScreen(user: user),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              leading: CircleAvatar(
                backgroundColor: colors.secondaryContainer,
                child: Icon(Icons.groups, color: colors.onSecondaryContainer),
              ),
              title: const Text(
                'Quiero registrar mi club',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Enviaremos la solicitud; te avisaremos al aprobarla',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RegisterClubScreen(user: user),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
