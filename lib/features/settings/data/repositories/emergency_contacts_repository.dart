import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:hive_flutter/hive_flutter.dart';

class EmergencyContact extends Equatable {
  const EmergencyContact({
    required this.name,
    required this.phone,
  });

  final String name;
  final String phone;

  bool get isValid {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return name.trim().isNotEmpty && digits.length >= 9;
  }

  /// Dígitos internacionales sin + ni espacios (para wa.me / sms).
  String get phoneDigits {
    var raw = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (raw.startsWith('+')) {
      raw = raw.substring(1);
    }
    // España sin prefijo: asumir 34 si son 9 dígitos.
    if (raw.length == 9 && RegExp(r'^[6-9]').hasMatch(raw)) {
      return '34$raw';
    }
    return raw;
  }

  EmergencyContact copyWith({String? name, String? phone}) {
    return EmergencyContact(
      name: name ?? this.name,
      phone: phone ?? this.phone,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: (json['name'] as String?)?.trim() ?? '',
      phone: (json['phone'] as String?)?.trim() ?? '',
    );
  }

  @override
  List<Object?> get props => [name, phone];
}

class EmergencyContactsPreferences extends Equatable {
  const EmergencyContactsPreferences({
    this.contacts = const [],
  });

  static const defaults = EmergencyContactsPreferences();
  static const maxContacts = 2;

  final List<EmergencyContact> contacts;

  List<EmergencyContact> get validContacts =>
      contacts.where((c) => c.isValid).toList();

  EmergencyContactsPreferences copyWith({List<EmergencyContact>? contacts}) {
    return EmergencyContactsPreferences(
      contacts: contacts ?? this.contacts,
    );
  }

  Map<String, dynamic> toJson() => {
        'contacts': contacts.map((c) => c.toJson()).toList(),
      };

  factory EmergencyContactsPreferences.fromJson(Map<String, dynamic> json) {
    final raw = json['contacts'];
    if (raw is! List) {
      return EmergencyContactsPreferences.defaults;
    }
    final list = <EmergencyContact>[];
    for (final item in raw) {
      if (item is Map) {
        list.add(
          EmergencyContact.fromJson(Map<String, dynamic>.from(item)),
        );
      }
      if (list.length >= maxContacts) {
        break;
      }
    }
    return EmergencyContactsPreferences(contacts: list);
  }

  @override
  List<Object?> get props => [contacts];
}

class EmergencyContactsRepository {
  static const _boxName = 'emergency_contacts';
  static const _key = 'prefs_v1';

  Box<String>? _box;

  Future<Box<String>> _open() async {
    _box ??= await Hive.openBox<String>(_boxName);
    return _box!;
  }

  Future<EmergencyContactsPreferences> load() async {
    final box = await _open();
    final raw = box.get(_key);
    if (raw == null || raw.isEmpty) {
      return EmergencyContactsPreferences.defaults;
    }
    try {
      return EmergencyContactsPreferences.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return EmergencyContactsPreferences.defaults;
    }
  }

  Future<void> save(EmergencyContactsPreferences prefs) async {
    final box = await _open();
    await box.put(_key, jsonEncode(prefs.toJson()));
  }
}
