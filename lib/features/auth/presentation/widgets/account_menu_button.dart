import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/auth/presentation/providers/auth_providers.dart';
import 'package:loc_motos/features/auth/presentation/screens/profile_screen.dart';
import 'package:loc_motos/features/auth/presentation/widgets/reveal_recovery_key_dialog.dart';

class AccountMenuButton extends ConsumerWidget {
  const AccountMenuButton({super.key});

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
      icon: const Icon(Icons.more_vert),
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
        }
      },
      itemBuilder: (context) => [
        if (isGuest)
          const PopupMenuItem(
            enabled: false,
            child: Text('Cuenta de invitado'),
          ),
        const PopupMenuItem(
          value: 'profile',
          child: Text('Mi perfil'),
        ),
        if (username.isNotEmpty)
          const PopupMenuItem(
            value: 'recovery',
            child: Text('Ver clave de recuperación'),
          ),
        PopupMenuItem(
          value: 'logout',
          child: Text(isGuest ? 'Salir de invitado' : 'Cerrar sesión'),
        ),
      ],
    );
  }
}
