import 'package:equatable/equatable.dart';

/// Región descargable de mapas vectoriales (.pmtiles).
class MapRegion extends Equatable {
  const MapRegion({
    required this.id,
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
    this.localPath,
    this.isDownloaded = false,
  });

  final String id;
  final String name;
  final String downloadUrl;
  final int sizeBytes;
  final String? localPath;
  final bool isDownloaded;

  MapRegion copyWith({
    String? localPath,
    bool? isDownloaded,
  }) {
    return MapRegion(
      id: id,
      name: name,
      downloadUrl: downloadUrl,
      sizeBytes: sizeBytes,
      localPath: localPath ?? this.localPath,
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    downloadUrl,
    sizeBytes,
    localPath,
    isDownloaded,
  ];
}
