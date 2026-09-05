import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/constants/navigation_constants.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/navigation/domain/entities/alert_preferences.dart';
import 'package:moto_amg/features/navigation/presentation/providers/navigation_providers.dart';

/// Hub de avisos en ruta: activar/desactivar y entrar al detalle de cada tipo.
class AlertPreferencesScreen extends ConsumerWidget {
  const AlertPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(alertPreferencesProvider);
    final notifier = ref.read(alertPreferencesProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(
        titleText: 'Avisos de navegación',
        actions: [
          TextButton(
            style: HubStyle.textButtonStyle(),
            onPressed: () async {
              await notifier.reset();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Valores restablecidos')),
                );
              }
            },
            child: const Text('Restablecer'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'Activa lo que necesites y entra en cada tipo para afinar mapa, voz y distancias.',
            style: HubStyle.body(),
          ),
          const SizedBox(height: 12),
          _AlertTypeHubTile(
            icon: Icons.speed_outlined,
            title: 'Radares',
            summary: _radarSummary(prefs),
            enabled: prefs.radarsEnabled,
            isDark: isDark,
            onEnabledChanged: (v) =>
                notifier.update((p) => p.copyWith(radarsEnabled: v)),
            onOpenDetail: () => _openDetail(context, _AlertCategory.radars),
          ),
          const SizedBox(height: 10),
          _AlertTypeHubTile(
            icon: Icons.local_gas_station_outlined,
            title: 'Gasolineras',
            summary: _fuelSummary(prefs),
            enabled: prefs.fuelEnabled,
            isDark: isDark,
            onEnabledChanged: (v) =>
                notifier.update((p) => p.copyWith(fuelEnabled: v)),
            onOpenDetail: () => _openDetail(context, _AlertCategory.fuel),
          ),
          const SizedBox(height: 10),
          _AlertTypeHubTile(
            icon: Icons.toll_outlined,
            title: 'Peajes',
            summary: _tollSummary(prefs),
            enabled: prefs.tollsEnabled,
            isDark: isDark,
            onEnabledChanged: (v) =>
                notifier.update((p) => p.copyWith(tollsEnabled: v)),
            onOpenDetail: () => _openDetail(context, _AlertCategory.tolls),
          ),
          const SizedBox(height: 10),
          _AlertTypeHubTile(
            icon: Icons.turn_sharp_right,
            title: 'Curvas pronunciadas',
            summary: _curveSummary(prefs),
            enabled: prefs.curvesEnabled,
            isDark: isDark,
            onEnabledChanged: (v) =>
                notifier.update((p) => p.copyWith(curvesEnabled: v)),
            onOpenDetail: () => _openDetail(context, _AlertCategory.curves),
          ),
          const SizedBox(height: 10),
          _AlertTypeHubTile(
            icon: Icons.speed,
            title: 'Límite de velocidad',
            summary: _speedLimitSummary(prefs),
            enabled: prefs.speedLimitAlertEnabled,
            isDark: isDark,
            onEnabledChanged: (v) =>
                notifier.update((p) => p.copyWith(speedLimitAlertEnabled: v)),
            onOpenDetail: () =>
                _openDetail(context, _AlertCategory.speedLimit),
          ),
          const SizedBox(height: 10),
          _AlertTypeHubTile(
            icon: Icons.traffic_outlined,
            title: 'Señales de tráfico',
            summary: _trafficSignsSummary(prefs),
            enabled: prefs.trafficSignsEnabled,
            isDark: isDark,
            onEnabledChanged: (v) =>
                notifier.update((p) => p.copyWith(trafficSignsEnabled: v)),
            onOpenDetail: () =>
                _openDetail(context, _AlertCategory.trafficSigns),
          ),
          const SizedBox(height: 20),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? null : HubStyle.cardShadow,
            ),
            child: Material(
              color: isDark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: HubStyle.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Los avisos aparecen en el mapa y en la pantalla al navegar. '
                        'La voz es opcional para cada tipo.',
                        style: HubStyle.caption(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _openDetail(BuildContext context, _AlertCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AlertTypeDetailScreen(category: category),
      ),
    );
  }
}

enum _AlertCategory { radars, fuel, tolls, curves, speedLimit, trafficSigns }

class _AlertTypeDetailScreen extends ConsumerWidget {
  const _AlertTypeDetailScreen({required this.category});

  final _AlertCategory category;

  String get _title => switch (category) {
        _AlertCategory.radars => 'Radares',
        _AlertCategory.fuel => 'Gasolineras',
        _AlertCategory.tolls => 'Peajes',
        _AlertCategory.curves => 'Curvas',
        _AlertCategory.speedLimit => 'Límite de velocidad',
        _AlertCategory.trafficSigns => 'Señales de tráfico',
      };

  String get _mainSwitchTitle => switch (category) {
        _AlertCategory.radars => 'Avisos de radar',
        _AlertCategory.fuel => 'Avisos de gasolinera',
        _AlertCategory.tolls => 'Avisos de peaje',
        _AlertCategory.curves => 'Detectar curvas',
        _AlertCategory.speedLimit => 'Avisarme si me paso',
        _AlertCategory.trafficSigns => 'Mostrar señales en el mapa',
      };

  bool _isEnabled(AlertPreferences prefs) => switch (category) {
        _AlertCategory.radars => prefs.radarsEnabled,
        _AlertCategory.fuel => prefs.fuelEnabled,
        _AlertCategory.tolls => prefs.tollsEnabled,
        _AlertCategory.curves => prefs.curvesEnabled,
        _AlertCategory.speedLimit => prefs.speedLimitAlertEnabled,
        _AlertCategory.trafficSigns => prefs.trafficSignsEnabled,
      };

  AlertPreferences _setEnabled(AlertPreferences prefs, bool value) =>
      switch (category) {
        _AlertCategory.radars => prefs.copyWith(radarsEnabled: value),
        _AlertCategory.fuel => prefs.copyWith(fuelEnabled: value),
        _AlertCategory.tolls => prefs.copyWith(tollsEnabled: value),
        _AlertCategory.curves => prefs.copyWith(curvesEnabled: value),
        _AlertCategory.speedLimit =>
          prefs.copyWith(speedLimitAlertEnabled: value),
        _AlertCategory.trafficSigns =>
          prefs.copyWith(trafficSignsEnabled: value),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(alertPreferencesProvider);
    final notifier = ref.read(alertPreferencesProvider.notifier);
    final enabled = _isEnabled(prefs);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(titleText: _title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        children: [
          SwitchListTile(
            title: Text(_mainSwitchTitle),
            subtitle: Text(
              category == _AlertCategory.speedLimit
                  ? (enabled
                      ? 'Marca en rojo la velocidad cuando te pases'
                      : 'Sin aviso visual ni sonido por exceso')
                  : category == _AlertCategory.trafficSigns
                      ? (enabled
                          ? 'Elige abajo qué señales pintar en el mapa'
                          : 'Semáforos, STOP y ceda ocultos')
                      : (enabled
                          ? 'Configura abajo cómo quieres verlo y oírlo'
                          : 'Actívalo para ajustar las opciones'),
            ),
            value: enabled,
            onChanged: (v) => notifier.update((p) => _setEnabled(p, v)),
            activeThumbColor: HubStyle.accent,
            activeTrackColor: HubStyle.accent.withValues(alpha: 0.45),
          ),
          if (!enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Este tipo de aviso está desactivado. Puedes volver atrás o '
                'activarlo con el interruptor de arriba.',
                style: HubStyle.caption(),
              ),
            )
          else if (category == _AlertCategory.speedLimit) ...[
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Margen sobre el límite',
                style: HubStyle.sectionTitle(color: HubStyle.accent),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Avisa cuando vayas más rápido que el límite + este margen. '
                'Con 0 km/h avisa en cuanto lo superas.',
                style: HubStyle.caption(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final km in AlertPreferences.speedLimitToleranceOptions)
                    ChoiceChip(
                      label: Text(
                        km == 0 ? 'Al pasarlo' : '+$km km/h',
                      ),
                      selected: prefs.speedLimitToleranceKmh == km,
                      onSelected: (_) => notifier.update(
                        (p) => p.copyWith(speedLimitToleranceKmh: km),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 28),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_outlined),
              title: const Text('Sonido al pasarme'),
              subtitle: const Text(
                'Aviso corto (“Límite”) la primera vez. Se calla si sigues '
                'pasado; vuelve a sonar si bajas al límite y te pasas otra vez',
              ),
              value: prefs.speedLimitSoundEnabled,
              onChanged: (v) => notifier.update(
                (p) => p.copyWith(speedLimitSoundEnabled: v),
              ),
              activeThumbColor: HubStyle.accent,
              activeTrackColor: HubStyle.accent.withValues(alpha: 0.45),
            ),
          ] else if (category == _AlertCategory.trafficSigns) ...[
            const Divider(height: 24),
            _SettingsSection(
              title: 'En el mapa',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'Solo iconos en el mapa durante la navegación. '
                    'Sin voz ni panel de distancia.',
                    style: HubStyle.caption(),
                  ),
                ),
                _CompactSwitchTile(
                  title: 'Semáforos',
                  subtitle: 'Icono de semáforo',
                  value: prefs.trafficSignalShowOnMap,
                  onChanged: (v) => notifier.update(
                    (p) => p.copyWith(trafficSignalShowOnMap: v),
                  ),
                ),
                _CompactSwitchTile(
                  title: 'STOP',
                  subtitle: 'Señal de stop',
                  value: prefs.stopShowOnMap,
                  onChanged: (v) =>
                      notifier.update((p) => p.copyWith(stopShowOnMap: v)),
                ),
                _CompactSwitchTile(
                  title: 'Ceda el paso',
                  subtitle: 'Triángulo invertido',
                  value: prefs.giveWayShowOnMap,
                  onChanged: (v) =>
                      notifier.update((p) => p.copyWith(giveWayShowOnMap: v)),
                ),
              ],
            ),
          ] else ...[
            const Divider(height: 24),
            _SettingsSection(
              title: 'En pantalla',
              children: _screenSection(context, ref, prefs, notifier),
            ),
            _SettingsSection(
              title: 'Voz',
              children: _voiceSection(context, ref, prefs, notifier),
            ),
            if (category == _AlertCategory.radars ||
                category == _AlertCategory.fuel ||
                category == _AlertCategory.tolls)
              _SettingsSection(
                title: 'Distancia de aviso',
                children: _distanceSection(context, ref, prefs, notifier),
              ),
            if (category == _AlertCategory.fuel)
              _SettingsSection(
                title: 'Precio en ruta',
                children: _fuelPriceSection(context, ref, prefs, notifier),
              ),
          ],
        ],
      ),
    );
  }

  List<Widget> _screenSection(
    BuildContext context,
    WidgetRef ref,
    AlertPreferences prefs,
    AlertPreferencesController notifier,
  ) {
    return switch (category) {
      _AlertCategory.radars => [
          _CompactSwitchTile(
            title: 'Mostrar en el mapa',
            subtitle: 'Durante la navegación',
            value: prefs.radarShowOnMap,
            onChanged: (v) =>
                notifier.update((p) => p.copyWith(radarShowOnMap: v)),
          ),
          _CompactSwitchTile(
            title: 'Mostrar en vista previa',
            subtitle: 'Al elegir la ruta (puedes cambiarlo en el mapa)',
            value: prefs.radarShowOnPreview,
            onChanged: (v) =>
                notifier.update((p) => p.copyWith(radarShowOnPreview: v)),
          ),
        ],
      _AlertCategory.fuel => [
          _CompactSwitchTile(
            title: 'Mostrar en el mapa',
            subtitle: 'Durante la navegación',
            value: prefs.fuelShowOnMap,
            onChanged: (v) =>
                notifier.update((p) => p.copyWith(fuelShowOnMap: v)),
          ),
          _CompactSwitchTile(
            title: 'Mostrar en vista previa',
            subtitle: 'Al elegir la ruta (puedes cambiarlo en el mapa)',
            value: prefs.fuelShowOnPreview,
            onChanged: (v) =>
                notifier.update((p) => p.copyWith(fuelShowOnPreview: v)),
          ),
        ],
      _AlertCategory.tolls => [
          _CompactSwitchTile(
            title: 'Mostrar en el mapa',
            subtitle: 'Durante la navegación',
            value: prefs.tollShowOnMap,
            onChanged: (v) =>
                notifier.update((p) => p.copyWith(tollShowOnMap: v)),
          ),
          _CompactSwitchTile(
            title: 'Mostrar en vista previa',
            subtitle: 'Al elegir la ruta (puedes cambiarlo en el mapa)',
            value: prefs.tollShowOnPreview,
            onChanged: (v) =>
                notifier.update((p) => p.copyWith(tollShowOnPreview: v)),
          ),
        ],
      _AlertCategory.curves => [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Elige qué curvas quieres ver y oír. Por defecto: cerrada y muy cerrada.',
              style: HubStyle.caption(),
            ),
          ),
          _CompactSwitchTile(
            title: 'Abierta',
            subtitle: 'Giros suaves (~35–54°)',
            value: prefs.curveOpenEnabled,
            onChanged: (v) =>
                notifier.update((p) => p.copyWith(curveOpenEnabled: v)),
          ),
          _CompactSwitchTile(
            title: 'Pronunciada',
            subtitle: 'Giros medios (~55–89°)',
            value: prefs.curvePronouncedEnabled,
            onChanged: (v) => notifier.update(
              (p) => p.copyWith(curvePronouncedEnabled: v),
            ),
          ),
          _CompactSwitchTile(
            title: 'Cerrada',
            subtitle: 'Giros fuertes (~90–134°)',
            value: prefs.curveTightEnabled,
            onChanged: (v) =>
                notifier.update((p) => p.copyWith(curveTightEnabled: v)),
          ),
          _CompactSwitchTile(
            title: 'Muy cerrada',
            subtitle: 'Casi 180° · horquilla',
            value: prefs.curveVeryClosedEnabled,
            onChanged: (v) => notifier.update(
              (p) => p.copyWith(curveVeryClosedEnabled: v),
            ),
          ),
          const Divider(height: 24),
          _CompactSwitchTile(
            title: 'Mostrar en el mapa',
            subtitle: 'Durante la navegación (por defecto off)',
            value: prefs.curvesShowOnMap,
            onChanged: (v) =>
                notifier.update((p) => p.copyWith(curvesShowOnMap: v)),
          ),
          _CompactSwitchTile(
            title: 'Mostrar en vista previa',
            subtitle: 'Al elegir la ruta (puedes cambiarlo en el mapa)',
            value: prefs.curvesShowOnPreview,
            onChanged: (v) =>
                notifier.update((p) => p.copyWith(curvesShowOnPreview: v)),
          ),
        ],
      _AlertCategory.speedLimit => const [],
      _AlertCategory.trafficSigns => const [],
    };
  }

  List<Widget> _voiceSection(
    BuildContext context,
    WidgetRef ref,
    AlertPreferences prefs,
    AlertPreferencesController notifier,
  ) {
    return switch (category) {
      _AlertCategory.radars => [
          _CompactSwitchTile(
            title: 'Aviso por voz',
            value: prefs.radarVoiceEnabled,
            onChanged: (v) =>
                notifier.update((p) => p.copyWith(radarVoiceEnabled: v)),
          ),
        ],
      _AlertCategory.fuel => [
          _CompactSwitchTile(
            title: 'Aviso por voz',
            value: prefs.fuelVoiceEnabled,
            onChanged: (v) =>
                notifier.update((p) => p.copyWith(fuelVoiceEnabled: v)),
          ),
        ],
      _AlertCategory.tolls => [
          _CompactSwitchTile(
            title: 'Aviso por voz',
            value: prefs.tollVoiceEnabled,
            onChanged: (v) =>
                notifier.update((p) => p.copyWith(tollVoiceEnabled: v)),
          ),
        ],
      _AlertCategory.curves => [
          _CompactSwitchTile(
            title: 'Aviso por voz',
            subtitle:
                'A los ${NavigationConstants.curveAnnounceMeters.round()} m: «Se aproxima curva…»',
            value: prefs.curvesVoiceEnabled,
            onChanged: (v) =>
                notifier.update((p) => p.copyWith(curvesVoiceEnabled: v)),
          ),
        ],
      _AlertCategory.speedLimit => const [],
      _AlertCategory.trafficSigns => const [],
    };
  }

  List<Widget> _distanceSection(
    BuildContext context,
    WidgetRef ref,
    AlertPreferences prefs,
    AlertPreferencesController notifier,
  ) {
    return switch (category) {
      _AlertCategory.radars => [
          _MultiDistanceChips(
            label: 'Avisar a',
            subtitle: 'Puedes marcar varias. La más cercana es el aviso fuerte.',
            selected: prefs.radarAnnounceDistances,
            options: AlertPreferences.radarAnnounceOptions,
            onChanged: (next) => notifier.update(
              (p) => p.copyWith(radarAnnounceDistances: next),
            ),
          ),
        ],
      _AlertCategory.fuel => [
          _DistanceChips(
            label: 'Mostrar aviso a',
            value: prefs.fuelAnnounceMeters,
            options: AlertPreferences.fuelAnnounceOptions,
            onSelected: (m) => notifier.update(
              (p) => p.copyWith(fuelAnnounceMeters: m),
            ),
          ),
        ],
      _AlertCategory.tolls => [
          _DistanceChips(
            label: 'Mostrar aviso a',
            value: prefs.tollAnnounceMeters,
            options: AlertPreferences.tollAnnounceOptions,
            onSelected: (m) => notifier.update(
              (p) => p.copyWith(tollAnnounceMeters: m),
            ),
          ),
        ],
      _ => const [],
    };
  }

  List<Widget> _fuelPriceSection(
    BuildContext context,
    WidgetRef ref,
    AlertPreferences prefs,
    AlertPreferencesController notifier,
  ) {
    return [
      _CompactSwitchTile(
        title: 'Mostrar precio',
        subtitle: 'Si se desactiva, solo verás la marca',
        value: prefs.fuelShowPrice,
        onChanged: (v) => notifier.update((p) => p.copyWith(fuelShowPrice: v)),
      ),
      _CompactSwitchTile(
        title: 'Filtrar por precio máximo',
        subtitle: prefs.fuelPriceFilterEnabled
            ? prefs.activeFuelMaxPriceEur != null
                ? 'Solo gasolineras a '
                    '${formatFuelMaxPriceEur(prefs.activeFuelMaxPriceEur!)} '
                    'o menos'
                : 'Indica el precio máximo en €/L'
            : 'Mostrar todas las gasolineras en la ruta',
        value: prefs.fuelPriceFilterEnabled,
        onChanged: (enabled) => notifier.update(
          (p) => p.copyWith(fuelPriceFilterEnabled: enabled),
        ),
      ),
      if (prefs.fuelPriceFilterEnabled)
        _FuelMaxPriceField(
          value: prefs.fuelMaxPriceEur,
          onSubmitted: (price) => notifier.update(
            (p) => p.copyWith(
              fuelMaxPriceEur: price,
              clearFuelMaxPriceEur: price == null,
            ),
          ),
        ),
    ];
  }
}

class _AlertTypeHubTile extends StatelessWidget {
  const _AlertTypeHubTile({
    required this.icon,
    required this.title,
    required this.summary,
    required this.enabled,
    required this.isDark,
    required this.onEnabledChanged,
    required this.onOpenDetail,
  });

  final IconData icon;
  final String title;
  final String summary;
  final bool enabled;
  final bool isDark;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : HubStyle.cardShadow,
      ),
      child: Material(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpenDetail,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: enabled
                        ? HubStyle.accent
                        : HubStyle.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: enabled ? Colors.white : HubStyle.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: HubStyle.sectionTitle()),
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: HubStyle.caption(
                          color: enabled
                              ? null
                              : HubStyle.subtitle.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: onEnabledChanged,
                  activeThumbColor: HubStyle.accent,
                  activeTrackColor: HubStyle.accent.withValues(alpha: 0.45),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: HubStyle.accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            title,
            style: HubStyle.sectionTitle(color: HubStyle.accent),
          ),
        ),
        ...children,
        const SizedBox(height: 8),
      ],
    );
  }
}

class _CompactSwitchTile extends StatelessWidget {
  const _CompactSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
      activeThumbColor: HubStyle.accent,
      activeTrackColor: HubStyle.accent.withValues(alpha: 0.45),
    );
  }
}

String _radarSummary(AlertPreferences prefs) {
  if (!prefs.radarsEnabled) {
    return 'Desactivado';
  }
  return _joinSummary([
    if (prefs.radarShowOnMap) 'Mapa',
    if (prefs.radarShowOnPreview) 'Vista previa',
    if (prefs.radarVoiceEnabled) 'Voz',
    _formatDistances(prefs.radarAnnounceDistances),
  ]);
}

String _fuelSummary(AlertPreferences prefs) {
  if (!prefs.fuelEnabled) {
    return 'Desactivado';
  }
  return _joinSummary([
    if (prefs.fuelShowOnMap) 'Mapa',
    if (prefs.fuelShowOnPreview) 'Vista previa',
    if (prefs.fuelShowPrice) 'Precio',
    if (prefs.fuelVoiceEnabled) 'Voz',
    if (prefs.fuelPriceFilterEnabled && prefs.activeFuelMaxPriceEur != null)
      '≤ ${formatFuelMaxPriceEur(prefs.activeFuelMaxPriceEur!)}',
    _formatDistance(prefs.fuelAnnounceMeters),
  ]);
}

String _tollSummary(AlertPreferences prefs) {
  if (!prefs.tollsEnabled) {
    return 'Desactivado';
  }
  return _joinSummary([
    if (prefs.tollShowOnMap) 'Mapa',
    if (prefs.tollShowOnPreview) 'Vista previa',
    if (prefs.tollVoiceEnabled) 'Voz',
    _formatDistance(prefs.tollAnnounceMeters),
  ]);
}

String _curveSummary(AlertPreferences prefs) {
  if (!prefs.curvesEnabled) {
    return 'Desactivado';
  }
  final types = <String>[
    if (prefs.curveOpenEnabled) 'Abierta',
    if (prefs.curvePronouncedEnabled) 'Pronunciada',
    if (prefs.curveTightEnabled) 'Cerrada',
    if (prefs.curveVeryClosedEnabled) 'Muy cerrada',
  ];
  return _joinSummary([
    if (types.isNotEmpty) types.join(', '),
    if (prefs.curvesShowOnMap) 'Mapa',
    if (prefs.curvesShowOnPreview) 'Vista previa',
    if (prefs.curvesVoiceEnabled)
      'Voz ${NavigationConstants.curveAnnounceMeters.round()} m',
  ]);
}

String _speedLimitSummary(AlertPreferences prefs) {
  if (!prefs.speedLimitAlertEnabled) {
    return 'Desactivado';
  }
  final margin = prefs.speedLimitToleranceKmh;
  return _joinSummary([
    margin == 0 ? 'Al pasarlo' : 'Margen +$margin km/h',
    if (prefs.speedLimitSoundEnabled) 'Sonido',
  ]);
}

String _trafficSignsSummary(AlertPreferences prefs) {
  if (!prefs.trafficSignsEnabled) {
    return 'Desactivado';
  }
  return _joinSummary([
    if (prefs.trafficSignalShowOnMap) 'Semáforo',
    if (prefs.stopShowOnMap) 'STOP',
    if (prefs.giveWayShowOnMap) 'Ceda',
  ]);
}

String _joinSummary(List<String> parts) {
  final filtered = parts.where((p) => p.isNotEmpty).toList();
  if (filtered.isEmpty) {
    return 'Activado';
  }
  return filtered.join(' · ');
}

String _formatDistance(double meters) => formatAlertDistanceMeters(meters);

String _formatDistances(List<double> meters) {
  if (meters.isEmpty) {
    return '';
  }
  final sorted = List<double>.from(meters)..sort((a, b) => b.compareTo(a));
  return sorted.map(formatAlertDistanceMeters).join(', ');
}

String formatFuelMaxPriceEur(double value) =>
    '${value.toStringAsFixed(2).replaceAll('.', ',')} €';

class _FuelMaxPriceField extends StatefulWidget {
  const _FuelMaxPriceField({
    required this.value,
    required this.onSubmitted,
  });

  final double? value;
  final ValueChanged<double?> onSubmitted;

  @override
  State<_FuelMaxPriceField> createState() => _FuelMaxPriceFieldState();
}

class _FuelMaxPriceFieldState extends State<_FuelMaxPriceField> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue(widget.value));
  }

  @override
  void didUpdateWidget(covariant _FuelMaxPriceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        widget.value?.toStringAsFixed(3) !=
            AlertPreferences.parseFuelMaxPriceInput(_controller.text)
                ?.toStringAsFixed(3)) {
      _controller.text = _formatValue(widget.value);
      _errorText = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatValue(double? value) {
    if (value == null) {
      return '';
    }
    return value.toStringAsFixed(3).replaceAll('.', ',');
  }

  void _commit() {
    final raw = _controller.text;
    if (raw.trim().isEmpty) {
      setState(() => _errorText = null);
      widget.onSubmitted(null);
      return;
    }
    final parsed = AlertPreferences.parseFuelMaxPriceInput(raw);
    if (parsed == null) {
      setState(() => _errorText = 'Precio no válido (ej.: 1,65)');
      return;
    }
    setState(() {
      _errorText = null;
      _controller.text = _formatValue(parsed);
    });
    widget.onSubmitted(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        decoration: HubStyle.inputDecoration(
          labelText: 'Precio máximo',
          hintText: 'Ej.: 1,65',
          helperText: 'Introduce el precio actual que quieres como tope',
        ).copyWith(
          suffixText: '€/L',
          errorText: _errorText,
        ),
        onSubmitted: (_) => _commit(),
        onEditingComplete: _commit,
      ),
    );
  }
}

class _DistanceChips extends StatelessWidget {
  const _DistanceChips({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final double value;
  final List<double> options;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: HubStyle.sectionTitle()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text(formatAlertDistanceMeters(option)),
                  selected: (value - option).abs() < 0.5,
                  onSelected: (_) => onSelected(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MultiDistanceChips extends StatelessWidget {
  const _MultiDistanceChips({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final List<double> selected;
  final List<double> options;
  final ValueChanged<List<double>> onChanged;

  bool _isSelected(double option) =>
      selected.any((m) => (m - option).abs() < 0.5);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: HubStyle.sectionTitle()),
          const SizedBox(height: 4),
          Text(subtitle, style: HubStyle.caption()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                FilterChip(
                  label: Text(formatAlertDistanceMeters(option)),
                  selected: _isSelected(option),
                  onSelected: (want) {
                    final next = List<double>.from(selected);
                    if (want) {
                      if (!_isSelected(option)) {
                        next.add(option);
                      }
                    } else {
                      if (next.length <= 1) {
                        return;
                      }
                      next.removeWhere((m) => (m - option).abs() < 0.5);
                    }
                    onChanged(next);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
