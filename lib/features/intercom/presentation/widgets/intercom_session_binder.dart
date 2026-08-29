import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/groups/presentation/providers/group_providers.dart';
import 'package:loc_motos/features/intercom/presentation/providers/intercom_providers.dart';

/// Mantiene la sesión de intercom mientras el mapa o el HUD están montados.
///
/// Se conecta solo si el creador tiene el intercom del grupo activado.
class IntercomSessionBinder extends ConsumerStatefulWidget {
  const IntercomSessionBinder({
    super.key,
    required this.groupId,
    required this.child,
  });

  final String groupId;
  final Widget child;

  @override
  ConsumerState<IntercomSessionBinder> createState() =>
      _IntercomSessionBinderState();
}

class _IntercomSessionBinderState extends ConsumerState<IntercomSessionBinder> {
  ProviderContainer? _container;
  var _retained = false;
  var _syncedIntercom = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container ??= ProviderScope.containerOf(context);
    if (!_retained) {
      _retained = true;
      unawaited(
        _container!
            .read(intercomSessionProvider.notifier)
            .retainHost(groupId: widget.groupId),
      );
    }
  }

  @override
  void didUpdateWidget(covariant IntercomSessionBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId == widget.groupId) {
      return;
    }
    _syncedIntercom = false;
    final container = _container;
    if (container == null) {
      return;
    }
    unawaited(() async {
      await container.read(intercomSessionProvider.notifier).releaseHost();
      await container
          .read(intercomSessionProvider.notifier)
          .retainHost(groupId: widget.groupId);
    }());
  }

  @override
  void dispose() {
    if (_retained) {
      final container = _container;
      if (container != null) {
        unawaited(container.read(intercomSessionProvider.notifier).releaseHost());
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        ref.watch(rideGroupProvider(widget.groupId)).valueOrNull?.intercomEnabled ??
            false;

    ref.listen(rideGroupProvider(widget.groupId), (previous, next) {
      final wasOn = previous?.valueOrNull?.intercomEnabled ?? false;
      final isOn = next.valueOrNull?.intercomEnabled ?? false;
      if (wasOn == isOn) {
        return;
      }
      unawaited(
        ref.read(intercomSessionProvider.notifier).setDesiredActive(isOn),
      );
    });

    if (!_syncedIntercom) {
      _syncedIntercom = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(
          ref.read(intercomSessionProvider.notifier).setDesiredActive(enabled),
        );
      });
    }

    return widget.child;
  }
}
