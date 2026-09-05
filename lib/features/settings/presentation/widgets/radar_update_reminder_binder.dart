import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/core/utils/spain_data_freshness.dart';
import 'package:moto_amg/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:moto_amg/features/settings/presentation/providers/settings_providers.dart';
import 'package:moto_amg/features/settings/presentation/screens/radar_cache_settings_screen.dart';

/// Al entrar en la app, si los radares están viejos según la config, muestra un aviso.
class RadarUpdateReminderBinder extends ConsumerStatefulWidget {
  const RadarUpdateReminderBinder({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RadarUpdateReminderBinder> createState() =>
      _RadarUpdateReminderBinderState();
}

class _RadarUpdateReminderBinderState
    extends ConsumerState<RadarUpdateReminderBinder> {
  var _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowReminder());
    });
  }

  Future<void> _maybeShowReminder() async {
    if (!mounted || _checking) {
      return;
    }
    if (ref.read(radarUpdateReminderShownThisSessionProvider)) {
      return;
    }

    // Esperar un poco a que hidraten prefs y caché.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) {
      return;
    }

    final prefs = ref.read(radarUpdateReminderProvider);
    if (!prefs.enabled) {
      return;
    }
    if (ref.read(radarUpdateReminderShownThisSessionProvider)) {
      return;
    }

    _checking = true;
    try {
      final status = await ref.read(spainRadarCacheStatusProvider.future);
      if (!mounted) {
        return;
      }
      final remind = shouldRemindRadarUpdate(
        hasOfficial: status.hasOfficial,
        officialFetchedAt: status.officialFetchedAt,
        hasOsm: status.hasOsm,
        osmFetchedAt: status.osmFetchedAt,
        intervalDays: prefs.intervalDays,
      );
      if (!remind) {
        return;
      }

      ref.read(radarUpdateReminderShownThisSessionProvider.notifier).state =
          true;

      final missing = !status.isReady;
      final message = missing
          ? 'Aún no tienes el inventario de radares descargado. '
              'Conviene actualizarlo (mejor con Wi‑Fi) para avisarte en ruta.'
          : 'Han pasado al menos ${prefs.intervalDays} días desde la última '
              'actualización de radares. ¿Quieres actualizarlos ahora?';

      if (!mounted) {
        return;
      }
      final action = await showDialog<_ReminderAction>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: HubStyle.surface,
          title: Text(
            missing ? 'Descargar radares' : 'Actualizar radares',
            style: HubStyle.sectionTitle(),
          ),
          content: Text(message, style: HubStyle.body()),
          actions: [
            TextButton(
              style: HubStyle.textButtonStyle(),
              onPressed: () => Navigator.pop(context, _ReminderAction.later),
              child: const Text('Más tarde'),
            ),
            TextButton(
              style: HubStyle.textButtonStyle(),
              onPressed: () =>
                  Navigator.pop(context, _ReminderAction.openSettings),
              child: const Text('Configuración'),
            ),
            FilledButton(
              style: HubStyle.filledButtonStyle(),
              onPressed: () =>
                  Navigator.pop(context, _ReminderAction.updateNow),
              child: Text(missing ? 'Descargar' : 'Actualizar'),
            ),
          ],
        ),
      );

      if (!mounted || action == null || action == _ReminderAction.later) {
        return;
      }
      if (action == _ReminderAction.openSettings) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const RadarCacheSettingsScreen(),
          ),
        );
        return;
      }
      await ref.read(radarCacheDownloadProvider.notifier).download();
    } catch (_) {
      // Silencioso: no bloquear la entrada por un fallo de lectura de caché.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(radarCacheDownloadProvider, (previous, next) {
      final message = next.snackMessage;
      if (message == null || message == previous?.snackMessage) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
    return widget.child;
  }
}

enum _ReminderAction { later, openSettings, updateNow }
