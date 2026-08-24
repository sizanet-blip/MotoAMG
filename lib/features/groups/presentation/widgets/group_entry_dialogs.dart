import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loc_motos/core/constants/app_constants.dart';

class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key, required this.defaultName});

  final String defaultName;

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.defaultName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nombre del grupo'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Ej. Ruta del domingo',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.length < AppConstants.minGroupNameLength) {
              return;
            }
            Navigator.pop(context, name);
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

class JoinGroupDialog extends StatefulWidget {
  const JoinGroupDialog({super.key});

  @override
  State<JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends State<JoinGroupDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Código del grupo'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        maxLength: AppConstants.groupCodeLength,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          UpperCaseTextFormatter(),
        ],
        decoration: const InputDecoration(
          hintText: 'Ej. K7M2PQ',
          border: OutlineInputBorder(),
          counterText: '',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final code = _controller.text.trim().toUpperCase();
            if (code.length != AppConstants.groupCodeLength) {
              return;
            }
            Navigator.pop(context, code);
          },
          child: const Text('Unirme'),
        ),
      ],
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
