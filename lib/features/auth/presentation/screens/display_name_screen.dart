import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/auth/presentation/providers/auth_providers.dart';
import 'package:loc_motos/features/auth/presentation/utils/auth_validators.dart';

class DisplayNameScreen extends ConsumerStatefulWidget {
  const DisplayNameScreen({
    super.key,
    this.alreadySignedIn = false,
    this.isGuest = true,
  });

  final bool alreadySignedIn;
  final bool isGuest;

  @override
  ConsumerState<DisplayNameScreen> createState() => _DisplayNameScreenState();
}

class _DisplayNameScreenState extends ConsumerState<DisplayNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final name = _nameController.text.trim();
    final controller = ref.read(authActionControllerProvider.notifier);
    if (widget.alreadySignedIn) {
      await controller.updateDisplayName(name);
    } else {
      await controller.signInAnonymously(displayName: name);
    }
    if (!mounted) {
      return;
    }
    if (ref.read(authActionControllerProvider).hasError) {
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authActionControllerProvider);
    final isLoading = action.isLoading;

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
      appBar: AppBar(
        title: Text(
          widget.isGuest || !widget.alreadySignedIn
              ? 'Cuenta de invitado'
              : 'Tu nombre en el mapa',
        ),
        actions: [
          if (widget.alreadySignedIn)
            IconButton(
              tooltip: 'Salir',
              onPressed: isLoading
                  ? null
                  : () => ref
                        .read(authActionControllerProvider.notifier)
                        .signOut(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.isGuest || !widget.alreadySignedIn
                            ? 'Es una cuenta de invitado: solo hace falta un nombre. '
                                'Podrás unirte con un código. Al salir se borra todo '
                                'y no se guarda ni se puede recuperar.'
                            : 'Así te verán en el mapa.',
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        enabled: !isLoading,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          hintText: 'Ej. Alberto',
                          border: OutlineInputBorder(),
                        ),
                        validator: AuthValidators.displayName,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 32),
                      FilledButton(
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                widget.isGuest || !widget.alreadySignedIn
                                    ? 'Entrar como invitado'
                                    : 'Continuar',
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
