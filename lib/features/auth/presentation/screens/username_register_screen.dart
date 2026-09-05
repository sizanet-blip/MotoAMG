import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/auth/presentation/utils/auth_validators.dart';

class UsernameRegisterScreen extends ConsumerStatefulWidget {
  const UsernameRegisterScreen({super.key});

  @override
  ConsumerState<UsernameRegisterScreen> createState() =>
      _UsernameRegisterScreenState();
}

class _UsernameRegisterScreenState
    extends ConsumerState<UsernameRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  var _obscure = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await ref.read(authActionControllerProvider.notifier).registerWithUsername(
          username: _usernameController.text,
          password: _passwordController.text,
        );
    if (!mounted) {
      return;
    }
    if (ref.read(authActionControllerProvider).hasError) {
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authActionControllerProvider).isLoading;

    ref.listen(authActionControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        },
      );
    });

    return Scaffold(
      backgroundColor: HubStyle.surface,
      appBar: HubStyle.appBar(titleText: 'Cuenta con usuario'),
      body: SafeArea(
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Text(
                  'Elige un usuario único y una contraseña. No hace falta correo. '
                  'Al crearla te daremos una clave de recuperación: guárdala, '
                  'es la única forma de recuperar la cuenta.',
                  style: HubStyle.body(),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _usernameController,
                  enabled: !isLoading,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: HubStyle.inputDecoration(
                    labelText: 'Usuario (único)',
                    hintText: 'ej. alberto_87',
                    helperText: 'Letras, números y _. Empieza con letra.',
                  ),
                  validator: AuthValidators.username,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  enabled: !isLoading,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  decoration: HubStyle.inputDecoration(
                    labelText: 'Contraseña',
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: HubStyle.subtitle,
                      ),
                    ),
                  ),
                  validator: AuthValidators.password,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmController,
                  enabled: !isLoading,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: HubStyle.inputDecoration(
                    labelText: 'Repetir contraseña',
                  ),
                  validator: (value) => AuthValidators.confirmPassword(
                    value,
                    _passwordController.text,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: HubStyle.filledButtonStyle(),
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Crear cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
