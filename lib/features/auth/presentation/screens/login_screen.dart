import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/auth/presentation/screens/display_name_screen.dart';
import 'package:moto_amg/features/auth/presentation/screens/recover_account_screen.dart';
import 'package:moto_amg/features/auth/presentation/screens/register_options_screen.dart';
import 'package:moto_amg/features/auth/presentation/utils/auth_validators.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await ref.read(authActionControllerProvider.notifier).signInWithIdentifier(
          identifier: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authActionControllerProvider);
    final isLoading = action.isLoading;

    ref.listen(authActionControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        },
      );
    });

    return Scaffold(
      backgroundColor: HubStyle.surface,
      body: SafeArea(
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 10),
                  Text(
                    'Entra con correo o con tu usuario. '
                    'Si solo es una ruta, usa una cuenta de invitado.',
                    textAlign: TextAlign.center,
                    style: HubStyle.caption(),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _emailController,
                    enabled: !isLoading,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: HubStyle.inputDecoration(
                      labelText: 'Correo o usuario',
                      hintText: 'tu@email.com o alberto_87',
                    ),
                    validator: AuthValidators.loginIdentifier,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    enabled: !isLoading,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _signIn(),
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
                    validator: AuthValidators.loginPassword,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: HubStyle.textButtonStyle(),
                      onPressed: isLoading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const RecoverAccountScreen(),
                                ),
                              );
                            },
                      child: const Text('He olvidado la contraseña'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FilledButton(
                    style: HubStyle.filledButtonStyle(),
                    onPressed: isLoading ? null : _signIn,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Entrar'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    style: HubStyle.textButtonStyle(),
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RegisterOptionsScreen(),
                              ),
                            );
                          },
                    child: const Text('¿No tienes cuenta? Crear cuenta'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('o', style: HubStyle.caption()),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    style: HubStyle.outlinedButtonStyle(),
                    onPressed: isLoading
                        ? null
                        : () => ref
                            .read(authActionControllerProvider.notifier)
                            .signInWithGoogle(),
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Entrar con Google'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: HubStyle.outlinedButtonStyle(),
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const DisplayNameScreen(),
                              ),
                            );
                          },
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('Entrar como invitado'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Cuenta de invitado: solo un nombre. Al salir se borra todo '
                    'y no se puede recuperar.',
                    textAlign: TextAlign.center,
                    style: HubStyle.caption(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
