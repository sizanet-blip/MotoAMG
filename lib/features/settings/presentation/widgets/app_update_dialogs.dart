import 'package:flutter/material.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/settings/domain/entities/app_update_metadata.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showAppUpdateDialog(
  BuildContext context, {
  required AppUpdateCheckResult result,
  bool barrierDismissible = true,
}) async {
  final metadata = result.metadata;
  if (metadata == null || !result.hasUpdate) {
    return;
  }
  final changelog = metadata.changelog.isEmpty
      ? 'Hay una versión nueva disponible.'
      : metadata.changelog.map((line) => '• $line').join('\n');
  final downloadUrl = result.downloadUrl;

  await showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible &&
        result.availability != AppUpdateAvailability.mandatory,
    builder: (context) {
      return AlertDialog(
        backgroundColor: HubStyle.surface,
        title: Text(
          result.availability == AppUpdateAvailability.mandatory
              ? 'Actualización obligatoria'
              : 'Actualización disponible',
          style: HubStyle.sectionTitle(),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Instalada: ${result.currentVersion} (${result.currentBuild})\n'
                'Nueva: ${metadata.latestVersion} (${metadata.latestBuild})',
                style: HubStyle.body(),
              ),
              const SizedBox(height: 12),
              Text(changelog, style: HubStyle.caption()),
            ],
          ),
        ),
        actions: [
          if (result.availability != AppUpdateAvailability.mandatory)
            TextButton(
              style: HubStyle.textButtonStyle(),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Más tarde'),
            ),
          FilledButton(
            style: HubStyle.filledButtonStyle(),
            onPressed: downloadUrl == null || downloadUrl.isEmpty
                ? null
                : () async {
                    final uri = Uri.tryParse(downloadUrl);
                    if (uri == null) {
                      return;
                    }
                    final ok = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No se pudo abrir el enlace de descarga.'),
                        ),
                      );
                    }
                  },
            child: const Text('Descargar'),
          ),
        ],
      );
    },
  );
}

Future<void> showAppUpdateUpToDateSnack(BuildContext context) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Ya tienes la última versión.')),
  );
}

Future<void> showAppUpdateErrorSnack(
  BuildContext context,
  String message,
) async {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
