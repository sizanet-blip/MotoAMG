/// Metadatos remotos de actualización (JSON en UPDATE_METADATA_URL).
class AppUpdateMetadata {
  const AppUpdateMetadata({
    required this.latestVersion,
    required this.latestBuild,
    required this.minSupportedVersion,
    required this.mandatory,
    required this.changelog,
    required this.androidDownloadUrl,
  });

  final String latestVersion;
  final int latestBuild;
  final String minSupportedVersion;
  final bool mandatory;
  final List<String> changelog;
  final String? androidDownloadUrl;

  factory AppUpdateMetadata.fromJson(Map<String, dynamic> json) {
    final downloads = json['downloads'];
    String? androidUrl;
    if (downloads is Map) {
      final android = downloads['android'];
      if (android is Map) {
        final url = android['url'];
        if (url is String && url.trim().isNotEmpty) {
          androidUrl = url.trim();
        }
      }
    }
    final changelogRaw = json['changelog'];
    final changelog = <String>[];
    if (changelogRaw is List) {
      for (final item in changelogRaw) {
        if (item is String && item.trim().isNotEmpty) {
          changelog.add(item.trim());
        }
      }
    }
    return AppUpdateMetadata(
      latestVersion: (json['latestVersion'] as String? ?? '').trim(),
      latestBuild: (json['latestBuild'] as num?)?.toInt() ?? 0,
      minSupportedVersion:
          (json['minSupportedVersion'] as String? ?? '').trim(),
      mandatory: json['mandatory'] == true,
      changelog: changelog,
      androidDownloadUrl: androidUrl,
    );
  }
}

/// Resultado de comparar la app instalada con el JSON remoto.
enum AppUpdateAvailability {
  /// No hay URL configurada o no se pudo comprobar.
  unknown,

  /// Ya estás en la última (o más nueva).
  upToDate,

  /// Hay una versión nueva recomendada.
  optional,

  /// Debes actualizar (mandatory o por debajo de minSupported).
  mandatory,
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.availability,
    required this.currentVersion,
    required this.currentBuild,
    this.metadata,
    this.errorMessage,
  });

  final AppUpdateAvailability availability;
  final String currentVersion;
  final int currentBuild;
  final AppUpdateMetadata? metadata;
  final String? errorMessage;

  bool get hasUpdate =>
      availability == AppUpdateAvailability.optional ||
      availability == AppUpdateAvailability.mandatory;

  String? get downloadUrl => metadata?.androidDownloadUrl;
}
