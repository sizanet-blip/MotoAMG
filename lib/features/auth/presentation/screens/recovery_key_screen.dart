import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Guarda tu clave'),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Esta clave es la única forma de recuperar la cuenta si '
                        'olvidas la contraseña (no hay correo).',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Apúntala en papel o en un gestor de contraseñas. '
                        'No la enseñes a nadie. Solo se muestra ahora.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      SelectableText(
                        widget.recoveryKey,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
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
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar clave'),
                      ),
                      const SizedBox(height: 32),
                      CheckboxListTile(
                        value: _saved,
                        onChanged: (value) =>
                            setState(() => _saved = value ?? false),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'He guardado la clave en un sitio seguro',
                        ),
                      ),
                      const SizedBox(height: 8),
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
