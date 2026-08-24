import 'package:flutter/material.dart';
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
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _FormatMenuAction.allAddress,
          child: ListTile(
            leading: Icon(Icons.place_outlined),
            title: Text('Todo en direcciones'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: _FormatMenuAction.allCoordinates,
          child: ListTile(
            leading: Icon(Icons.gps_not_fixed),
            title: Text('Todo en coordenadas'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _FormatMenuAction.originAddress,
          child: ListTile(
            leading: Icon(
              originMode == RouteEndpointInputMode.address
                  ? Icons.check
                  : Icons.trip_origin,
            ),
            title: const Text('Origen: dirección'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _FormatMenuAction.originCoordinates,
          child: ListTile(
            leading: Icon(
              originMode == RouteEndpointInputMode.coordinates
                  ? Icons.check
                  : Icons.trip_origin,
            ),
            title: const Text('Origen: coordenadas'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _FormatMenuAction.destAddress,
          child: ListTile(
            leading: Icon(
              destMode == RouteEndpointInputMode.address
                  ? Icons.check
                  : Icons.flag_outlined,
            ),
            title: const Text('Destino: dirección'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _FormatMenuAction.destCoordinates,
          child: ListTile(
            leading: Icon(
              destMode == RouteEndpointInputMode.coordinates
                  ? Icons.check
                  : Icons.flag_outlined,
            ),
            title: const Text('Destino: coordenadas'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
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
