import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/clubs/presentation/providers/club_providers.dart';

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
          backgroundColor: HubStyle.surface,
          title: Text('Solicitud enviada', style: HubStyle.sectionTitle()),
          content: Text(
            'Tu solicitud está pendiente de aprobación. '
            'Te avisaremos cuando la peña esté activa.',
            style: HubStyle.body(),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: HubStyle.filledButtonStyle(),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(titleText: 'Solicitar alta de peña'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Text(
            'Enviaremos la solicitud. Cuando la aprueben, podrás invitar a tus socios.',
            style: HubStyle.body(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            enabled: !_busy,
            textCapitalization: TextCapitalization.sentences,
            style: HubStyle.body(color: HubStyle.title),
            decoration: HubStyle.inputDecoration(
              labelText: 'Nombre de la peña',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _regionCtrl,
            enabled: !_busy,
            style: HubStyle.body(color: HubStyle.title),
            decoration: HubStyle.inputDecoration(
              labelText: 'Ciudad o zona (opcional)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            enabled: !_busy,
            keyboardType: TextInputType.phone,
            style: HubStyle.body(color: HubStyle.title),
            decoration: HubStyle.inputDecoration(
              labelText: 'Teléfono de contacto (opcional)',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: HubStyle.caption(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            style: HubStyle.filledButtonStyle(enabled: !_busy),
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Enviar solicitud'),
          ),
        ],
      ),
    );
  }
}
