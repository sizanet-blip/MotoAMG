import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:moto_amg/features/auth/domain/exceptions/auth_exceptions.dart';
import 'package:moto_amg/firebase_options.dart';

class GoogleSignInTokens {
  const GoogleSignInTokens({
    required this.idToken,
    this.email,
    this.displayName,
    this.googleUserId,
  });

  final String idToken;
  final String? email;
  final String? displayName;
  final String? googleUserId;
}

/// Google Sign-In sin Firebase Auth. El panel valida el [idToken].
class GoogleAuthDataSource {
  GoogleAuthDataSource({GoogleSignIn? googleSignIn})
      : _googleSignIn =
            googleSignIn ??
            GoogleSignIn(
              scopes: const ['email', 'profile'],
              clientId: defaultTargetPlatform == TargetPlatform.iOS
                  ? DefaultFirebaseOptions.ios.iosClientId
                  : null,
              serverClientId: DefaultFirebaseOptions.googleWebClientId,
            );

  final GoogleSignIn _googleSignIn;

  String? get currentGoogleUserId => _googleSignIn.currentUser?.id;

  Future<GoogleSignInTokens> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const AuthCancelledException();
      }
      final tokens = await account.authentication;
      final idToken = tokens.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(
          'Google no devolvió idToken. Comprueba el serverClientId (Web client).',
        );
      }
      return GoogleSignInTokens(
        idToken: idToken,
        email: account.email,
        displayName: account.displayName,
        googleUserId: account.id,
      );
    } on AuthCancelledException {
      rethrow;
    } catch (error) {
      if (error is AuthException) rethrow;
      throw AuthException(_mapGoogleError(error));
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  String _mapGoogleError(Object error) {
    final text = error.toString();
    if (text.contains('network_error') || text.contains('NETWORK_ERROR')) {
      return 'Sin conexión con Google. Comprueba la red.';
    }
    return 'No se pudo iniciar sesión con Google.';
  }
}
