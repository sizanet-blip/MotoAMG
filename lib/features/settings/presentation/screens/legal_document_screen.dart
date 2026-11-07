import 'package:flutter/material.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/core/theme/hub_style.dart';

enum LegalDocumentKind { privacy, terms }

/// Texto legal integrado de MotoAMG (propio de esta app).
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.kind});

  final LegalDocumentKind kind;

  String get _lastUpdated => AppConstants.privacyPolicyVersion;

  String _body(LegalDocumentKind kind) {
    final contact = 'Contacto del responsable: ${AppConstants.supportEmail}';
    final developer = AppConstants.developerName;
    final app = AppConstants.appName;
    return switch (kind) {
      LegalDocumentKind.privacy => '''
Política de privacidad de $app
Versión / fecha: $_lastUpdated

Esta política describe cómo $app trata datos personales. El responsable del tratamiento es $developer.

1. Qué datos tratamos

Cuenta AMG
• Usuario, contraseña (hash en el servidor), email opcional y código de recuperación.
• La solicitud de alta puede quedar pendiente hasta que un administrador la apruebe en el panel.
• Identificador técnico de dispositivo, plataforma, versión de la app y build al iniciar sesión.

Perfil y clubs
• Nombre visible, vehículos que guardes y datos de club/grupo asociados a tu cuenta.
• Membresías, roles y solicitudes de club.

Ubicación
• Posición, rumbo y velocidad aproximada mientras compartes ubicación con un grupo o usas la navegación GPS.
• Se envía a nuestros sistemas (p. ej. Firebase Realtime Database) para mostrar tu posición a los miembros del grupo y para la guía de ruta.

Grupos y actividad en ruta
• Nombre del grupo, código de acceso, miembros, roles de marcha, rutas compartidas, paradas e incidencias o avisos que publiques.

Intercom (voz)
• Si el creador del grupo activa el intercom y tú usas Hablar/Oír, se trata audio en tiempo real (LiveKit). No está pensado como archivo permanente de conversaciones.

Contactos de emergencia
• Nombre y teléfono que configures se guardan en tu dispositivo. $app no envía SMS ni WhatsApp automáticamente.

Datos en el dispositivo
• Preferencias, cachés de mapas offline, inventarios de radares/gasolineras y datos técnicos de sesión.

Datos técnicos y estabilidad
• Información básica del dispositivo y, en su caso, informes de fallo (p. ej. Firebase Crashlytics) para mejorar la estabilidad. No usamos esa información para publicidad personalizada.

2. Para qué los usamos

• Prestarte el servicio: mapa de grupo, navegación, avisos, intercom y gestión de cuenta.
• Gestionar el alta AMG, la aprobación del administrador y el acceso a $app.
• Mostrar tu posición y estado a los miembros del grupo.
• Atender soporte y cumplir obligaciones legales.

3. Base del tratamiento

Contrato/uso del servicio, consentimiento (permisos del sistema y aceptación de esta política) e interés legítimo en seguridad y mejora técnica, cuando proceda.

4. Con quién se comparten

• Miembros de tus grupos: ubicación, nombre visible, avisos e información de ruta mientras compartes.
• Proveedores: panel AMG/hosting, Google Firebase, mapas/geocodificación, LiveKit.
• No vendemos tus datos personales a terceros con fines publicitarios.

5. Conservación

• Cuenta: mientras esté activa o según necesidad de soporte/seguridad.
• Ubicación en vivo: mientras compartes.
• Preferencias y cachés locales: en tu dispositivo hasta que las borres o desinstales.

6. Derechos

Revocar permisos del sistema, salir de grupos, editar perfil y solicitar acceso/rectificación/supresión escribiendo a ${AppConstants.supportEmail}. También puedes reclamar ante la AEPD (www.aepd.es).

7. Seguridad

Medidas razonables (HTTPS, hash de contraseñas, acceso autenticado). Protege tu dispositivo y el código de recuperación.

8. Menores

$app está pensada para adultos con capacidad legal para usar geolocalización y conducción responsable.

9. Cambios

Podemos actualizar esta política. Versión vigente: $_lastUpdated. Tras cambios relevantes se pedirá una nueva aceptación cuando proceda.

Responsable: $developer.
$contact
''',
      LegalDocumentKind.terms => '''
Términos de uso de $app
Versión / fecha: ${AppConstants.termsOfUseVersion}

Al usar $app aceptas estos términos. Si no estás de acuerdo, no uses la app. Desarrollo: $developer.

1. Descripción del servicio

$app ofrece mapa de grupo en vivo, navegación GPS, avisos en ruta, paradas e incidencias e intercom de voz (si el grupo lo activa).

2. Cuenta y acceso

• El acceso requiere cuenta AMG con usuario y contraseña.
• La solicitud puede quedar pendiente de aprobación del administrador.
• Eres responsable de custodiar credenciales y el código de recuperación.
• No hay acceso de invitado ni registro con Google en esta versión.

3. Grupos y códigos

• Te unes a un grupo de forma voluntaria. Comparte el código solo con personas de confianza.
• Administradores pueden gestionar el grupo según las funciones disponibles.

4. Ubicación, mapa e intercom

• Al compartir posición, los miembros pueden verte.
• El intercom transmite audio en vivo; úsalo solo cuando sea seguro y respetuoso.

5. Emergencias

• Los avisos son herramientas de coordinación; no sustituyen a los servicios de emergencia.
• $app no llama al 112 ni envía mensajes automáticamente.

6. Navegación y datos de terceros

• Rutas, ETA, radares y precios son orientativos. Obedece siempre la señalización real y las normas de tráfico.

7. Uso permitido y no permitido

Usa la app de forma legal y responsable. No está permitido acosar, suplantar, acceder a datos ajenos, interferir con el servicio ni usarla para actividades ilegales, ni consultar el mapa de forma que distraiga la conducción.

8. Disponibilidad

El servicio puede interrumpirse por mantenimiento, cobertura o fallos de proveedores. Podemos modificar funciones o estos términos.

9. Limitación de responsabilidad

$app se ofrece “tal cual”. En la máxima medida permitida por la ley, $developer no responde de daños derivados del uso, de decisiones de conducción, de datos de terceros ni de la conducta de otros usuarios, salvo cuando la ley lo prohíba.

10. Privacidad

El tratamiento de datos se describe en la Política de privacidad de $app.

11. Contacto

${AppConstants.supportEmail}

$developer
''',
    };
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (kind) {
      LegalDocumentKind.privacy => 'Política de privacidad',
      LegalDocumentKind.terms => 'Términos de uso',
    };
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(titleText: title),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Text(
          _body(kind).trim(),
          style: HubStyle.body(
            color: isDark
                ? Theme.of(context).colorScheme.onSurface
                : HubStyle.title,
          ).copyWith(height: 1.45),
        ),
      ),
    );
  }
}
