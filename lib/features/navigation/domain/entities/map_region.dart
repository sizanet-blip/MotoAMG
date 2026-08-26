import 'package:equatable/equatable.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_bounds.dart';

/// Región descargable de mapas vectoriales (.pmtiles).
class MapRegion extends Equatable {
  const MapRegion({
    required this.id,
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.bounds,
    this.localPath,
    this.isDownloaded = false,
    this.partialBytes = 0,
  });

  final String id;
  final String name;
  final String downloadUrl;
  final int sizeBytes;
  final GeoBounds bounds;
  final String? localPath;
  final bool isDownloaded;

  /// Bytes ya descargados en `.partial` (descarga interrumpida).
  final int partialBytes;

  bool get hasPartialDownload => !isDownloaded && partialBytes > 0;

  double get partialProgress =>
      sizeBytes > 0 ? (partialBytes / sizeBytes).clamp(0.0, 1.0) : 0;

  MapRegion copyWith({
    String? localPath,
    bool? isDownloaded,
    GeoBounds? bounds,
    int? partialBytes,
  }) {
    return MapRegion(
      id: id,
      name: name,
      downloadUrl: downloadUrl,
      sizeBytes: sizeBytes,
      bounds: bounds ?? this.bounds,
      localPath: localPath ?? this.localPath,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      partialBytes: partialBytes ?? this.partialBytes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        downloadUrl,
        sizeBytes,
        bounds,
        localPath,
        isDownloaded,
        partialBytes,
      ];
}
