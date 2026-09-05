import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/clubs/presentation/providers/club_providers.dart';

class JoinClubScreen extends ConsumerStatefulWidget {
  const JoinClubScreen({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<JoinClubScreen> createState() => _JoinClubScreenState();
}

class _JoinClubScreenState extends ConsumerState<JoinClubScreen> {
  final _codeCtrl = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Introduce el código de invitación.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final club = await ref.read(clubRemoteDataSourceProvider).joinWithInviteCode(
            uid: widget.user.uid,
            displayName: widget.user.displayName,
            rawCode: code,
          );
      if (!mounted) {
        return;
      }
      final local = ref.read(signedInUserProvider);
      if (local != null && local.uid == widget.user.uid) {
        ref.read(signedInUserProvider.notifier).state = local.copyWith(
          currentClubId: club.id,
          clearPendingClubRequestId: true,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Te has unido a ${club.name}')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = e is StateError ? e.message : 'No se pudo unir al club.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unirme a un club')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Text(
            'Usa el enlace que te han mandado o escribe el código.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeCtrl,
            enabled: !_busy,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Código de invitación',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _busy ? null : _join(),
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
            onPressed: _busy ? null : _join,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Unirme'),
          ),
        ],
      ),
    );
  }
}
