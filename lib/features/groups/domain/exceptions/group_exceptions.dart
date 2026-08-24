class GroupException implements Exception {
  const GroupException(this.message);

  final String message;

  @override
  String toString() => message;
}
