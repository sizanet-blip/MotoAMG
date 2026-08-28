import 'package:flutter/material.dart';
import 'package:loc_motos/core/constants/app_constants.dart';

enum LegalDocumentKind { privacy, terms }

/// Texto legal integrado cuando no hay URL pública configurada.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.kind});

  final LegalDocumentKind kind;

  String _body(LegalDocumentKind kind) {
    final contact = 'Contacto: ${AppConstants.supportEmail}';
    return switch (kind) {
      LegalDocumentKind.privacy => '''
LocMotos trata datos personales para ofrecer mapa en vivo, grupos de ruta y navegación GPS.

Qué recogemos
• Cuenta: nombre visible, identificador de usuario y, si lo usas, correo o cuenta de Google.
• Ubicación en tiempo real mientras compartes posición con un grupo o navegas.
• Datos del grupo: nombre del grupo, miembros, rutas compartidas, paradas e incidencias que publiques.
• Datos técnicos básicos para el funcionamiento de la app (p. ej. errores anonimizados si Crashlytics está activo).

Para qué los usamos
• Mostrar tu moto en el mapa del grupo.
• Calcular rutas, avisos y navegación.
• Mantener sesión y preferencias en tu dispositivo.

Con quién se comparten
• Los miembros de tu grupo ven tu ubicación mientras compartes.
• Proveedores necesarios (p. ej. Firebase, servidores de mapas y rutas) procesan datos en nuestro nombre.

Tus derechos
• Puedes dejar de compartir ubicación saliendo del grupo o desactivando permisos en el móvil.
• Puedes solicitar información o borrado escribiendo al contacto de soporte.

Conservación
• La ubicación en vivo se actualiza en el grupo y deja de mostrarse cuando dejas de compartir o pierdes señal según la configuración de la app.

Responsable del tratamiento: ${AppConstants.developerName}.

$contact
''',
      LegalDocumentKind.terms => '''
Al usar LocMotos aceptas estas condiciones.

Uso permitido
• Coordinar salidas en grupo de motociclistas con mapa y navegación.
• Compartir tu ubicación solo con grupos a los que te unes voluntariamente.

Uso no permitido
• Conducir distraído: consulta el mapa solo cuando sea seguro.
• Acosar, publicar datos falsos o usar la app para actividades ilegales.
• Intentar acceder a grupos o datos ajenos sin autorización.

Responsabilidad
• LocMotos es una herramienta de ayuda; no sustituye tu criterio ni las normas de tráfico.
• Las rutas son orientativas: respeta señales, límites de velocidad y condiciones de la vía.
• El organizador del grupo y cada conductor son responsables de su conducción.

Cuenta y grupos
• Debes proporcionar información veraz en tu perfil.
• Los administradores de grupo pueden gestionar miembros según las funciones de la app.

Cambios
• Podemos actualizar la app y estas condiciones. El uso continuado implica aceptación de los cambios publicados.

Desarrollo: ${AppConstants.developerName}.

$contact
''',
    };
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (kind) {
      LegalDocumentKind.privacy => 'Política de privacidad',
      LegalDocumentKind.terms => 'Términos de uso',
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Text(
          _body(kind).trim(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.45,
              ),
        ),
      ),
    );
  }
}
