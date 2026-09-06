import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/features/settings/domain/entities/app_update_metadata.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Descarga y compara el JSON de UPDATE_METADATA_URL.
class AppUpdateChecker {
  AppUpdateChecker({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool get isConfigured => AppConstants.updateMetadataUrl.trim().isNotEmpty;

  Future<AppUpdateCheckResult> check() async {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;
    final currentBuild = int.tryParse(info.buildNumber) ?? 0;

    final url = AppConstants.updateMetadataUrl.trim();
    if (url.isEmpty) {
      return AppUpdateCheckResult(
        availability: AppUpdateAvailability.unknown,
        currentVersion: currentVersion,
        currentBuild: currentBuild,
        errorMessage: 'Actualizaciones no configuradas en este build.',
      );
    }

    try {
      final uri = Uri.parse(url);
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AppUpdateCheckResult(
          availability: AppUpdateAvailability.unknown,
          currentVersion: currentVersion,
          currentBuild: currentBuild,
          errorMessage: 'No se pudo consultar la actualización '
              '(HTTP ${response.statusCode}).',
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        return AppUpdateCheckResult(
          availability: AppUpdateAvailability.unknown,
          currentVersion: currentVersion,
          currentBuild: currentBuild,
          errorMessage: 'Respuesta de actualización no válida.',
        );
      }
      final metadata = AppUpdateMetadata.fromJson(decoded);
      final availability = _resolveAvailability(
        currentVersion: currentVersion,
        currentBuild: currentBuild,
        metadata: metadata,
      );
      return AppUpdateCheckResult(
        availability: availability,
        currentVersion: currentVersion,
        currentBuild: currentBuild,
        metadata: metadata,
      );
    } catch (error) {
      return AppUpdateCheckResult(
        availability: AppUpdateAvailability.unknown,
        currentVersion: currentVersion,
        currentBuild: currentBuild,
        errorMessage: 'No se pudo comprobar actualizaciones.',
      );
    }
  }

  AppUpdateAvailability _resolveAvailability({
    required String currentVersion,
    required int currentBuild,
    required AppUpdateMetadata metadata,
  }) {
    final belowMin = metadata.minSupportedVersion.isNotEmpty &&
        _compareVersions(currentVersion, metadata.minSupportedVersion) < 0;
    final newerByBuild = metadata.latestBuild > currentBuild;
    final newerByVersion = metadata.latestVersion.isNotEmpty &&
        _compareVersions(currentVersion, metadata.latestVersion) < 0;
    final hasNewer = newerByBuild || newerByVersion;

    if (!hasNewer && !belowMin) {
      return AppUpdateAvailability.upToDate;
    }
    if (metadata.mandatory || belowMin) {
      return AppUpdateAvailability.mandatory;
    }
    return AppUpdateAvailability.optional;
  }

  /// Compara semver simple `a.b.c`. Negativo si [a] < [b].
  int _compareVersions(String a, String b) {
    List<int> parts(String v) => v
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final pa = parts(a);
    final pb = parts(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) {
        return x.compareTo(y);
      }
    }
    return 0;
  }
}
