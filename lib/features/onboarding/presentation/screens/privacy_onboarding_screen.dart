import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/core/onboarding/app_onboarding_provider.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/settings/presentation/screens/legal_document_screen.dart';

/// Aceptación de privacidad: en el dispositivo (1.ª instalación) o por cuenta.
enum PrivacyAcceptanceScope {
  /// Solo Hive en este móvil (antes del login).
  device,

  /// Guardado en Firestore para el usuario autenticado.
  account,
}

/// Tras permisos (dispositivo) o tras login (cuenta): hay que aceptar.
class PrivacyOnboardingScreen extends ConsumerStatefulWidget {
  const PrivacyOnboardingScreen({
    super.key,
    this.scope = PrivacyAcceptanceScope.device,
  });

  final PrivacyAcceptanceScope scope;

  @override
  ConsumerState<PrivacyOnboardingScreen> createState() =>
      _PrivacyOnboardingScreenState();
}

class _PrivacyOnboardingScreenState
    extends ConsumerState<PrivacyOnboardingScreen> {
  var _accepted = false;
  var _completing = false;
  late final TapGestureRecognizer _privacyTap;
  late final TapGestureRecognizer _termsTap;

  bool get _forAccount => widget.scope == PrivacyAcceptanceScope.account;

  @override
  void initState() {
    super.initState();
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => _openDocument(LegalDocumentKind.privacy);
    _termsTap = TapGestureRecognizer()
      ..onTap = () => _openDocument(LegalDocumentKind.terms);
  }

  @override
  void dispose() {
    _privacyTap.dispose();
    _termsTap.dispose();
    super.dispose();
  }

  Future<void> _openDocument(LegalDocumentKind kind) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(kind: kind),
      ),
    );
  }

  Future<void> _finish() async {
    if (!_accepted || _completing) {
      return;
    }
    setState(() => _completing = true);
    try {
      if (_forAccount) {
        await ref
            .read(authActionControllerProvider.notifier)
            .acceptPrivacyPolicy();
      } else {
        await ref.read(appOnboardingControllerProvider).acceptPrivacy();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _completing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar la aceptación. Inténtalo de nuevo.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final subtitle = _forAccount
        ? 'Esta cuenta aún no ha aceptado cómo tratamos los datos. '
            'Cada usuario debe aceptar la política, aunque el móvil ya se haya usado.'
        : 'Antes de entrar en ${AppConstants.appName} debes aceptar cómo '
            'tratamos tus datos (ubicación, cuenta y uso del servicio).';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    AppConstants.appIconAsset,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Privacidad y condiciones',
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _LegalSummaryCard(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Política de privacidad',
                      body:
                          'Explica qué datos usamos (cuenta, ubicación, grupos, '
                          'intercom), con qué finalidad y cómo puedes ejercer '
                          'tus derechos.',
                      actionLabel: 'Leer política de privacidad',
                      onOpen: () => _openDocument(LegalDocumentKind.privacy),
                    ),
                    const SizedBox(height: 12),
                    _LegalSummaryCard(
                      icon: Icons.description_outlined,
                      title: 'Términos de uso',
                      body:
                          'Condiciones del servicio: uso responsable en ruta, '
                          'límites de responsabilidad y reglas de la comunidad.',
                      actionLabel: 'Leer términos de uso',
                      onOpen: () => _openDocument(LegalDocumentKind.terms),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _accepted
                        ? colors.primary.withValues(alpha: 0.45)
                        : colors.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: CheckboxListTile(
                  value: _accepted,
                  onChanged: _completing
                      ? null
                      : (value) => setState(() => _accepted = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                  title: Text.rich(
                    TextSpan(
                      style: textTheme.bodyMedium?.copyWith(height: 1.35),
                      children: [
                        const TextSpan(text: 'He leído y acepto la '),
                        TextSpan(
                          text: 'Política de privacidad',
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: _privacyTap,
                        ),
                        const TextSpan(text: ' y los '),
                        TextSpan(
                          text: 'Términos de uso',
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: _termsTap,
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ),
              if (!_accepted) ...[
                const SizedBox(height: 8),
                Text(
                  _forAccount
                      ? 'Marca la casilla para continuar con esta cuenta.'
                      : 'Marca la casilla para continuar.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(color: colors.error),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _accepted && !_completing ? _finish : null,
                child: _completing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Aceptar y continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalSummaryCard extends StatelessWidget {
  const _LegalSummaryCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onOpen,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onOpen,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
