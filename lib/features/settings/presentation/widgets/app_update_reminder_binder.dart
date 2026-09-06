import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/features/settings/domain/entities/app_update_metadata.dart';
import 'package:moto_amg/features/settings/presentation/providers/settings_providers.dart';
import 'package:moto_amg/features/settings/presentation/widgets/app_update_dialogs.dart';

/// Al entrar en home, si hay UPDATE_METADATA_URL y una versión nueva, avisa.
class AppUpdateReminderBinder extends ConsumerStatefulWidget {
  const AppUpdateReminderBinder({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppUpdateReminderBinder> createState() =>
      _AppUpdateReminderBinderState();
}

class _AppUpdateReminderBinderState
    extends ConsumerState<AppUpdateReminderBinder> {
  var _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybePrompt());
    });
  }

  Future<void> _maybePrompt() async {
    if (!mounted || _checking) {
      return;
    }
    if (AppConstants.updateMetadataUrl.trim().isEmpty) {
      return;
    }
    if (ref.read(appUpdatePromptShownThisSessionProvider)) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) {
      return;
    }
    if (ref.read(appUpdatePromptShownThisSessionProvider)) {
      return;
    }

    _checking = true;
    try {
      final result = await ref.read(appUpdateCheckerProvider).check();
      if (!mounted || !result.hasUpdate) {
        return;
      }
      ref.read(appUpdatePromptShownThisSessionProvider.notifier).state = true;
      await showAppUpdateDialog(
        context,
        result: result,
        barrierDismissible:
            result.availability != AppUpdateAvailability.mandatory,
      );
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
