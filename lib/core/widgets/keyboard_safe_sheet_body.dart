import 'package:flutter/material.dart';

/// Envuelve el contenido de un bottom sheet para que no desborde en landscape
/// (ni con teclado): altura máxima acotada + scroll.
class KeyboardSafeSheetBody extends StatelessWidget {
  const KeyboardSafeSheetBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.includeViewInsets = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Si true, deja hueco inferior para el teclado (`viewInsets`).
  final bool includeViewInsets;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = includeViewInsets ? mq.viewInsets.bottom : 0.0;
    final maxHeight = (mq.size.height - keyboard - 48).clamp(120.0, mq.size.height);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
