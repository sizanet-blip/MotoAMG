import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/auth/presentation/providers/auth_providers.dart';
import 'package:loc_motos/features/clubs/presentation/providers/club_providers.dart';

class RegisterClubScreen extends ConsumerStatefulWidget {
  const RegisterClubScreen({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<RegisterClubScreen> createState() => _RegisterClubScreenState();
}

class _RegisterClubScreenState extends ConsumerState<RegisterClubScreen> {
  final _nameCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _regionCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.length < AppConstants.minClubNameLength) {
      setState(
        () => _error =
            'El nombre debe tener al menos ${AppConstants.minClubNameLength} caracteres.',
      );
      return;
    }
    if (name.length > AppConstants.maxClubNameLength) {
      setState(() => _error = 'Nombre demasiado largo.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final requestId =
          await ref.read(clubRemoteDataSourceProvider).submitClubRequest(
                uid: widget.user.uid,
                displayName: widget.user.displayName,
                clubName: name,
                email: widget.user.email,
                phone: _phoneCtrl.text.trim().isEmpty
                    ? widget.user.phoneNumber
                    : _phoneCtrl.text.trim(),
                region: _regionCtrl.text.trim(),
              );
      final local = ref.read(signedInUserProvider);
      if (local != null && local.uid == widget.user.uid) {
        ref.read(signedInUserProvider.notifier).state = local.copyWith(
          pendingClubRequestId: requestId,
          clearCurrentClubId: true,
        );
      }
      ref.read(dismissedPendingClubRequestIdProvider.notifier).state = null;
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Solicitud enviada'),
          content: const Text(
            'Tu solicitud está pendiente de aprobación. '
            'Te avisaremos cuando el club esté activo.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = 'No se pudo enviar la solicitud.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar mi club')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Text(
            'Enviaremos la solicitud. Cuando la aprueben, podrás invitar a tus socios.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            enabled: !_busy,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre del club',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _regionCtrl,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Ciudad o zona (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            enabled: !_busy,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono de contacto (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar solicitud'),
          ),
        ],
      ),
    );
  }
}
