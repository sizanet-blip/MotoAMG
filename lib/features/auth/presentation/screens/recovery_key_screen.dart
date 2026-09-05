import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';

class RecoveryKeyScreen extends ConsumerStatefulWidget {
  const RecoveryKeyScreen({super.key, required this.recoveryKey});

  final String recoveryKey;

  @override
  ConsumerState<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends ConsumerState<RecoveryKeyScreen> {
  var _saved = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: HubStyle.surface,
        appBar: HubStyle.appBar(
          titleText: 'Guarda tu clave',
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Esta clave es la única forma de recuperar la cuenta si '
                        'olvidas la contraseña (no hay correo).',
                        style: HubStyle.body(color: HubStyle.title),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Apúntala en papel o en un gestor de contraseñas. '
                        'No la enseñes a nadie. Solo se muestra ahora.',
                        style: HubStyle.body(),
                      ),
                      const SizedBox(height: 24),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: HubStyle.cardShadow,
                          border: Border.all(
                            color: HubStyle.accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          child: SelectableText(
                            widget.recoveryKey,
                            textAlign: TextAlign.center,
                            style: HubStyle.headline(color: HubStyle.accent)
                                .copyWith(
                              fontSize: 22,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: widget.recoveryKey),
                          );
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Clave copiada.')),
                          );
                        },
                        style: HubStyle.outlinedButtonStyle(),
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copiar clave'),
                      ),
                      const SizedBox(height: 32),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: HubStyle.cardShadow,
                          border: Border.all(
                            color: _saved
                                ? HubStyle.accent.withValues(alpha: 0.45)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: CheckboxListTile(
                          value: _saved,
                          activeColor: HubStyle.accent,
                          onChanged: (value) =>
                              setState(() => _saved = value ?? false),
                          contentPadding:
                              const EdgeInsets.fromLTRB(8, 4, 12, 4),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            'He guardado la clave en un sitio seguro',
                            style: HubStyle.body(color: HubStyle.title),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _saved
                            ? () {
                                ref
                                    .read(pendingRecoveryKeyProvider.notifier)
                                    .state = null;
                                final navigator = Navigator.of(context);
                                if (navigator.canPop()) {
                                  navigator
                                      .popUntil((route) => route.isFirst);
                                }
                              }
                            : null,
                        style: HubStyle.filledButtonStyle(enabled: _saved),
                        child: const Text('Continuar'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
