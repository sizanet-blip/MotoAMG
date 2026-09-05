import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:moto_amg/features/navigation/data/services/gpx_route_codec.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Comparte e importa rutas en formato GPX.
class RouteGpxService {
  RouteGpxService({GpxRouteCodec? codec})
      : _codec = codec ?? const GpxRouteCodec();

  final GpxRouteCodec _codec;

  Future<void> shareRoute(
    NavigationRoute route, {
    String name = 'Ruta MotoAMG',
  }) async {
    final gpx = _codec.encode(route, name: name);
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/motoamg_ruta_$stamp.gpx');
    await file.writeAsString(gpx, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/gpx+xml')],
        subject: name,
        text: 'Ruta compartida desde MotoAMG',
      ),
    );
  }

  /// Abre el selector de archivos y parsea el GPX elegido.
  ///
  /// Devuelve `null` si el usuario cancela.
  ///
  /// En Android no filtramos por extensión `.gpx`: el SAF a menudo muestra el
  /// archivo pero no deja seleccionarlo (MIME desconocido). Validamos después.
  Future<List<GpxImportedStop>?> pickAndParse() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) {
      return null;
    }
    final name = file.name.toLowerCase();
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('No se pudo leer el archivo GPX.');
    }
    final xml = utf8.decode(bytes);
    final looksLikeGpx = name.endsWith('.gpx') ||
        name.endsWith('.xml') ||
        xml.contains('<gpx') ||
        xml.contains('<GPX');
    if (!looksLikeGpx) {
      throw const FormatException(
        'Elige un archivo GPX (.gpx).',
      );
    }
    final stops = _codec.decode(xml);
    if (stops.length < 2) {
      throw const FormatException(
        'El GPX no tiene suficientes puntos (origen y destino).',
      );
    }
    return stops;
  }
}
