import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/groups/presentation/providers/group_providers.dart';
import 'package:loc_motos/features/intercom/domain/entities/intercom_session_state.dart';
import 'package:loc_motos/features/intercom/presentation/providers/intercom_providers.dart';

/// Solo Hablar / Oír (+ estado mínimo). El ON/OFF lo marca el creador del grupo.
class IntercomControlsBar extends ConsumerWidget {
  const IntercomControlsBar({
    super.key,
    required this.groupId,
    this.compact = false,
    this.dark = false,
  });

  final String groupId;
  final bool compact;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(rideGroupProvider(groupId)).valueOrNull;
    if (group == null || !group.intercomEnabled) {
      return const SizedBox.shrink();
    }

    final session = ref.watch(intercomSessionProvider);
    final colors = Theme.of(context).colorScheme;
    final bg = dark
        ? Colors.black.withValues(alpha: 0.55)
        : colors.surface.withValues(alpha: 0.92);
    final fg = dark ? Colors.white : colors.onSurface;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      elevation: dark ? 0 : 1,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 6 : 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  _statusIcon(session.status),
                  size: 16,
                  color: _statusColor(session.status, colors, dark),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    session.isConnected
                        ? (session.remoteSpeakerNames.isNotEmpty
                            ? 'Habla: ${session.remoteSpeakerNames.join(', ')}'
                            : 'Intercom')
                        : session.statusLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (session.localTransmitting)
                  Icon(
                    Icons.graphic_eq,
                    size: 16,
                    color: dark ? const Color(0xFF69F0AE) : colors.primary,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _MuteChip(
                    selected: session.speakEnabled,
                    icon: session.speakEnabled ? Icons.mic : Icons.mic_off,
                    label: 'Hablar',
                    dark: dark,
                    onTap: () => unawaited(
                      ref
                          .read(intercomSessionProvider.notifier)
                          .setSpeakEnabled(!session.speakEnabled),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MuteChip(
                    selected: session.listenEnabled,
                    icon: session.listenEnabled
                        ? Icons.volume_up
                        : Icons.volume_off,
                    label: 'Oír',
                    dark: dark,
                    onTap: () => unawaited(
                      ref
                          .read(intercomSessionProvider.notifier)
                          .setListenEnabled(!session.listenEnabled),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(IntercomConnectionStatus status) {
    return switch (status) {
      IntercomConnectionStatus.idle => Icons.headset_off_outlined,
      IntercomConnectionStatus.connecting => Icons.sync,
      IntercomConnectionStatus.connected => Icons.headset_mic,
      IntercomConnectionStatus.reconnecting => Icons.sync_problem,
      IntercomConnectionStatus.unavailable => Icons.signal_wifi_off,
      IntercomConnectionStatus.error => Icons.error_outline,
    };
  }

  Color _statusColor(
    IntercomConnectionStatus status,
    ColorScheme colors,
    bool dark,
  ) {
    return switch (status) {
      IntercomConnectionStatus.connected =>
        dark ? const Color(0xFF69F0AE) : colors.primary,
      IntercomConnectionStatus.error ||
      IntercomConnectionStatus.unavailable =>
        dark ? const Color(0xFFFF8A80) : colors.error,
      IntercomConnectionStatus.connecting ||
      IntercomConnectionStatus.reconnecting =>
        dark ? const Color(0xFFFFD54F) : colors.tertiary,
      IntercomConnectionStatus.idle =>
        dark ? Colors.white70 : colors.onSurfaceVariant,
    };
  }
}

class _MuteChip extends StatelessWidget {
  const _MuteChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.dark,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final selectedBg = dark
        ? Colors.white.withValues(alpha: 0.18)
        : Theme.of(context).colorScheme.primaryContainer;
    final unselectedBg = dark
        ? Colors.white.withValues(alpha: 0.08)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final fg = dark
        ? Colors.white
        : (selected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface);

    return Material(
      color: selected ? selectedBg : unselectedBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
