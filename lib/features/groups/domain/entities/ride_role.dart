/// Rol de marcha en el pelotón (independiente de ser admin).
enum RideRole {
  cabecera,
  cola,
}

extension RideRoleX on RideRole {
  String get label => switch (this) {
        RideRole.cabecera => 'Cabecera',
        RideRole.cola => 'Cola',
      };

  String get firestoreValue => name;

  static RideRole? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    for (final role in RideRole.values) {
      if (role.name == raw) {
        return role;
      }
    }
    return null;
  }
}
