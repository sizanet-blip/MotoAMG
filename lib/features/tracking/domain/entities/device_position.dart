/// Posición GPS del propio dispositivo con rumbo, velocidad y precisión.
typedef OwnDevicePosition = ({
  double lat,
  double lng,
  double? heading,
  double speedMps,
  double? accuracyMeters,
});

OwnDevicePosition ownDevicePosition({
  required double lat,
  required double lng,
  double? heading,
  double speedMps = 0,
  double? accuracyMeters,
}) =>
    (
      lat: lat,
      lng: lng,
      heading: heading,
      speedMps: speedMps,
      accuracyMeters: accuracyMeters,
    );
