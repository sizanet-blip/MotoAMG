import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:moto_amg/features/intercom/domain/entities/intercom_preferences.dart';

class IntercomPreferencesRepository {
  static const _boxName = 'intercom_prefs';
  static const _key = 'prefs';

  Box<String>? _box;

  Future<Box<String>> _open() async {
    _box ??= await Hive.openBox<String>(_boxName);
    return _box!;
  }

  Future<IntercomPreferences> load() async {
    final box = await _open();
    final raw = box.get(_key);
    if (raw == null || raw.isEmpty) {
      return IntercomPreferences.defaults;
    }
    try {
      return IntercomPreferences.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return IntercomPreferences.defaults;
    }
  }

  Future<void> save(IntercomPreferences prefs) async {
    final box = await _open();
    await box.put(_key, jsonEncode(prefs.toJson()));
  }
}
