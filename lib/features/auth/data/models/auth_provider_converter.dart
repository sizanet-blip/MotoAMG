import 'package:json_annotation/json_annotation.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';

class AuthProviderTypeConverter
    implements JsonConverter<AuthProviderType, String> {
  const AuthProviderTypeConverter();

  @override
  AuthProviderType fromJson(String json) {
    return switch (json) {
      'google' => AuthProviderType.google,
      'email' => AuthProviderType.email,
      'username' => AuthProviderType.username,
      _ => AuthProviderType.anonymous,
    };
  }

  @override
  String toJson(AuthProviderType object) {
    return switch (object) {
      AuthProviderType.google => 'google',
      AuthProviderType.email => 'email',
      AuthProviderType.username => 'username',
      AuthProviderType.anonymous => 'anonymous',
    };
  }
}
