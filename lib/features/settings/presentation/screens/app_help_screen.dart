import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:url_launcher/url_launcher.dart';

/// Guía rápida integrada para el usuario.
class AppHelpScreen extends StatelessWidget {
  const AppHelpScreen({super.key});

  static const _sections = <({String title, String body})>[
    (
      title: 'Qué es LocMotos',
      body:
          'LocMotos combina mapa de grupo en vivo y un navegador GPS propio '
          'pensado para moto. Sirve para salidas en pelotón y también para '
          'ir solo a un destino. No sustituye tu criterio ni las normas de tráfico.',
    ),
    (
      title: 'Primeros pasos',
      body:
          '1. Concede ubicación y notificaciones cuando la app lo pida.\n'
          '2. En Xiaomi/Samsung conviene excluir LocMotos de la optimización '
          'de batería (Configuración → Pantalla al navegar).\n'
          '3. Inicia sesión con Google, correo o usuario.\n'
          '4. Crea un grupo o únete con el código de 6 caracteres.',
    ),
    (
      title: 'Grupos',
      body:
          '• Crear grupo: elige un nombre y comparte el código con el pelotón.\n'
          '• Unirse: introduce el código en «Unirse a grupo».\n'
          '• Cabecera y cola: roles de marcha (no son lo mismo que ser admin).\n'
          '• Para salir del grupo, usa las opciones del grupo en el menú.',
    ),
    (
      title: 'Mapa del grupo',
      body:
          'En el mapa verás a los compañeros en vivo. Iconos habituales:\n'
          '• Cabecera / cola del pelotón.\n'
          '• Motos sin señal GPS reciente.\n'
          '• Incidencias (avería, separado, emergencia…).\n'
          '• Paradas del grupo (café, gasolina, espera…).\n'
          'Botones útiles: centrar grupo, pelotón, paradas y navegar si hay ruta.',
    ),
    (
      title: 'Navegador integrado',
      body:
          'Además del mapa de grupo, LocMotos lleva su propio navegador GPS '
          '(no hace falta abrir Waze ni Google Maps).\n'
          '• Desde el inicio, pulsa el icono Navegación (brújula).\n'
          '• Busca destino, añade paradas si quieres y elige estilo de ruta '
          '(rápida, secundarias, evitaciones…).\n'
          '• Revisa la ruta en la vista previa y pulsa Empezar navegación.\n'
          '• En marcha verás mapa, siguiente maniobra, voz, radares, '
          'gasolineras, recálculo si te desvías y mapas offline si los '
          'descargaste.\n'
          'Puedes usarlo solo, sin estar en ningún grupo.',
    ),
    (
      title: 'Ruta compartida del grupo',
      body:
          'En una salida en pelotón, quien planifica puede publicar una ruta '
          'para que todos la vean en el mapa del grupo. Con ruta activa, '
          'pulsa Navegar: se abre el mismo navegador integrado, pero siguiendo '
          'el destino (y trazado) acordado por el grupo.',
    ),
    (
      title: 'Si sales tarde',
      body:
          'Si el grupo ya va en marcha y estás lejos del trazado, al pulsar '
          'Navegar puedes elegir:\n'
          '• Ir a la cabecera: ruta hacia su posición en vivo (eliges estilo '
          'de ruta).\n'
          '• Ir al destino del grupo: navegas directo al destino compartido.\n'
          'Cuando enganchas el trazado del pelotón, sigues la ruta del grupo.',
    ),
    (
      title: 'Ajustes que conviene revisar',
      body:
          '• Avisos de navegación: radares, gasolineras, peajes.\n'
          '• Grupo en ruta: ver compañeros en el HUD y avisos de pelotón.\n'
          '• Mapas offline: descargar regiones si rodarás sin cobertura.\n'
          '• Pantalla al navegar: evitar que se apague el móvil en ruta.',
    ),
    (
      title: 'Problemas frecuentes',
      body:
          '• No me ven en el mapa: comprueba ubicación activa y que compartes '
          'posición en el grupo.\n'
          '• GPS se corta: notificaciones activas y batería sin restricciones.\n'
          '• Compañero «sin señal»: lleva tiempo sin actualizar; puede estar '
          'sin cobertura o con la app en segundo plano restringida.\n'
          '• No hay ruta en el mapa: alguien del grupo debe publicarla primero.',
    ),
  ];

  Future<void> _openEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      queryParameters: const {'subject': 'LocMotos — ayuda'},
    );
    final opened = await launchUrl(uri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Escribe a ${AppConstants.supportEmail}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'Guía rápida',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Lo esencial para usar LocMotos en grupo.',
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          for (final section in _sections) ...[
            _HelpSectionCard(
              title: section.title,
              body: section.body,
            ),
            const SizedBox(height: 10),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '¿Sigues con dudas?',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Escríbenos y te ayudamos.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => unawaited(_openEmail(context)),
                    icon: const Icon(Icons.mail_outline),
                    label: Text(AppConstants.supportEmail),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSectionCard extends StatelessWidget {
  const _HelpSectionCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
