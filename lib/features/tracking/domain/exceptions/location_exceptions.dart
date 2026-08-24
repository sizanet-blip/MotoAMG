class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}
