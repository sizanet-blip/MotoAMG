class AuthCancelledException implements Exception {
  const AuthCancelledException();
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
