import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/data/datasources/fallback_geocoding_datasource.dart';
import 'package:loc_motos/features/navigation/data/datasources/geocoding_remote_datasource.dart';
import 'package:loc_motos/features/navigation/data/datasources/nominatim_geocoding_datasource.dart';
import 'package:loc_motos/features/navigation/data/datasources/photon_geocoding_datasource.dart';

GeocodingRemoteDataSource createGeocodingRemoteDataSource() {
  final nominatim = NominatimGeocodingDataSource();
  if (NavigationConstants.photonBaseUrl.isEmpty) {
    return nominatim;
  }
  // Photon primero; si el VPS cae o no responde, Nominatim público.
  return FallbackGeocodingDataSource(
    primary: PhotonGeocodingDataSource(),
    fallback: nominatim,
  );
}
