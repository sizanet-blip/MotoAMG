import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Margen extra al comprobar espacio (sistema + otros ficheros).
const mapDownloadSpaceBufferBytes = 16 * 1024 * 1024;

const _channel = MethodChannel('es.albertomaestre.motoamg/storage');

/// Espacio libre en bytes en la ruta indicada, o null si no se pudo leer.
Future<int?> readFreeBytesForPath(String directoryPath) async {
  if (kIsWeb) {
    return null;
  }
  try {
    final result = await _channel.invokeMethod<int>(
      'getFreeBytesForPath',
      {'path': directoryPath},
    );
    return result;
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

String formatStorageMb(int bytes) {
  final mb = bytes / (1024 * 1024);
  if (mb < 10) {
    return '${mb.toStringAsFixed(1)} MB';
  }
  return '${mb.round()} MB';
}

String formatMapInsufficientSpace({
  required int neededBytes,
  required int freeBytes,
}) {
  return 'No hay espacio suficiente. Necesitas ${formatStorageMb(neededBytes)} '
      'libres y quedan ${formatStorageMb(freeBytes)}.';
}
