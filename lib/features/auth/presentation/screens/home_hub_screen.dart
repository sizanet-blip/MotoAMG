import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/widgets/app_brand_title.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/auth/presentation/providers/home_landing_provider.dart';
import 'package:moto_amg/features/auth/presentation/widgets/account_menu_button.dart';
import 'package:moto_amg/features/navigation/presentation/screens/navigation_hub_screen.dart';
import 'package:moto_amg/features/settings/presentation/screens/settings_screen.dart';

/// Inicio estilo mockup: saludo + tres accesos principales.
class HomeHubScreen extends ConsumerWidget {
  const HomeHubScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        titleSpacing: 12,
        title: const AppBrandTitle(),
        actions: const [AccountMenuButton()],
      ),
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 160,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _HomeRoadscapePainter(
                  mountain: colors.onSurface.withValues(alpha: 0.06),
                  road: colors.onSurface.withValues(alpha: 0.10),
                  pin: colors.primary,
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              children: [
                Text(
                  'Hola',
                  style: textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '¿A dónde vamos hoy?',
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),
                _HomeHubCard(
                  icon: Icons.groups_rounded,
                  title: 'Mis grupos',
                  subtitle: 'Gestiona tus grupos y miembros de ruta',
                  onTap: () {
                    ref.read(homeLandingSectionProvider.notifier).state =
                        HomeLandingSection.groups;
                  },
                ),
                const SizedBox(height: 14),
                _HomeHubCard(
                  icon: Icons.navigation_rounded,
                  title: 'Navegación',
                  subtitle: 'Planifica y navega tus rutas',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NavigationHubScreen(user: user),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                _HomeHubCard(
                  icon: Icons.settings_rounded,
                  title: 'Configuración',
                  subtitle: 'Ajustes de la app y preferencias',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 140),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHubCard extends StatelessWidget {
  const _HomeHubCard({
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
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final cardColor = colors.brightness == Brightness.dark
        ? colors.surfaceContainerHighest
        : Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 12, 18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: colors.onPrimary, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.primary,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeRoadscapePainter extends CustomPainter {
  const _HomeRoadscapePainter({
    required this.mountain,
    required this.road,
    required this.pin,
  });

  final Color mountain;
  final Color road;
  final Color pin;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final far = Path()
      ..moveTo(0, h * 0.72)
      ..lineTo(w * 0.18, h * 0.42)
      ..lineTo(w * 0.34, h * 0.58)
      ..lineTo(w * 0.52, h * 0.28)
      ..lineTo(w * 0.68, h * 0.52)
      ..lineTo(w * 0.84, h * 0.36)
      ..lineTo(w, h * 0.55)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(far, Paint()..color = mountain);

    final near = Path()
      ..moveTo(0, h * 0.88)
      ..lineTo(w * 0.22, h * 0.62)
      ..lineTo(w * 0.40, h * 0.78)
      ..lineTo(w * 0.58, h * 0.55)
      ..lineTo(w * 0.78, h * 0.72)
      ..lineTo(w, h * 0.60)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      near,
      Paint()..color = mountain.withValues(alpha: 0.55),
    );

    final roadPath = Path()
      ..moveTo(w * 0.08, h)
      ..quadraticBezierTo(w * 0.28, h * 0.78, w * 0.42, h * 0.70)
      ..quadraticBezierTo(w * 0.58, h * 0.60, w * 0.62, h * 0.48);
    final roadPaint = Paint()
      ..color = road
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(roadPath, roadPaint);

    final pinCenter = Offset(w * 0.62, h * 0.40);
    final pinPaint = Paint()..color = pin;
    canvas.drawCircle(pinCenter, 7, pinPaint);
    final tip = Path()
      ..moveTo(pinCenter.dx - 6, pinCenter.dy + 4)
      ..lineTo(pinCenter.dx, pinCenter.dy + 16)
      ..lineTo(pinCenter.dx + 6, pinCenter.dy + 4)
      ..close();
    canvas.drawPath(tip, pinPaint);
    canvas.drawCircle(
      pinCenter,
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _HomeRoadscapePainter oldDelegate) {
    return oldDelegate.mountain != mountain ||
        oldDelegate.road != road ||
        oldDelegate.pin != pin;
  }
}
