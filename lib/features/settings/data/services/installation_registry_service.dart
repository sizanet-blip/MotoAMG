import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Ping de instalación al inventario unificado del panel AMG.
///
/// Build: `--dart-define=INSTALLATION_API_URL=https://…`
/// (también acepta `LICENSE_API_URL`).
class InstallationRegistryService {
  InstallationRegistryService();

  static const String _boxName = 'amg_installation';
  static const String _kDeviceId = 'device_id';
  static const String _kLicenseKey = 'license_key';
  static const String _kLastUid = 'last_uid';

  Box<String>? _box;

  Future<Box<String>> _open() async {
    return _box ??= await Hive.openBox<String>(_boxName);
  }

  static bool get isConfigured =>
      AppConstants.installationApiUrl.trim().isNotEmpty;

  Future<String> deviceId() async {
    final box = await _open();
    final existing = box.get(_kDeviceId)?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _generateDeviceId();
    await box.put(_kDeviceId, generated);
    return generated;
  }

  /// Registra / actualiza la instalación; si hay email o username, identifica.
  Future<void> syncForUser({
    required String uid,
    String? email,
    String? username,
  }) async {
    if (!isConfigured) return;

    try {
      final package = await PackageInfo.fromPlatform();
      final id = await deviceId();
      final mail = email?.trim() ?? '';
      final user = username?.trim() ?? '';

      final body = <String, dynamic>{
        'device_id': id,
        'app_name': AppConstants.appName,
        'platform': _platformKey,
        'app_version': package.version,
        'build_number': package.buildNumber,
        if (mail.isNotEmpty) 'email': mail,
        if (user.isNotEmpty) 'username': user,
        // Referencia al uid de Moto (panel de clubs); no sustituye email.
        'notes_hint': 'moto_uid:$uid',
      };

      final response = await _postJson('/installations/register', body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[Installation] register HTTP ${response.statusCode}: ${response.body}',
        );
        return;
      }

      final box = await _open();
      try {
        final data = jsonDecode(response.body);
        if (data is Map) {
          final license = data['license'];
          if (license is Map) {
            final key = (license['license_key'] ?? '').toString().trim();
            if (key.isNotEmpty) await box.put(_kLicenseKey, key);
          }
        }
      } catch (_) {}
      await box.put(_kLastUid, uid);
      debugPrint('[Installation] sync OK para $uid');
    } catch (e, st) {
      debugPrint('[Installation] sync falló: $e\n$st');
    }
  }

  Future<http.Response> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final base = AppConstants.installationApiUrl.trim().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final uri = Uri.parse('$base$path');
    return http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
  }

  String _generateDeviceId() {
    final rnd = Random.secure();
    final randomPart =
        List.generate(24, (_) => rnd.nextInt(16).toRadixString(16)).join();
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    return 'mamg-$ts-$randomPart';
  }

  String get _platformKey {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
