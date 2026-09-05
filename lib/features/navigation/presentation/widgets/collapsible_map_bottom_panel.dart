import 'package:flutter/material.dart';
import 'package:moto_amg/core/theme/hub_style.dart';

/// Panel inferior sobre el mapa que se puede ocultar y mostrar.
///
/// Mismo comportamiento en vertical y horizontal: toca la cabecera o la
/// flecha para alternar. Al girar a horizontal se pliega solo si estaba abierto.
class CollapsibleMapBottomPanel extends StatefulWidget {
  const CollapsibleMapBottomPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.initiallyExpanded,
    this.maxExpandedHeight,
    this.autoCollapseOnLandscape = true,
    this.sidePanel = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// Si es null, abierto en vertical y cerrado en horizontal.
  final bool? initiallyExpanded;

  /// Limita la altura del contenido expandido (p. ej. vista previa con scroll).
  final double? maxExpandedHeight;

  final bool autoCollapseOnLandscape;

  /// Panel fijo a un lateral (p. ej. itinerario en horizontal): ocupa toda la altura
  /// del padre y el contenido expandido hace scroll dentro.
  final bool sidePanel;

  @override
  State<CollapsibleMapBottomPanel> createState() =>
      _CollapsibleMapBottomPanelState();
}

class _CollapsibleMapBottomPanelState extends State<CollapsibleMapBottomPanel> {
  late bool _expanded;
  Orientation? _lastOrientation;
  var _orientationInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.initiallyExpanded != null) {
      _expanded = widget.initiallyExpanded!;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.orientationOf(context);

    if (!_orientationInitialized) {
      _orientationInitialized = true;
      if (widget.initiallyExpanded == null) {
        _expanded = widget.sidePanel ||
            orientation == Orientation.portrait;
      }
      _lastOrientation = orientation;
      return;
    }

    if (widget.autoCollapseOnLandscape &&
        !widget.sidePanel &&
        _lastOrientation != orientation &&
        orientation == Orientation.landscape &&
        _expanded) {
      _expanded = false;
    }
    _lastOrientation = orientation;
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  BorderRadius get _panelRadius => widget.sidePanel
      ? const BorderRadius.horizontal(right: Radius.circular(20))
      : const BorderRadius.vertical(top: Radius.circular(20));

  Widget _buildHeader(BuildContext context, ColorScheme colors) {
    return InkWell(
      onTap: _toggle,
      borderRadius: _panelRadius,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          widget.sidePanel ? 12 : 10,
          4,
          widget.sidePanel ? 8 : 10,
        ),
        child: Column(
          children: [
            if (!widget.sidePanel)
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            if (!widget.sidePanel) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: HubStyle.sectionTitle()),
                      if (!_expanded && widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          maxLines: widget.sidePanel ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: HubStyle.caption(),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _expanded ? 'Ocultar panel' : 'Mostrar panel',
                  onPressed: _toggle,
                  icon: Icon(
                    widget.sidePanel
                        ? (_expanded
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded)
                        : (_expanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedBody() {
    if (widget.sidePanel) {
      return Expanded(
        child: SingleChildScrollView(
          child: widget.child,
        ),
      );
    }

    return ClipRect(
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        heightFactor: _expanded ? 1 : 0,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: widget.maxExpandedHeight ?? double.infinity,
          ),
          child: widget.child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      elevation: 10,
      color: isDark ? colors.surface : HubStyle.surface,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: _panelRadius,
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: widget.sidePanel,
        bottom: !widget.sidePanel,
        left: widget.sidePanel,
        right: false,
        child: widget.sidePanel
            ? LayoutBuilder(
                builder: (context, constraints) {
                  // Si el alto es muy justo (teclado), todo el panel hace scroll.
                  final tight = constraints.maxHeight < 120;
                  if (tight) {
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(context, colors),
                          if (_expanded) widget.child,
                        ],
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context, colors),
                      if (_expanded) _buildExpandedBody(),
                    ],
                  );
                },
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context, colors),
                  _buildExpandedBody(),
                ],
              ),
      ),
    );
  }
}
