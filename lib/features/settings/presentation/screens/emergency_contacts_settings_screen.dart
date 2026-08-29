import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/settings/data/repositories/emergency_contacts_repository.dart';
import 'package:loc_motos/features/settings/presentation/providers/settings_providers.dart';

/// Configura 1–2 contactos personales (SMS/WhatsApp tras Urgente · 112).
class EmergencyContactsSettingsScreen extends ConsumerStatefulWidget {
  const EmergencyContactsSettingsScreen({super.key});

  @override
  ConsumerState<EmergencyContactsSettingsScreen> createState() =>
      _EmergencyContactsSettingsScreenState();
}

class _EmergencyContactsSettingsScreenState
    extends ConsumerState<EmergencyContactsSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(emergencyContactsProvider);
    final contacts = prefs.contacts;

    return Scaffold(
      appBar: AppBar(title: const Text('Contacto de emergencia')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Personas de fuera del grupo (familia, pareja…). '
            'Tras marcar Urgente · 112 puedes avisarles a mano por SMS o WhatsApp. '
            'No se envía nada solo.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < contacts.length; i++) ...[
            _ContactCard(
              index: i,
              contact: contacts[i],
              onSave: (c) => ref
                  .read(emergencyContactsProvider.notifier)
                  .upsertContact(i, c),
              onDelete: () =>
                  ref.read(emergencyContactsProvider.notifier).removeContact(i),
            ),
            const SizedBox(height: 12),
          ],
          if (contacts.length < EmergencyContactsPreferences.maxContacts)
            OutlinedButton.icon(
              onPressed: () async {
                final created = await _editContact(
                  context,
                  title: 'Nuevo contacto',
                );
                if (created == null || !mounted) {
                  return;
                }
                await ref
                    .read(emergencyContactsProvider.notifier)
                    .upsertContact(contacts.length, created);
              },
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Añadir contacto'),
            ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.index,
    required this.contact,
    required this.onSave,
    required this.onDelete,
  });

  final int index;
  final EmergencyContact contact;
  final Future<void> Function(EmergencyContact contact) onSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final label = contact.name.trim().isEmpty
        ? 'Contacto ${index + 1}'
        : contact.name.trim();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.contact_phone_outlined),
        title: Text(label),
        subtitle: Text(
          contact.phone.trim().isEmpty ? 'Sin teléfono' : contact.phone.trim(),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Editar',
              onPressed: () async {
                final edited = await _editContact(
                  context,
                  title: 'Editar contacto',
                  initial: contact,
                );
                if (edited != null) {
                  await onSave(edited);
                }
              },
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Eliminar',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

Future<EmergencyContact?> _editContact(
  BuildContext context, {
  required String title,
  EmergencyContact? initial,
}) {
  return Navigator.of(context).push<EmergencyContact>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _EditContactPage(title: title, initial: initial),
    ),
  );
}

class _EditContactPage extends StatefulWidget {
  const _EditContactPage({required this.title, this.initial});

  final String title;
  final EmergencyContact? initial;

  @override
  State<_EditContactPage> createState() => _EditContactPageState();
}

class _EditContactPageState extends State<_EditContactPage> {
  late final TextEditingController _name;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _phone = TextEditingController(text: widget.initial?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final contact = EmergencyContact(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
    );
    if (!contact.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pon un nombre y un teléfono válido (mín. 9 dígitos).',
          ),
        ),
      );
      return;
    }
    Navigator.pop(context, contact);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej. María',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  hintText: 'Ej. 600123456 o +34600123456',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submit,
                child: const Text('Guardar'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
