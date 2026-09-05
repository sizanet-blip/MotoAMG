import 'package:flutter/material.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(titleText: kind.title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(kind.subtitle, style: HubStyle.body()),
          const SizedBox(height: 16),
          if (kind == AppHelpDocumentKind.faq)
            ..._faqCards(isDark)
          else
            ..._sectionCards(isDark),
        ],
      ),
    );
  }

  List<Widget> _sectionCards(bool isDark) {
    final sections = switch (kind) {
      AppHelpDocumentKind.quickGuide => quickGuideSections,
      AppHelpDocumentKind.fullManual => fullManualSections,
      AppHelpDocumentKind.faq => const <HelpSection>[],
    };
    return [
      for (final section in sections) ...[
        _SectionCard(title: section.title, body: section.body, isDark: isDark),
        const SizedBox(height: 10),
      ],
    ];
  }

  List<Widget> _faqCards(bool isDark) {
    return [
      for (final item in faqItems) ...[
        _FaqTile(
          question: item.question,
          answer: item.answer,
          isDark: isDark,
        ),
        const SizedBox(height: 8),
      ],
    ];
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.body,
    required this.isDark,
  });

  final String title;
  final String body;
  final bool isDark;

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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: HubStyle.sectionTitle()),
              const SizedBox(height: 8),
              Text(body, style: HubStyle.body()),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.question,
    required this.answer,
    required this.isDark,
  });

  final String question;
  final String answer;
  final bool isDark;

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
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            iconColor: HubStyle.accent,
            collapsedIconColor: HubStyle.subtitle,
            title: Text(question, style: HubStyle.sectionTitle()),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(answer, style: HubStyle.body()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
