import 'package:flutter/material.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/auth/presentation/screens/register_screen.dart';
import 'package:moto_amg/features/auth/presentation/screens/username_register_screen.dart';

class RegisterOptionsScreen extends StatelessWidget {
  const RegisterOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubStyle.surface,
      appBar: HubStyle.appBar(titleText: 'Crear cuenta'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Text(
              'Con una cuenta puedes volver a tus grupos desde este u otro móvil.',
              style: HubStyle.body(),
            ),
            const SizedBox(height: 20),
            _RegisterOptionCard(
              icon: Icons.mail_outline_rounded,
              title: 'Con correo',
              subtitle: 'Podrás recuperar la contraseña por email.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RegisterScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _RegisterOptionCard(
              icon: Icons.person_outline_rounded,
              title: 'Con usuario y contraseña',
              subtitle:
                  'Sin correo. Te daremos una clave de recuperación; guárdala bien.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const UsernameRegisterScreen(),
                  ),
                );
              },
            ),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: HubStyle.cardShadow,
      ),
      child: Material(
        color: HubStyle.surface,
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
                      Text(title, style: HubStyle.sectionTitle()),
                      const SizedBox(height: 2),
                      Text(subtitle, style: HubStyle.caption()),
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
