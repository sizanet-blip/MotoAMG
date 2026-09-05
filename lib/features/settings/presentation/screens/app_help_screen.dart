import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(titleText: 'Ayuda'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('Documentación para usuarios', style: HubStyle.sectionTitle()),
          const SizedBox(height: 6),
          Text(
            'Elige el formato que necesites: un resumen rápido, el manual '
            'completo o las preguntas más habituales.',
            style: HubStyle.body(),
          ),
          const SizedBox(height: 16),
          for (final kind in AppHelpDocumentKind.values) ...[
            _HelpOptionCard(
              icon: kind.icon,
              title: kind.title,
              subtitle: kind.subtitle,
              isDark: isDark,
              onTap: () => _open(context, kind),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '¿Necesitas ayuda personalizada?',
                      style: HubStyle.sectionTitle(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Si no encuentras la respuesta en la documentación, '
                      'escríbenos y te atendemos.',
                      style: HubStyle.body(),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => unawaited(_openEmail(context)),
                      style: HubStyle.filledButtonStyle(),
                      icon: const Icon(Icons.mail_outline_rounded),
                      label: Text(AppConstants.supportEmail),
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
}

class _HelpOptionCard extends StatelessWidget {
  const _HelpOptionCard({
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
