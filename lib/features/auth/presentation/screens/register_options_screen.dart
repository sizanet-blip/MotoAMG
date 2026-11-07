import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/auth/presentation/screens/register_screen.dart';
import 'package:moto_amg/features/auth/presentation/screens/username_register_screen.dart';

class RegisterOptionsScreen extends ConsumerWidget {
  const RegisterOptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authActionControllerProvider).isLoading;

    ref.listen(authActionControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        },
        data: (_) {
          if (previous?.isLoading == true && !next.hasError) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
      );
    });

    return Scaffold(
      backgroundColor: HubStyle.surface,
      appBar: HubStyle.appBar(titleText: 'Crear cuenta'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Text(
              'Solicita acceso con usuario y contraseña. Un administrador '
              'deberá aprobar tu cuenta en el panel antes de poder entrar. '
              'Guarda el código de recuperación que te mostraremos.',
              style: HubStyle.body(),
            ),
            const SizedBox(height: 20),
            _RegisterOptionCard(
              icon: Icons.person_outline_rounded,
              title: 'Usuario y contraseña',
              subtitle: 'Cuenta AMG unificada (pendiente de aprobación).',
              onTap: isLoading
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const UsernameRegisterScreen(),
                        ),
                      );
                    },
            ),
            const SizedBox(height: 12),
            _RegisterOptionCard(
              icon: Icons.mail_outline_rounded,
              title: 'Con correo',
              subtitle: 'Usuario + email opcional + contraseña.',
              onTap: isLoading
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
            ),
            if (isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

class _RegisterOptionCard extends StatelessWidget {
  const _RegisterOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HubStyle.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: HubStyle.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: HubStyle.sectionTitle()),
                    const SizedBox(height: 4),
                    Text(subtitle, style: HubStyle.caption()),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
