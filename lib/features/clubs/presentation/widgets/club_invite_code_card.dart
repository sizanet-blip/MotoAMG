import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Código de invitación del club (copiar / compartir / QR).
class ClubInviteCodeCard extends StatelessWidget {
  const ClubInviteCodeCard({
    super.key,
    required this.code,
    required this.clubName,
    this.compact = false,
  });

  final String code;
  final String clubName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shareText =
        'Únete a mi club «$clubName» en MotoAMG.\nCódigo: $code';
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : HubStyle.cardShadow,
      ),
      child: Material(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Código del club', style: HubStyle.caption()),
              const SizedBox(height: 8),
              Text(
                code,
                textAlign: TextAlign.center,
                style: HubStyle.headline(color: HubStyle.accent).copyWith(
                  letterSpacing: 4,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 16),
                Center(
                  child: QrImageView(
                    data: code,
                    version: QrVersions.auto,
                    size: 160,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Compártelo para que otros se unan al club con este código.',
                  textAlign: TextAlign.center,
                  style: HubStyle.caption(),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'Compártelo para que otros se unan al club.',
                  textAlign: TextAlign.center,
                  style: HubStyle.caption(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Código copiado')),
                          );
                        }
                      },
                      style: HubStyle.outlinedButtonStyle(),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(text: shareText),
                      ),
                      style: HubStyle.filledButtonStyle(),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Compartir'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
