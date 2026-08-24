/// Posición GPS del propio dispositivo con rumbo y velocidad.
typedef OwnDevicePosition = ({
  double lat,
  double lng,
  double? heading,
  double speedMps,
});

OwnDevicePosition ownDevicePosition({
  required double lat,
  required double lng,
  double? heading,
  double speedMps = 0,
}) =>
    (lat: lat, lng: lng, heading: heading, speedMps: speedMps);
