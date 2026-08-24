import 'package:loc_motos/core/constants/app_constants.dart';

bool isGpsStale(DateTime updatedAt, DateTime now) {
  return now.difference(updatedAt) >= AppConstants.gpsStaleAfter;
}
