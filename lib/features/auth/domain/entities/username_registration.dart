import 'package:loc_motos/features/auth/domain/entities/app_user.dart';

class UsernameRegistration {
  const UsernameRegistration({
    required this.user,
    required this.recoveryKey,
  });

  final AppUser user;
  final String recoveryKey;
}
