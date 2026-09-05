import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/core/widgets/app_brand_title.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/auth/presentation/providers/home_landing_provider.dart';
import 'package:moto_amg/features/auth/presentation/widgets/account_menu_button.dart';
import 'package:moto_amg/features/navigation/presentation/screens/navigation_hub_screen.dart';
import 'package:moto_amg/features/settings/presentation/screens/settings_screen.dart';

/// Inicio: cards principales + menú de cuenta (sin drawer duplicado).
class HomeHubScreen extends ConsumerWidget {
  const HomeHubScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Theme.of(context).colorScheme.surface : HubStyle.surface;
    final onBg = isDark
        ? Theme.of(context).colorScheme.onSurface
        : HubStyle.title;
    final muted = isDark
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : HubStyle.subtitle;
    final screenH = MediaQuery.sizeOf(context).height;
    final landscapeH = (screenH * 0.32).clamp(190.0, 280.0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: onBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 12,
        automaticallyImplyLeading: false,
        title: const AppBrandTitle(),
        actions: const [
          AccountMenuButton(),
          SizedBox(width: 8),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: landscapeH,
            child: IgnorePointer(
              child: Image.asset(
                AppConstants.homeLandscapeAsset,
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: landscapeH - 56,
            height: 72,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      bg,
                      bg.withValues(alpha: 0.85),
                      bg.withValues(alpha: 0.35),
                      bg.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.35, 0.7, 1],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, 8, 22, landscapeH * 0.55),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Hola',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      height: 1.05,
                      color: onBg,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '¿A dónde vamos hoy?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _HomeHubCard(
                    icon: Icons.groups_rounded,
                    title: 'Mis grupos',
                    subtitle: 'Gestiona tus grupos y miembros de ruta',
                    isDark: isDark,
                    onTap: () {
                      ref.read(homeLandingSectionProvider.notifier).state =
                          HomeLandingSection.groups;
                    },
                  ),
                  const SizedBox(height: 14),
                  _HomeHubCard(
                    icon: Icons.near_me_rounded,
                    title: 'Navegación',
                    subtitle: 'Planifica y navega tus rutas',
                    isDark: isDark,
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
                    isDark: isDark,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
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
    final titleColor = isDark
        ? Theme.of(context).colorScheme.onSurface
        : const Color(0xFF111827);
    final subtitleColor = isDark
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : const Color(0xFF4B5563);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
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
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                          letterSpacing: -0.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                          color: subtitleColor,
                        ),
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
