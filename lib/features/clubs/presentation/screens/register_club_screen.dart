import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/auth/data/repositories/mysql_auth_repository_impl.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/clubs/presentation/providers/club_providers.dart';

/// Envía solicitud de club; queda pendiente hasta aprobarla en el panel.
class RegisterClubScreen extends ConsumerStatefulWidget {
  const RegisterClubScreen({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<RegisterClubScreen> createState() => _RegisterClubScreenState();
}

class _RegisterClubScreenState extends ConsumerState<RegisterClubScreen> {
  final _nameCtrl = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
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
      final requestId = await ref.read(clubRemoteDataSourceProvider).submitClubRequest(
            uid: widget.user.uid,
            displayName: widget.user.displayName,
            clubName: name,
            email: widget.user.email,
          );
      final repo = ref.read(authRepositoryProvider);
      if (repo is MysqlAuthRepositoryImpl) {
        await repo.patchLocalUser(
          (current) => current.copyWith(
            pendingClubRequestId: requestId,
            currentClubId: null,
            clearCurrentClubId: true,
          ),
        );
      }
      final local = ref.read(signedInUserProvider);
      if (local != null && local.uid == widget.user.uid) {
        ref.read(signedInUserProvider.notifier).state = local.copyWith(
          pendingClubRequestId: requestId,
          clearCurrentClubId: true,
        );
      }
      ref.invalidate(myClubMembershipsProvider);
      ref.invalidate(pendingClubRequestProvider);
      if (!mounted) {
        return;
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(titleText: 'Crear club'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Text(
            'Se enviará una solicitud al panel. Cuando la aprueben, '
            'el club quedará activo y podrás usarlo.',
            style: HubStyle.body(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            enabled: !_busy,
            textCapitalization: TextCapitalization.sentences,
            style: HubStyle.body(color: HubStyle.title),
            decoration: HubStyle.inputDecoration(
              labelText: 'Nombre del club',
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
