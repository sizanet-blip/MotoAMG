import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/core/utils/spain_data_freshness.dart';
import 'package:moto_amg/features/intercom/presentation/screens/intercom_settings_screen.dart';
import 'package:moto_amg/features/navigation/data/datasources/spain_fuel_datasource.dart';
import 'package:moto_amg/features/navigation/data/datasources/spain_radar_datasource.dart';
import 'package:moto_amg/features/navigation/data/repositories/map_appearance_repository.dart';
import 'package:moto_amg/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:moto_amg/features/settings/presentation/screens/about_app_screen.dart';
import 'package:moto_amg/features/settings/presentation/screens/alert_preferences_screen.dart';
import 'package:moto_amg/features/settings/presentation/screens/api_usage_settings_screen.dart';
import 'package:moto_amg/features/settings/presentation/screens/app_help_screen.dart';
import 'package:moto_amg/features/settings/presentation/screens/emergency_contacts_settings_screen.dart';
import 'package:moto_amg/features/settings/presentation/screens/fuel_cache_settings_screen.dart';
import 'package:moto_amg/features/settings/presentation/screens/group_ride_settings_screen.dart';
import 'package:moto_amg/features/settings/presentation/screens/hud_safety_settings_screen.dart';
import 'package:moto_amg/features/settings/presentation/screens/map_appearance_settings_screen.dart';
import 'package:moto_amg/features/settings/presentation/screens/offline_maps_settings_screen.dart';
import 'package:moto_amg/features/settings/presentation/screens/radar_cache_settings_screen.dart';

/// Hub de configuración de la app.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(mapAppearanceProvider);
    final fuelStatus = ref.watch(spainFuelCacheStatusProvider).asData?.value;
    final radarStatus = ref.watch(spainRadarCacheStatusProvider).asData?.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(titleText: 'Configuración'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text('Apariencia', style: HubStyle.caption()),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: switch (appearance.mode) {
              MapAppearanceMode.auto => Icons.brightness_auto_rounded,
              MapAppearanceMode.day => Icons.light_mode_rounded,
              MapAppearanceMode.night => Icons.dark_mode_rounded,
            },
            title: 'Mapa día / noche',
            subtitle: '${appearance.mode.label} · ${appearance.mode.subtitle}',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MapAppearanceSettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text('Navegación y grupo', style: HubStyle.caption()),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.notifications_active_outlined,
            title: 'Avisos de navegación',
            subtitle: 'Radares, gasolineras, peajes, curvas y distancias',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AlertPreferencesScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.sports_motorsports_outlined,
            title: 'Pantalla al navegar',
            subtitle:
                'Que no se apague (grupo y ruta), más brillo y botones grandes',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HudSafetySettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.groups_outlined,
            title: 'Grupo en ruta',
            subtitle:
                'Qué motos ver, botón en navegación y avisos si alguien se queda',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GroupRideSettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.headset_mic_outlined,
            title: 'Intercom',
            subtitle:
                'Hablar y oír por defecto (el canal lo activa el creador del grupo)',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const IntercomSettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.contact_emergency_outlined,
            title: 'Contacto de emergencia',
            subtitle: 'Aviso manual por SMS o WhatsApp tras Urgente · 112',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const EmergencyContactsSettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text('Datos offline', style: HubStyle.caption()),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.map_outlined,
            title: 'Mapas offline',
            subtitle: 'Descargar regiones para navegar sin cobertura',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const OfflineMapsSettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.speed_outlined,
            title: 'Radares offline',
            subtitle: _radarCacheSubtitle(radarStatus),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RadarCacheSettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.local_gas_station_outlined,
            title: 'Gasolineras offline',
            subtitle: _fuelCacheSubtitle(fuelStatus),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FuelCacheSettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text('Ayuda y cuenta', style: HubStyle.caption()),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            title: 'Ayuda',
            subtitle: 'Guía rápida, manual completo y preguntas frecuentes',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AppHelpScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.cloud_outlined,
            title: 'Uso de APIs',
            subtitle: ref.watch(tomtomPreferencesProvider).enabled
                ? 'TomTom límites: activado · contadores de sesión'
                : 'TomTom límites: desactivado · contadores de sesión',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ApiUsageSettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Acerca de MotoAMG',
            subtitle: 'Versión, contacto y legal',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AboutAppScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static String _fuelCacheSubtitle(SpainFuelCacheStatus? status) {
    if (status == null || !status.isReady) {
      return 'Descargar precios MITECO desde el servidor MotoAMG';
    }
    final age = formatSpainDataAge(status.fetchedAt);
    final stale = isSpainFuelDataStale(status.fetchedAt);
    final prefix = stale ? 'Datos antiguos · ' : '';
    return '$prefix${status.count} estaciones · $age';
  }

  static String _radarCacheSubtitle(SpainRadarCacheStatus? status) {
    if (status == null || !status.isReady) {
      return 'Descargar inventario desde el servidor MotoAMG';
    }
    final total = status.officialCount + status.osmCount;
    final stale = isSpainRadarCacheStale(
      hasOfficial: status.hasOfficial,
      officialFetchedAt: status.officialFetchedAt,
      hasOsm: status.hasOsm,
      osmFetchedAt: status.osmFetchedAt,
    );
    final prefix = stale ? 'Datos antiguos · ' : '';
    DateTime? newest;
    for (final at in [status.officialFetchedAt, status.osmFetchedAt]) {
      if (at == null) {
        continue;
      }
      if (newest == null || at.isAfter(newest)) {
        newest = at;
      }
    }
    return '$prefix$total radares · ${formatSpainDataAge(newest)}';
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : HubStyle.cardShadow,
      ),
      child: Material(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : HubStyle.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: HubStyle.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
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
