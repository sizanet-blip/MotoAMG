import 'dart:convert';
import 'dart:io';

/// Estilo PMTiles simplificado para navegación (sin edificios 3D/planos).
void main() {
  final layersFile = File('assets/maps/protomaps_light_layers.json');
  final outputFile = File('assets/maps/navigation_style.json');
  final allLayers = jsonDecode(layersFile.readAsStringSync()) as List<dynamic>;
  final layers = allLayers.where((layer) {
    final map = layer as Map<String, dynamic>;
    final id = map['id'] as String? ?? '';
    return !id.contains('building');
  }).toList();

  final style = <String, dynamic>{
    'version': 8,
    'glyphs':
        'https://protomaps.github.io/basemaps-assets/fonts/{fontstack}/{range}.pbf',
    'sprite': 'https://protomaps.github.io/basemaps-assets/sprites/v4/light',
    'sources': {
      'protomaps': {
        'type': 'vector',
        'url': 'pmtiles://https://demo-bucket.protomaps.com/v4.pmtiles',
        'attribution':
            '<a href="https://github.com/protomaps/basemaps">Protomaps</a> '
            '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      },
    },
    'layers': layers,
  };

  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(style),
  );
  stdout.writeln(
    'Wrote ${outputFile.path} (${outputFile.lengthSync()} bytes, '
    '${layers.length} layers)',
  );
}
