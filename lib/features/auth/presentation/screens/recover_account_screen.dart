import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/auth/presentation/utils/auth_validators.dart';

class RecoverAccountScreen extends ConsumerStatefulWidget {
  const RecoverAccountScreen({super.key});

  @override
  ConsumerState<RecoverAccountScreen> createState() =>
      _RecoverAccountScreenState();
}

class _RecoverAccountScreenState extends ConsumerState<RecoverAccountScreen> {
  var _useEmail = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Con correo'),
                  icon: Icon(Icons.mail_outline),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Con clave'),
                  icon: Icon(Icons.vpn_key_outlined),
                ),
              ],
              selected: {_useEmail},
              onSelectionChanged: (value) {
                setState(() => _useEmail = value.first);
              },
            ),
            const SizedBox(height: 24),
            if (_useEmail) const _EmailResetForm() else const _KeyResetForm(),
          ],
        ),
      ),
    );
  }
}

class _EmailResetForm extends ConsumerStatefulWidget {
  const _EmailResetForm();

  @override
  ConsumerState<_EmailResetForm> createState() => _EmailResetFormState();
}

class _EmailResetFormState extends ConsumerState<_EmailResetForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await ref
        .read(authActionControllerProvider.notifier)
        .sendPasswordReset(_emailController.text);
    if (!mounted) {
      return;
    }
    if (ref.read(authActionControllerProvider).hasError) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Si hay una cuenta con ese correo, te hemos enviado un enlace.',
        ),
      ),
    );
    Navigator.of(context).pop();
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

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Para cuentas creadas con correo o Google. Te enviaremos un enlace.',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            enabled: !isLoading,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Correo',
              border: OutlineInputBorder(),
            ),
            validator: AuthValidators.email,
            onFieldSubmitted: (_) => _send(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: isLoading ? null : _send,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar enlace'),
          ),
        ],
      ),
    );
  }
}

class _KeyResetForm extends ConsumerStatefulWidget {
  const _KeyResetForm();

  @override
  ConsumerState<_KeyResetForm> createState() => _KeyResetFormState();
}

class _KeyResetFormState extends ConsumerState<_KeyResetForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _keyController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  var _obscure = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _keyController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await ref.read(authActionControllerProvider.notifier).recoverUsernamePassword(
      username: _usernameController.text,
      recoveryKey: _keyController.text,
      newPassword: _passwordController.text,
    );
    if (!mounted) {
      return;
    }
    if (ref.read(authActionControllerProvider).hasError) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contraseña actualizada. Ya estás dentro.')),
    );
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

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Para cuentas con usuario (sin correo). Usa la clave que te dimos '
            'al registrarte y elige una contraseña nueva.',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _usernameController,
            enabled: !isLoading,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Usuario',
              border: OutlineInputBorder(),
            ),
            validator: AuthValidators.username,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _keyController,
            enabled: !isLoading,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Clave de recuperación',
              hintText: 'MA-XXXX-XXXX-XXXX-XXXX',
              border: OutlineInputBorder(),
            ),
            validator: AuthValidators.recoveryKey,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            enabled: !isLoading,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              ),
            ),
            validator: AuthValidators.password,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmController,
            enabled: !isLoading,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Repetir contraseña',
              border: OutlineInputBorder(),
            ),
            validator: (value) => AuthValidators.confirmPassword(
              value,
              _passwordController.text,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: isLoading ? null : _submit,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Cambiar contraseña y entrar'),
          ),
        ],
      ),
    );
  }
}
