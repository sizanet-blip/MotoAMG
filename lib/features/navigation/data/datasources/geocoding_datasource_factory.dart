import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/data/datasources/geocoding_remote_datasource.dart';
import 'package:loc_motos/features/navigation/data/datasources/nominatim_geocoding_datasource.dart';
import 'package:loc_motos/features/navigation/data/datasources/photon_geocoding_datasource.dart';

GeocodingRemoteDataSource createGeocodingRemoteDataSource() {
  if (NavigationConstants.photonBaseUrl.isNotEmpty) {
    return PhotonGeocodingDataSource();
  }
  return NominatimGeocodingDataSource();
}
