import 'package:flutter/material.dart';
import 'package:loc_motos/core/widgets/app_popup_menu.dart';
import 'package:loc_motos/features/navigation/domain/entities/geocoding_place.dart';
import 'package:loc_motos/features/navigation/presentation/models/route_endpoint_input_mode.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/coordinate_endpoint_field.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/destination_search_field.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/route_endpoint_mode_toggle.dart';

/// Origen o destino con selector de formato (dirección / coordenadas).
class RouteEndpointField extends StatelessWidget {
  const RouteEndpointField({
    super.key,
    required this.endpointLabel,
    required this.mode,
    required this.enabled,
    required this.onModeChanged,
    required this.addressController,
    required this.addressFocus,
    required this.latController,
    required this.lngController,
    required this.selectedPlace,
    required this.onAddressEdited,
    required this.onAddressSelected,
    this.addressLabelText = '¿A dónde vas?',
    this.addressHintText = 'Calle, número, ciudad',
    this.addressPrefixIcon = Icons.location_on_outlined,
    this.addressExampleHint =
        'Escribe calle, número y ciudad. Ej.: Calle Previsión Social 9, Zaragoza',
    this.coordinatesLabelText = 'Coordenadas',
    this.coordinatesPrefixIcon = Icons.location_on_outlined,
    this.onUseGps,
    this.onCoordinatesChanged,
  });

  final String endpointLabel;
  final RouteEndpointInputMode mode;
  final bool enabled;
  final ValueChanged<RouteEndpointInputMode> onModeChanged;
  final TextEditingController addressController;
  final FocusNode addressFocus;
  final TextEditingController latController;
  final TextEditingController lngController;
  final GeocodingPlace? selectedPlace;
  final VoidCallback onAddressEdited;
  final ValueChanged<GeocodingPlace> onAddressSelected;
  final String addressLabelText;
  final String addressHintText;
  final IconData addressPrefixIcon;
  final String addressExampleHint;
  final String coordinatesLabelText;
  final IconData coordinatesPrefixIcon;
  final VoidCallback? onUseGps;
  final VoidCallback? onCoordinatesChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              endpointLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            RouteEndpointModeToggle(
              mode: mode,
              enabled: enabled,
              onChanged: onModeChanged,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (mode == RouteEndpointInputMode.address)
          DestinationSearchField(
            controller: addressController,
            focusNode: addressFocus,
            enabled: enabled,
            labelText: addressLabelText,
            hintText: addressHintText,
            prefixIcon: addressPrefixIcon,
            exampleHint: addressExampleHint,
            selectedPlace: selectedPlace,
            onUseGps: onUseGps,
            onEdited: onAddressEdited,
            onSelected: onAddressSelected,
          )
        else
          CoordinateEndpointField(
            labelText: coordinatesLabelText,
            latController: latController,
            lngController: lngController,
            enabled: enabled,
            prefixIcon: coordinatesPrefixIcon,
            onUseGps: onUseGps,
            onChanged: onCoordinatesChanged,
          ),
      ],
    );
  }
}

/// Atajos de formato junto al título «Planificar ruta».
class RoutePlanFormatMenu extends StatelessWidget {
  const RoutePlanFormatMenu({
    super.key,
    required this.originMode,
    required this.destMode,
    required this.enabled,
    required this.onApply,
  });

  final RouteEndpointInputMode originMode;
  final RouteEndpointInputMode destMode;
  final bool enabled;
  final void Function({
    RouteEndpointInputMode? origin,
    RouteEndpointInputMode? dest,
  }) onApply;

  @override
  Widget build(BuildContext context) {
    final usingCoords = originMode == RouteEndpointInputMode.coordinates ||
        destMode == RouteEndpointInputMode.coordinates;

    return PopupMenuButton<_FormatMenuAction>(
      tooltip: 'Formato origen / destino',
      enabled: enabled,
      offset: AppPopupMenus.offset,
      elevation: AppPopupMenus.elevation,
      shadowColor: AppPopupMenus.shadowColor,
      surfaceTintColor: AppPopupMenus.surfaceTintOf(context),
      color: AppPopupMenus.colorOf(context),
      shape: AppPopupMenus.shapeOf(context),
      icon: Icon(
        usingCoords ? Icons.gps_not_fixed : Icons.place_outlined,
      ),
      onSelected: (action) {
        switch (action) {
          case _FormatMenuAction.allAddress:
            onApply(
              origin: RouteEndpointInputMode.address,
              dest: RouteEndpointInputMode.address,
            );
          case _FormatMenuAction.allCoordinates:
            onApply(
              origin: RouteEndpointInputMode.coordinates,
              dest: RouteEndpointInputMode.coordinates,
            );
          case _FormatMenuAction.originCoordinates:
            onApply(origin: RouteEndpointInputMode.coordinates);
          case _FormatMenuAction.destCoordinates:
            onApply(dest: RouteEndpointInputMode.coordinates);
          case _FormatMenuAction.originAddress:
            onApply(origin: RouteEndpointInputMode.address);
          case _FormatMenuAction.destAddress:
            onApply(dest: RouteEndpointInputMode.address);
        }
      },
      itemBuilder: (context) {
        final colors = Theme.of(context).colorScheme;
        return [
          appPopupMenuItem(
            value: _FormatMenuAction.allAddress,
            icon: Icons.place_outlined,
            label: 'Todo en direcciones',
            tint: colors.primary,
          ),
          appPopupMenuItem(
            value: _FormatMenuAction.allCoordinates,
            icon: Icons.gps_not_fixed,
            label: 'Todo en coordenadas',
            tint: colors.tertiary,
          ),
          const PopupMenuDivider(height: 8),
          appPopupMenuItem(
            value: _FormatMenuAction.originAddress,
            icon: Icons.trip_origin,
            label: 'Origen: dirección',
            selected: originMode == RouteEndpointInputMode.address,
          ),
          appPopupMenuItem(
            value: _FormatMenuAction.originCoordinates,
            icon: Icons.my_location_outlined,
            label: 'Origen: coordenadas',
            selected: originMode == RouteEndpointInputMode.coordinates,
          ),
          appPopupMenuItem(
            value: _FormatMenuAction.destAddress,
            icon: Icons.flag_outlined,
            label: 'Destino: dirección',
            selected: destMode == RouteEndpointInputMode.address,
          ),
          appPopupMenuItem(
            value: _FormatMenuAction.destCoordinates,
            icon: Icons.flag,
            label: 'Destino: coordenadas',
            selected: destMode == RouteEndpointInputMode.coordinates,
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
          ),
        ];
      },
    );
  }
}

enum _FormatMenuAction {
  allAddress,
  allCoordinates,
  originAddress,
  originCoordinates,
  destAddress,
  destCoordinates,
}
