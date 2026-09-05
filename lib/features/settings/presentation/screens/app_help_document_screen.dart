import 'package:flutter/material.dart';
import 'package:moto_amg/features/settings/presentation/help/app_help_content.dart';

enum AppHelpDocumentKind { quickGuide, fullManual, faq }

extension AppHelpDocumentKindX on AppHelpDocumentKind {
  String get title => switch (this) {
        AppHelpDocumentKind.quickGuide => 'Guía rápida de uso',
        AppHelpDocumentKind.fullManual => 'Manual completo',
        AppHelpDocumentKind.faq => 'Preguntas y respuestas',
      };

  String get subtitle => switch (this) {
        AppHelpDocumentKind.quickGuide =>
          'Lo esencial para empezar en pocos minutos',
        AppHelpDocumentKind.fullManual =>
          'Referencia detallada para el día a día',
        AppHelpDocumentKind.faq => 'Dudas frecuentes, con respuestas claras',
      };

  IconData get icon => switch (this) {
        AppHelpDocumentKind.quickGuide => Icons.bolt_outlined,
        AppHelpDocumentKind.fullManual => Icons.menu_book_outlined,
        AppHelpDocumentKind.faq => Icons.quiz_outlined,
      };
}

/// Muestra una guía, el manual o el FAQ.
class AppHelpDocumentScreen extends StatelessWidget {
  const AppHelpDocumentScreen({super.key, required this.kind});

  final AppHelpDocumentKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(kind.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            kind.subtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          if (kind == AppHelpDocumentKind.faq)
            ..._faqCards(context)
          else
            ..._sectionCards(context),
        ],
      ),
    );
  }

  List<Widget> _sectionCards(BuildContext context) {
    final sections = switch (kind) {
      AppHelpDocumentKind.quickGuide => quickGuideSections,
      AppHelpDocumentKind.fullManual => fullManualSections,
      AppHelpDocumentKind.faq => const <HelpSection>[],
    };
    return [
      for (final section in sections) ...[
        _SectionCard(title: section.title, body: section.body),
        const SizedBox(height: 10),
      ],
    ];
  }

  List<Widget> _faqCards(BuildContext context) {
    return [
      for (final item in faqItems) ...[
        _FaqTile(question: item.question, answer: item.answer),
        const SizedBox(height: 8),
      ],
    ];
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          question,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
