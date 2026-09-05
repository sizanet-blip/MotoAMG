import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/core/theme/hub_style.dart';

Future<String?> showCreateGroupDialog(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _CreateGroupPage(),
    ),
  );
}

Future<String?> showJoinGroupDialog(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _JoinGroupPage(),
    ),
  );
}

class _CreateGroupPage extends StatefulWidget {
  const _CreateGroupPage();

  @override
  State<_CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<_CreateGroupPage> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.length < AppConstants.minGroupNameLength) {
      setState(() {
        _error = name.isEmpty
            ? 'Escribe un nombre para el grupo'
            : 'Mínimo ${AppConstants.minGroupNameLength} caracteres';
      });
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(titleText: 'Nuevo grupo'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nombre del grupo', style: HubStyle.sectionTitle()),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_error != null) {
                    setState(() => _error = null);
                  }
                },
                decoration: HubStyle.inputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej. Ruta del domingo',
                ).copyWith(errorText: _error),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: HubStyle.filledButtonStyle(),
                onPressed: _submit,
                child: const Text('Crear'),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: HubStyle.textButtonStyle(),
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

class _JoinGroupPage extends StatefulWidget {
  const _JoinGroupPage();

  @override
  State<_JoinGroupPage> createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<_JoinGroupPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim().toUpperCase();
    if (code.length != AppConstants.groupCodeLength) {
      return;
    }
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(titleText: 'Unirme a un grupo'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Código del grupo', style: HubStyle.sectionTitle()),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                maxLength: AppConstants.groupCodeLength,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  UpperCaseTextFormatter(),
                ],
                decoration: HubStyle.inputDecoration(
                  labelText: 'Código',
                  hintText: 'Ej. K7M2PQ',
                ).copyWith(counterText: ''),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: HubStyle.filledButtonStyle(),
                onPressed: _submit,
                child: const Text('Unirme'),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: HubStyle.textButtonStyle(),
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

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
