import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/features/settings/presentation/screens/legal_document_screen.dart';
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
        'subject': 'LocMotos — soporte',
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
          'tienen atribuciones propias en «Acerca de LocMotos».',
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
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de LocMotos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Versión $_versionLabel',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppConstants.appTagline,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppConstants.copyrightNotice,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Desarrollo: ${AppConstants.developerName}',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          _AboutLinkTile(
            icon: Icons.mail_outline,
            title: 'Contacto y soporte',
            subtitle: AppConstants.supportEmail,
            onTap: _openEmail,
          ),
          _AboutLinkTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Política de privacidad',
            onTap: () => _openLegal(
              LegalDocumentKind.privacy,
              AppConstants.privacyPolicyUrl,
            ),
          ),
          _AboutLinkTile(
            icon: Icons.description_outlined,
            title: 'Términos de uso',
            onTap: () => _openLegal(
              LegalDocumentKind.terms,
              AppConstants.termsOfUseUrl,
            ),
          ),
          _AboutLinkTile(
            icon: Icons.code_outlined,
            title: 'Licencias de software libre',
            subtitle: 'Paquetes de código abierto y sus licencias',
            onTap: _openLicenses,
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Atribuciones de mapas y datos',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppConstants.dataAttributionsPlain,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
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

class _AboutLinkTile extends StatelessWidget {
  const _AboutLinkTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
