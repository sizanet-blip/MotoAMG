import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/constants/navigation_constants.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/navigation/domain/entities/geocoding_place.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/domain/exceptions/navigation_exceptions.dart';
import 'package:moto_amg/features/navigation/domain/exceptions/navigation_user_message.dart';
import 'package:moto_amg/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:moto_amg/features/tracking/presentation/providers/tracking_providers.dart';

class DestinationSearchField extends ConsumerStatefulWidget {
  const DestinationSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSelected,
    this.onEdited,
    this.labelText = '¿A dónde vas?',
    this.hintText = 'Calle, número, ciudad',
    this.prefixIcon = Icons.location_on_outlined,
    this.exampleHint =
        'Escribe calle, número y ciudad. Ej.: Calle Previsión Social 9, Zaragoza',
    this.selectedPlace,
    this.onUseGps,
    this.isFavorite,
    this.onToggleFavorite,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final ValueChanged<GeocodingPlace> onSelected;
  final VoidCallback? onEdited;
  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final String exampleHint;
  final GeocodingPlace? selectedPlace;
  final VoidCallback? onUseGps;

  /// Si se define junto a [onToggleFavorite], muestra estrella en sugerencias.
  final bool Function(GeocodingPlace place)? isFavorite;
  final ValueChanged<GeocodingPlace>? onToggleFavorite;

  @override
  ConsumerState<DestinationSearchField> createState() =>
      _DestinationSearchFieldState();
}

class _DestinationSearchFieldState extends ConsumerState<DestinationSearchField> {
  static const _maxSuggestions = 4;

  Timer? _debounce;
  var _searching = false;
  var _error = '';
  List<GeocodingPlace> _suggestions = const [];
  GeocodingPlace? _selected;
  var _focused = false;
  var _ignoreQueryListener = false;
  var _searchGeneration = 0;

  TextEditingController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedPlace;
    if (widget.selectedPlace != null) {
      _setQueryText(widget.selectedPlace!.displayLine, notify: false);
    }
    _controller.addListener(_onQueryChanged);
    widget.focusNode.addListener(_onFocusChanged);
    _focused = widget.focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(DestinationSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPlace != oldWidget.selectedPlace &&
        widget.selectedPlace != _selected) {
      final place = widget.selectedPlace;
      if (place != null) {
        _setQueryText(place.displayLine, notify: false);
      }
      setState(() {
        _selected = place;
        if (place != null) {
          _suggestions = const [];
          _error = '';
        }
      });
    }
  }

  void _setQueryText(String text, {required bool notify}) {
    _ignoreQueryListener = true;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _ignoreQueryListener = false;
    if (notify) {
      widget.onEdited?.call();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    final focused = widget.focusNode.hasFocus;
    if (_focused == focused) {
      return;
    }
    setState(() => _focused = focused);
  }

  GeoPoint? get _biasPoint {
    final own = ref.read(ownDevicePositionProvider);
    if (own == null) {
      return null;
    }
    return GeoPoint(lat: own.lat, lng: own.lng);
  }

  /// Mantiene sugerencias visibles mientras llega la siguiente búsqueda.
  bool get _showSuggestions =>
      _selected == null && _suggestions.isNotEmpty;

  void _onQueryChanged() {
    if (_ignoreQueryListener) {
      return;
    }
    if (_selected != null) {
      setState(() => _selected = null);
      widget.onEdited?.call();
    }
    _debounce?.cancel();
    final query = _controller.text.trim();
    if (query.length < 3) {
      _searchGeneration++;
      setState(() {
        _suggestions = const [];
        _error = '';
        _searching = false;
      });
      return;
    }
    // Feedback inmediato: el spinner aparece sin esperar al debounce.
    if (!_searching) {
      setState(() {
        _searching = true;
        _error = '';
      });
    }
    _debounce = Timer(NavigationConstants.geocodingSearchDebounce, () {
      unawaited(_runSearch(query));
    });
  }

  Future<void> _runSearch(String query, {bool thorough = false}) async {
    if (!mounted) {
      return;
    }
    final generation = ++_searchGeneration;
    setState(() {
      _searching = true;
      _error = '';
    });
    try {
      final repo = ref.read(geocodingRepositoryProvider);
      var results = await repo.searchAddresses(
        query,
        near: _biasPoint,
        thorough: thorough,
      );
      // Si no hay nada, una pasada completa (solo entonces).
      if (!thorough && results.isEmpty && generation == _searchGeneration) {
        results = await repo.searchAddresses(
          query,
          near: _biasPoint,
          thorough: true,
        );
      }
      if (!mounted || generation != _searchGeneration) {
        return;
      }
      if (_controller.text.trim() != query) {
        setState(() => _searching = false);
        return;
      }
      setState(() {
        _suggestions = results.take(_maxSuggestions).toList(growable: false);
        _searching = false;
        if (results.isEmpty) {
          _error = 'Sin resultados. Prueba con más detalle.';
        }
      });
    } on NavigationException catch (error) {
      if (!mounted || generation != _searchGeneration) {
        return;
      }
      setState(() {
        _searching = false;
        _error = navigationUserMessage(error);
        if (_suggestions.isEmpty) {
          _suggestions = const [];
        }
      });
    } catch (error) {
      if (!mounted || generation != _searchGeneration) {
        return;
      }
      setState(() {
        _searching = false;
        _error = navigationUserMessage(error);
      });
    }
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _selected = null;
      _suggestions = const [];
      _error = '';
    });
    widget.onEdited?.call();
  }

  void _select(GeocodingPlace place) {
    _setQueryText(place.displayLine, notify: false);
    setState(() {
      _selected = place;
      _suggestions = const [];
      _error = '';
    });
    widget.focusNode.unfocus();
    widget.onSelected(place);
  }

  Widget? _suffixIcon(ColorScheme colors) {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final actions = <Widget>[];
    if (widget.onUseGps != null && _selected == null) {
      actions.add(
        IconButton(
          tooltip: 'Mi ubicación',
          onPressed: widget.enabled ? widget.onUseGps : null,
          icon: const Icon(Icons.my_location, color: HubStyle.accent),
        ),
      );
    }
    if (_selected != null) {
      actions.add(const Icon(Icons.check_circle, color: HubStyle.accent, size: 22));
      actions.add(
        IconButton(
          tooltip: 'Borrar',
          onPressed: widget.enabled ? _clear : null,
          icon: const Icon(Icons.clear),
        ),
      );
    } else if (_controller.text.isNotEmpty) {
      actions.add(
        IconButton(
          tooltip: 'Borrar',
          onPressed: widget.enabled ? _clear : null,
          icon: const Icon(Icons.clear),
        ),
      );
    }

    if (actions.isEmpty) {
      return null;
    }
    if (actions.length == 1) {
      return actions.first;
    }
    return Row(mainAxisSize: MainAxisSize.min, children: actions);
  }

  String? _helperText(ColorScheme colors) {
    if (_searching) {
      return 'Buscando dirección…';
    }
    if (_error.isNotEmpty) {
      return _error;
    }
    if (_selected != null) {
      return null;
    }
    if (_suggestions.isNotEmpty) {
      return 'Toca un resultado o pulsa Calcular.';
    }
    if (_focused || _controller.text.trim().length >= 3) {
      return widget.exampleHint;
    }
    return null;
  }

  Color? _helperColor(ColorScheme colors) {
    if (_error.isNotEmpty) {
      return colors.error;
    }
    if (_selected != null) {
      return colors.primary;
    }
    if (_searching) {
      return colors.onSurfaceVariant;
    }
    return colors.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borderColor = _selected != null
        ? HubStyle.accent.withValues(alpha: 0.6)
        : const Color(0xFFD1D5DB);
    final helper = _helperText(colors);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: const Color(0xFFF9FAFB),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                focusNode: widget.focusNode,
                enabled: widget.enabled,
                keyboardType: TextInputType.streetAddress,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                enableSuggestions: false,
                minLines: 1,
                maxLines: _selected == null ? 1 : 2,
                onSubmitted: (_) {
                  if (_suggestions.length == 1) {
                    _select(_suggestions.first);
                    return;
                  }
                  final query = _controller.text.trim();
                  if (query.length >= 3) {
                    unawaited(_runSearch(query, thorough: true));
                  }
                },
                style: HubStyle.body(color: HubStyle.title),
                decoration: InputDecoration(
                  labelText: widget.labelText,
                  hintText: widget.hintText,
                  labelStyle: HubStyle.caption(),
                  hintStyle: HubStyle.caption(
                    color: HubStyle.subtitle.withValues(alpha: 0.7),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(16, 14, 4, 10),
                  prefixIcon: Icon(widget.prefixIcon, color: HubStyle.accent),
                  suffixIcon: _suffixIcon(colors),
                  suffixIconConstraints: const BoxConstraints(minWidth: 44),
                ),
              ),
              if (_showSuggestions) ...[
                Divider(
                  height: 1,
                  color: colors.outlineVariant.withValues(alpha: 0.6),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    '${_suggestions.length} resultado'
                    '${_suggestions.length == 1 ? '' : 's'}',
                    style: HubStyle.caption(),
                  ),
                ),
                for (var i = 0; i < _suggestions.length; i++)
                  _SuggestionTile(
                    place: _suggestions[i],
                    enabled: widget.enabled,
                    showDivider: i < _suggestions.length - 1,
                    isFavorite: widget.isFavorite?.call(_suggestions[i]),
                    onToggleFavorite: widget.onToggleFavorite == null
                        ? null
                        : () => widget.onToggleFavorite!(_suggestions[i]),
                    onTap: () => _select(_suggestions[i]),
                  ),
              ],
            ],
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              helper,
              style: HubStyle.caption(color: _helperColor(colors)),
            ),
          ),
        ],
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.place,
    required this.enabled,
    required this.showDivider,
    required this.onTap,
    this.isFavorite,
    this.onToggleFavorite,
  });

  final GeocodingPlace place;
  final bool enabled;
  final bool showDivider;
  final VoidCallback onTap;
  final bool? isFavorite;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final favorite = isFavorite == true;

    return Column(
      children: [
        InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(
                  Icons.north_west,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Text(
                      place.displayLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HubStyle.body(color: HubStyle.title),
                    ),
                  ),
                ),
                if (onToggleFavorite != null)
                  IconButton(
                    tooltip: favorite
                        ? 'Quitar de favoritos'
                        : 'Guardar en favoritos',
                    onPressed: enabled ? onToggleFavorite : null,
                    icon: Icon(
                      favorite ? Icons.star_rounded : Icons.star_border_rounded,
                      color: favorite ? HubStyle.accent : colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 44,
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}
