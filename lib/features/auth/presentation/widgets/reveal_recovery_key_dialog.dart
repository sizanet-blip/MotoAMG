import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/auth/domain/exceptions/auth_exceptions.dart';
import 'package:loc_motos/features/auth/presentation/providers/auth_providers.dart';
import 'package:loc_motos/features/auth/presentation/utils/auth_validators.dart';

class RevealRecoveryKeyDialog extends ConsumerStatefulWidget {
  const RevealRecoveryKeyDialog({super.key, required this.username});

  final String username;

  static Future<void> show(BuildContext context, {required String username}) {
    return showDialog<void>(
      context: context,
      builder: (_) => RevealRecoveryKeyDialog(username: username),
    );
  }

  @override
  ConsumerState<RevealRecoveryKeyDialog> createState() =>
      _RevealRecoveryKeyDialogState();
}

class _RevealRecoveryKeyDialogState
    extends ConsumerState<RevealRecoveryKeyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  var _obscure = true;
  var _busy = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _busy = true);
    try {
      final key = await ref
          .read(authActionControllerProvider.notifier)
          .revealRecoveryKey(
            username: widget.username,
            password: _passwordController.text,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ref.read(pendingRecoveryKeyProvider.notifier).state = key;
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Ver clave de recuperación'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pon tu contraseña para ver la clave. Guárdala: si la olvidas '
              'no hay otra forma de recuperar la cuenta.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              enabled: !_busy,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Contraseña',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
              validator: AuthValidators.loginPassword,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Ver clave'),
        ),
      ],
    );
  }
}
