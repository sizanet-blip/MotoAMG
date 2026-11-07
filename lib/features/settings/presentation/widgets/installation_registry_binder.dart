import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/settings/data/services/installation_registry_service.dart';
import 'package:moto_amg/features/settings/presentation/providers/settings_providers.dart';

/// Tras login, registra la instalación en el inventario unificado (panel AMG).
class InstallationRegistryBinder extends ConsumerStatefulWidget {
  const InstallationRegistryBinder({
    super.key,
    required this.user,
    required this.child,
  });

  final AppUser user;
  final Widget child;

  @override
  ConsumerState<InstallationRegistryBinder> createState() =>
      _InstallationRegistryBinderState();
}

class _InstallationRegistryBinderState
    extends ConsumerState<InstallationRegistryBinder> {
  var _syncedUid = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeSync(widget.user));
    });
  }

  @override
  void didUpdateWidget(covariant InstallationRegistryBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      unawaited(_maybeSync(widget.user));
    }
  }

  Future<void> _maybeSync(AppUser user) async {
    if (user.isAnonymous) return;
    if (!InstallationRegistryService.isConfigured) return;
    if (_syncedUid == user.uid) return;
    _syncedUid = user.uid;

    final service = ref.read(installationRegistryServiceProvider);
    await service.syncForUser(
      uid: user.uid,
      email: user.email,
      username: user.username ?? user.uid,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
