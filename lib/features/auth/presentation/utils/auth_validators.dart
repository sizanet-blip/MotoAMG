import 'package:loc_motos/core/constants/app_constants.dart';

abstract final class AuthValidators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? displayName(String? value) {
    final name = value?.trim() ?? '';
    if (name.length < AppConstants.minDisplayNameLength) {
      return 'Pon al menos ${AppConstants.minDisplayNameLength} letras.';
    }
    if (name.length > AppConstants.maxDisplayNameLength) {
      return 'Máximo ${AppConstants.maxDisplayNameLength} caracteres.';
    }
    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty || !_email.hasMatch(email)) {
      return 'Pon un correo válido.';
    }
    return null;
  }

  static String? username(String? value) {
    final username = (value ?? '').trim();
    if (username.length < AppConstants.minUsernameLength) {
      return 'Mínimo ${AppConstants.minUsernameLength} caracteres.';
    }
    if (username.length > AppConstants.maxUsernameLength) {
      return 'Máximo ${AppConstants.maxUsernameLength} caracteres.';
    }
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(username)) {
      return 'Empieza con letra. Solo letras, números y _.';
    }
    return null;
  }

  static String? loginIdentifier(String? value) {
    final identifier = value?.trim() ?? '';
    if (identifier.isEmpty) {
      return 'Pon tu correo o tu usuario.';
    }
    if (identifier.contains('@')) {
      return email(identifier);
    }
    return username(identifier);
  }

  static String? recoveryKey(String? value) {
    final key = (value ?? '').trim();
    final compact = key.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final body = compact.startsWith('LM') ? compact.substring(2) : compact;
    if (body.length != 16) {
      return 'La clave tiene el formato LM-XXXX-XXXX-XXXX-XXXX.';
    }
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.length < AppConstants.minPasswordLength) {
      return 'Mínimo ${AppConstants.minPasswordLength} caracteres.';
    }
    return null;
  }

  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Pon tu contraseña.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value != password) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }

  static String? optionalPhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) {
      return null;
    }
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) {
      return 'Pon un teléfono válido.';
    }
    return null;
  }

  static String? optionalBikeField(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > AppConstants.maxBikeFieldLength) {
      return 'Máximo ${AppConstants.maxBikeFieldLength} caracteres.';
    }
    return null;
  }

  static String? optionalPlate(String? value) {
    final plate = value?.trim() ?? '';
    if (plate.isEmpty) {
      return null;
    }
    if (plate.length > AppConstants.maxPlateLength) {
      return 'Máximo ${AppConstants.maxPlateLength} caracteres.';
    }
    return null;
  }

  static String? optionalBikeYear(String? value) {
    final yearText = value?.trim() ?? '';
    if (yearText.isEmpty) {
      return null;
    }
    final year = int.tryParse(yearText);
    final maxYear = DateTime.now().year + 1;
    if (year == null || year < 1950 || year > maxYear) {
      return 'Año no válido.';
    }
    return null;
  }
}
