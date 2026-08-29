class IntercomTokenCredentials {
  const IntercomTokenCredentials({
    required this.url,
    required this.token,
    required this.room,
  });

  final String url;
  final String token;
  final String room;
}

class IntercomTokenException implements Exception {
  IntercomTokenException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
