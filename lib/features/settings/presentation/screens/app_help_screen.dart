import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/features/settings/presentation/screens/app_help_document_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Menú de ayuda: guía rápida, manual completo y preguntas frecuentes.
class AppHelpScreen extends StatelessWidget {
  const AppHelpScreen({super.key});

  Future<void> _openEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      queryParameters: const {'subject': 'MotoAMG — ayuda'},
    );
    final opened = await launchUrl(uri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Escribe a ${AppConstants.supportEmail}')),
      );
    }
  }

  void _open(BuildContext context, AppHelpDocumentKind kind) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppHelpDocumentScreen(kind: kind),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'Documentación para usuarios',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Elige el formato que necesites: un resumen rápido, el manual '
            'completo o las preguntas más habituales.',
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          for (final kind in AppHelpDocumentKind.values) ...[
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  child: Icon(kind.icon),
                ),
                title: Text(
                  kind.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(kind.subtitle),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(context, kind),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '¿Necesitas ayuda personalizada?',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Si no encuentras la respuesta en la documentación, '
                    'escríbenos y te atendemos.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => unawaited(_openEmail(context)),
                    icon: const Icon(Icons.mail_outline),
                    label: Text(AppConstants.supportEmail),
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
