import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/settings/presentation/screens/legal_document_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Versión, contacto, legal y atribuciones de la app.
class AboutAppScreen extends StatefulWidget {
  const AboutAppScreen({super.key});

  @override
  State<AboutAppScreen> createState() => _AboutAppScreenState();
}

class _AboutAppScreenState extends State<AboutAppScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInfo());
  }

  Future<void> _loadInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() => _info = info);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }

  Future<void> _openEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      queryParameters: const {
        'subject': 'MotoAMG — soporte',
      },
    );
    final opened = await launchUrl(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Escribe a ${AppConstants.supportEmail}'),
        ),
      );
    }
  }

  void _openLegal(LegalDocumentKind kind, String url) {
    if (url.isNotEmpty) {
      unawaited(_openUrl(url));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(kind: kind),
      ),
    );
  }

  void _openLicenses() {
    showLicensePage(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: _versionLabel,
      applicationLegalese:
          '${AppConstants.copyrightNotice}\n'
          'Desarrollo: ${AppConstants.developerName}\n\n'
          'Las bibliotecas de terceros se listan a continuación con sus '
          'licencias. Mapas, radares, carburantes y servicios de infraestructura '
          'tienen atribuciones propias en «Acerca de MotoAMG».',
      applicationIcon: Image.asset(
        AppConstants.appIconAsset,
        width: 48,
        height: 48,
      ),
    );
  }

  String get _versionLabel {
    final info = _info;
    if (info == null) {
      return '…';
    }
    return '${info.version} (${info.buildNumber})';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(titleText: 'Acerca de MotoAMG'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                AppConstants.appIconAsset,
                width: 88,
                height: 88,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppConstants.appName,
            textAlign: TextAlign.center,
            style: HubStyle.headline(),
          ),
          const SizedBox(height: 6),
          Text(
            AppConstants.appTagline,
            textAlign: TextAlign.center,
            style: HubStyle.body(),
          ),
          const SizedBox(height: 6),
          Text(
            AppConstants.appShortDescription,
            textAlign: TextAlign.center,
            style: HubStyle.caption(),
          ),
          const SizedBox(height: 8),
          Text(
            'Versión $_versionLabel',
            textAlign: TextAlign.center,
            style: HubStyle.body(),
          ),
          const SizedBox(height: 8),
          Text(
            AppConstants.copyrightNotice,
            textAlign: TextAlign.center,
            style: HubStyle.caption(),
          ),
          const SizedBox(height: 4),
          Text(
            'Desarrollo: ${AppConstants.developerName}',
            textAlign: TextAlign.center,
            style: HubStyle.caption(),
          ),
          const SizedBox(height: 28),
          _AboutLinkTile(
            icon: Icons.mail_outline_rounded,
            title: 'Contacto y soporte',
            subtitle: AppConstants.supportEmail,
            isDark: isDark,
            onTap: _openEmail,
          ),
          const SizedBox(height: 10),
          _AboutLinkTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Política de privacidad',
            isDark: isDark,
            onTap: () => _openLegal(
              LegalDocumentKind.privacy,
              AppConstants.privacyPolicyUrl,
            ),
          ),
          const SizedBox(height: 10),
          _AboutLinkTile(
            icon: Icons.description_outlined,
            title: 'Términos de uso',
            isDark: isDark,
            onTap: () => _openLegal(
              LegalDocumentKind.terms,
              AppConstants.termsOfUseUrl,
            ),
          ),
          const SizedBox(height: 10),
          _AboutLinkTile(
            icon: Icons.code_outlined,
            title: 'Licencias de software libre',
            subtitle: 'Paquetes de código abierto y sus licencias',
            isDark: isDark,
            onTap: _openLicenses,
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atribuciones de mapas y datos',
                      style: HubStyle.sectionTitle(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppConstants.dataAttributionsPlain,
                      style: HubStyle.caption(),
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

class _AboutLinkTile extends StatelessWidget {
  const _AboutLinkTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
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
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: HubStyle.caption()),
                      ],
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
