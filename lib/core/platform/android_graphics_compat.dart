import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Perfil gráfico Android: MapLibre se cae en emuladores API ≤30 (GLES débil).
class AndroidGraphicsCompat {
  const AndroidGraphicsCompat({
    required this.sdkInt,
    required this.isEmulator,
  });

  final int sdkInt;
  final bool isEmulator;

  /// Estilo mínimo, sin 3D, TextureView, menos GeoJSON.
  bool get useLowGlMapMode =>
      !kIsWeb && ((isEmulator && sdkInt <= 30) || sdkInt <= 28);

  static const _channel = MethodChannel('com.locmotos.loc_motos/storage');

  static Future<AndroidGraphicsCompat> detect() async {
    if (kIsWeb) {
      return const AndroidGraphicsCompat(sdkInt: 99, isEmulator: false);
    }
    try {
      final raw = await _channel.invokeMethod<dynamic>('getGraphicsCompat');
      if (raw is Map) {
        return AndroidGraphicsCompat(
          sdkInt: (raw['sdkInt'] as num?)?.toInt() ?? 99,
          isEmulator: raw['isEmulator'] == true,
        );
      }
    } catch (_) {}
    return const AndroidGraphicsCompat(sdkInt: 99, isEmulator: false);
  }
}
