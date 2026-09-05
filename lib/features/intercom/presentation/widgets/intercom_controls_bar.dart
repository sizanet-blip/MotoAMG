import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/groups/presentation/providers/group_providers.dart';
import 'package:moto_amg/features/intercom/domain/entities/intercom_session_state.dart';
import 'package:moto_amg/features/intercom/presentation/providers/intercom_providers.dart';

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
        : HubStyle.surface.withValues(alpha: 0.97);
    final fg = dark ? Colors.white : HubStyle.title;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      elevation: dark ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: 0.12),
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
                    style: HubStyle.caption(color: fg).copyWith(
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
                    color: dark ? const Color(0xFF69F0AE) : HubStyle.accent,
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
        dark ? const Color(0xFF69F0AE) : HubStyle.accent,
      IntercomConnectionStatus.error ||
      IntercomConnectionStatus.unavailable =>
        dark ? const Color(0xFFFF8A80) : colors.error,
      IntercomConnectionStatus.connecting ||
      IntercomConnectionStatus.reconnecting =>
        dark ? const Color(0xFFFFD54F) : const Color(0xFFB45309),
      IntercomConnectionStatus.idle =>
        dark ? Colors.white70 : HubStyle.subtitle,
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
        : HubStyle.accent.withValues(alpha: 0.14);
    final unselectedBg = dark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFF3F4F6);
    final fg = dark
        ? Colors.white
        : (selected ? HubStyle.accent : HubStyle.subtitle);

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
                style: HubStyle.body(color: fg).copyWith(
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
