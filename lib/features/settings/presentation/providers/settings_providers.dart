import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/settings/data/repositories/emergency_contacts_repository.dart';

final emergencyContactsRepositoryProvider =
    Provider<EmergencyContactsRepository>((ref) {
  return EmergencyContactsRepository();
});

final emergencyContactsProvider = NotifierProvider<EmergencyContactsController,
    EmergencyContactsPreferences>(
  EmergencyContactsController.new,
);

class EmergencyContactsController
    extends Notifier<EmergencyContactsPreferences> {
  @override
  EmergencyContactsPreferences build() {
    Future.microtask(_hydrate);
    return EmergencyContactsPreferences.defaults;
  }

  Future<void> _hydrate() async {
    final loaded =
        await ref.read(emergencyContactsRepositoryProvider).load();
    state = loaded;
  }

  Future<void> _persist(EmergencyContactsPreferences next) async {
    state = next;
    await ref.read(emergencyContactsRepositoryProvider).save(next);
  }

  Future<void> setContacts(List<EmergencyContact> contacts) {
    final capped = contacts.length > EmergencyContactsPreferences.maxContacts
        ? contacts.sublist(0, EmergencyContactsPreferences.maxContacts)
        : List<EmergencyContact>.from(contacts);
    return _persist(state.copyWith(contacts: capped));
  }

  Future<void> upsertContact(int index, EmergencyContact contact) {
    final list = List<EmergencyContact>.from(state.contacts);
    if (index >= 0 && index < list.length) {
      list[index] = contact;
    } else if (list.length < EmergencyContactsPreferences.maxContacts) {
      list.add(contact);
    }
    return setContacts(list);
  }

  Future<void> removeContact(int index) {
    final list = List<EmergencyContact>.from(state.contacts);
    if (index < 0 || index >= list.length) {
      return Future.value();
    }
    list.removeAt(index);
    return setContacts(list);
  }
}
