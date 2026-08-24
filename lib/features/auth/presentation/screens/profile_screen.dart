import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/auth/presentation/providers/auth_providers.dart';
import 'package:loc_motos/features/auth/presentation/utils/auth_validators.dart';
import 'package:loc_motos/features/auth/presentation/widgets/reveal_recovery_key_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _profileKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _year;
  late final TextEditingController _color;
  late final TextEditingController _plate;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  var _obscure = true;

  AppUser get _user {
    final local = ref.watch(signedInUserProvider);
    final remote = ref.watch(authStateProvider).asData?.value;
    return resolveSessionUser(local, remote) ?? widget.user;
  }

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _name = TextEditingController(text: user.displayName);
    _phone = TextEditingController(text: user.phoneNumber ?? '');
    _brand = TextEditingController(text: user.bikeBrand ?? '');
    _model = TextEditingController(text: user.bikeModel ?? '');
    _year = TextEditingController(text: user.bikeYear ?? '');
    _color = TextEditingController(text: user.bikeColor ?? '');
    _plate = TextEditingController(text: user.bikePlate ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _brand.dispose();
    _model.dispose();
    _year.dispose();
    _color.dispose();
    _plate.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String? _blankToNull(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _saveProfile() async {
    if (!_profileKey.currentState!.validate()) {
      return;
    }
    await ref.read(authActionControllerProvider.notifier).updateProfile(
      displayName: _name.text,
      phoneNumber: _blankToNull(_phone.text),
      bikeBrand: _blankToNull(_brand.text),
      bikeModel: _blankToNull(_model.text),
      bikeYear: _blankToNull(_year.text),
      bikeColor: _blankToNull(_color.text),
      bikePlate: _blankToNull(_plate.text)?.toUpperCase(),
    );
    if (!mounted) {
      return;
    }
    if (ref.read(authActionControllerProvider).hasError) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil guardado.')),
    );
  }

  Future<void> _savePassword() async {
    if (!_passwordKey.currentState!.validate()) {
      return;
    }
    await ref.read(authActionControllerProvider.notifier).changePassword(
      currentPassword: _currentPassword.text,
      newPassword: _newPassword.text,
    );
    if (!mounted) {
      return;
    }
    if (ref.read(authActionControllerProvider).hasError) {
      return;
    }
    _currentPassword.clear();
    _newPassword.clear();
    _confirmPassword.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contraseña actualizada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final isLoading = ref.watch(authActionControllerProvider).isLoading;
    final username = user.username?.trim().isNotEmpty == true
        ? user.username!.trim()
        : (user.isUsernameAccount ? user.displayName.trim() : '');

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
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (user.isAnonymous) ...[
            const Card(
              child: ListTile(
                leading: Icon(Icons.badge_outlined),
                title: Text('Cuenta de invitado'),
                subtitle: Text(
                  'Al salir se borra todo, incluida la moto. '
                  'Crea una cuenta para guardarlo.',
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text('Cuenta', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Tipo'),
                  subtitle: Text(_accountType(user)),
                ),
                if (user.email != null && user.email!.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: const Text('Correo'),
                    subtitle: Text(user.email!),
                  ),
                if (username.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.alternate_email),
                    title: const Text('Usuario'),
                    subtitle: Text(username),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Tus datos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Form(
            key: _profileKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !isLoading,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre en el mapa',
                    border: OutlineInputBorder(),
                  ),
                  validator: AuthValidators.displayName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  enabled: !isLoading,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  validator: AuthValidators.optionalPhone,
                ),
                const SizedBox(height: 24),
                Text(
                  'Tu moto',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _brand,
                  enabled: !isLoading,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Marca',
                    hintText: 'Honda, Yamaha, BMW…',
                    border: OutlineInputBorder(),
                  ),
                  validator: AuthValidators.optionalBikeField,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _model,
                  enabled: !isLoading,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Modelo',
                    hintText: 'CB500X, MT-07…',
                    border: OutlineInputBorder(),
                  ),
                  validator: AuthValidators.optionalBikeField,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _year,
                  enabled: !isLoading,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Año',
                    border: OutlineInputBorder(),
                  ),
                  validator: AuthValidators.optionalBikeYear,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _color,
                  enabled: !isLoading,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Color',
                    border: OutlineInputBorder(),
                  ),
                  validator: AuthValidators.optionalBikeField,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _plate,
                  enabled: !isLoading,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Matrícula',
                    border: OutlineInputBorder(),
                  ),
                  validator: AuthValidators.optionalPlate,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: isLoading ? null : _saveProfile,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar perfil'),
                ),
              ],
            ),
          ),
          if (user.canChangePassword) ...[
            const SizedBox(height: 32),
            Text(
              'Contraseña',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Form(
              key: _passwordKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _currentPassword,
                    enabled: !isLoading,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Contraseña actual',
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
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPassword,
                    enabled: !isLoading,
                    obscureText: _obscure,
                    decoration: const InputDecoration(
                      labelText: 'Nueva contraseña',
                      border: OutlineInputBorder(),
                    ),
                    validator: AuthValidators.password,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPassword,
                    enabled: !isLoading,
                    obscureText: _obscure,
                    decoration: const InputDecoration(
                      labelText: 'Repetir contraseña',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => AuthValidators.confirmPassword(
                      value,
                      _newPassword.text,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: isLoading ? null : _savePassword,
                    child: const Text('Cambiar contraseña'),
                  ),
                ],
              ),
            ),
          ],
          if (user.provider == AuthProviderType.google) ...[
            const SizedBox(height: 24),
            Text(
              'Entras con Google. La contraseña se gestiona en esa cuenta.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (username.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () => RevealRecoveryKeyDialog.show(
                      context,
                      username: username,
                    ),
              child: const Text('Ver clave de recuperación'),
            ),
          ],
        ],
      ),
    );
  }

  String _accountType(AppUser user) {
    return switch (user.provider) {
      AuthProviderType.google => 'Google',
      AuthProviderType.email => 'Correo y contraseña',
      AuthProviderType.username => 'Usuario y contraseña',
      AuthProviderType.anonymous => 'Invitado',
    };
  }
}
