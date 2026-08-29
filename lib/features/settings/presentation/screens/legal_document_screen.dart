import 'package:flutter/material.dart';
import 'package:loc_motos/core/constants/app_constants.dart';

enum LegalDocumentKind { privacy, terms }

/// Texto legal integrado cuando no hay URL pública configurada.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.kind});

  final LegalDocumentKind kind;

  static const String _lastUpdated = '29 de agosto de 2026';

  String _body(LegalDocumentKind kind) {
    final contact = 'Contacto del responsable: ${AppConstants.supportEmail}';
    final developer = AppConstants.developerName;
    return switch (kind) {
      LegalDocumentKind.privacy => '''
Política de privacidad de ${AppConstants.appName}
Última actualización: $_lastUpdated

Esta política describe, en lenguaje claro, cómo ${AppConstants.appName} trata datos personales cuando usas la aplicación. El responsable del tratamiento es $developer.

1. Qué datos tratamos

Cuenta y perfil
• Identificador de usuario y, según cómo inicies sesión: cuenta de Google, correo electrónico o nombre de usuario.
• Nombre visible en el mapa, teléfono de perfil (si lo indicas), foto de perfil (si la aporta el proveedor de acceso) y vehículos que guardes (tipo, combustible, icono, etc.).
• En registro con usuario y contraseña: credenciales necesarias para autenticarte. La clave de recuperación que se muestra al registrarte es tu responsabilidad guardarla; no la almacenamos como método alternativo de acceso para ti.

Modo invitado
• Solo un nombre de visualización y datos temporales de sesión. Al salir como invitado se pierde el acceso y no hay recuperación de esa sesión.

Ubicación
• Posición, rumbo y velocidad aproximada mientras compartes ubicación con un grupo o usas la navegación GPS.
• Se envía a nuestros sistemas (p. ej. Firebase Realtime Database) para mostrar tu posición a los miembros del grupo y para la guía de ruta.

Grupos y actividad en ruta
• Nombre del grupo, código de acceso, miembros, roles de marcha (p. ej. cabecera/cola), rutas compartidas, paradas e incidencias o avisos que publiques (avería, separado, emergencia, etc.).

Intercom (voz)
• Si el creador del grupo activa el intercom y tú usas Hablar/Oír, se trata audio en tiempo real a través del servicio de voz (LiveKit) para que los miembros del canal puedan comunicarse. No está pensado como archivo de grabaciones permanentes de conversaciones.

Contactos de emergencia
• Nombre y teléfono que configures se guardan en tu dispositivo (almacenamiento local). LocMotos no envía SMS ni WhatsApp automáticamente: tú decides si avisar a esas personas tras una emergencia urgente.

Datos en el dispositivo
• Preferencias (tema, avisos, intercom, pantalla al navegar, recordatorios de radares, etc.), cachés de mapas offline, inventarios de radares y gasolineras descargados, y datos técnicos de sesión.

Datos técnicos y estabilidad
• Información básica del dispositivo y registros de fallo (p. ej. Firebase Crashlytics) para mejorar la estabilidad. No usamos esa información para publicidad personalizada.

2. Para qué los usamos

• Prestarte el servicio: mapa de grupo, navegación, avisos, intercom y gestión de cuenta.
• Mostrar tu posición y estado a los miembros del grupo al que te unes.
• Calcular rutas, ETA, avisos de radar/gasolinera/peaje según tu configuración.
• Mantener preferencias y contenidos offline en tu móvil.
• Atender soporte cuando nos escribes.
• Cumplir obligaciones legales aplicables.

3. Base del tratamiento

Tratamos datos porque son necesarios para prestar el servicio que solicitas (contrato/uso de la app), por tu consentimiento cuando otorgas permisos del sistema (ubicación, micrófono, notificaciones, etc.) y, en su caso, por interés legítimo en seguridad y mejora técnica de la app.

4. Con quién se comparten

• Miembros de tus grupos: ven tu ubicación, nombre visible, avisos e información de ruta del grupo mientras compartes.
• Proveedores de infraestructura que actúan por nuestra cuenta, entre otros: Google Firebase (autenticación, base de datos, posibles informes de error), servicios de mapas y geocodificación, servidor de voz LiveKit y, si usas Google Sign-In, Google como proveedor de acceso.
• Fuentes de datos públicos o institucionales que descargas o consultas a través de nuestros servidores o APIs (p. ej. cartografía OpenStreetMap/Protomaps, inventarios de radares, precios de carburantes). Esas fuentes no reciben tu perfil de usuario por el solo hecho de descargar el inventario.
• No vendemos tus datos personales a terceros con fines publicitarios.

Tú puedes abrir apps externas (Waze, Maps, WhatsApp, SMS, marcador telefónico). Esas apps tienen sus propias políticas; LocMotos solo facilita el enlace o el contenido que tú envías.

5. Conservación

• Cuenta y perfil: mientras mantengas la cuenta activa.
• Ubicación en vivo: se actualiza mientras compartes; deja de mostrarse cuando sales del grupo, cierras sesión o la app deja de publicar posición (p. ej. sin señal o permisos desactivados).
• Datos de grupo: mientras el grupo exista o según gestiones el administrador (salida, expulsión, borrado del grupo).
• Preferencias y cachés locales: en tu dispositivo hasta que las borres, desinstales la app o limpies datos.
• Modo invitado: se elimina al cerrar esa sesión.

6. Tus derechos y controles

• Revocar permisos del sistema (ubicación, micrófono, notificaciones) en el móvil.
• Dejar de compartir saliendo del grupo o cerrando sesión.
• Editar o borrar vehículos y datos de perfil desde la app, en la medida en que la función lo permita.
• Borrar contactos de emergencia en Configuración.
• Solicitar información, rectificación o borrado de datos de cuenta escribiendo a soporte. Atenderemos la petición en la medida legalmente posible y técnicamente viable.

7. Seguridad

Aplicamos medidas razonables (acceso autenticado, comunicación cifrada en tránsito con los servicios habituales, etc.). Ningún sistema es 100 % seguro: usa códigos de grupo solo con personas de confianza y protege tu dispositivo.

8. Menores

LocMotos está pensada para usuarios con capacidad legal para usar servicios de geolocalización y conducción responsable. Si eres menor, usa la app solo con supervisión y consentimiento de quien corresponda.

9. Transferencias y ubicación de tratamiento

Parte del tratamiento puede realizarse en infraestructuras de proveedores situadas fuera de tu país (p. ej. servicios de Google). Usamos proveedores de confianza y las salvaguardas habituales de esos servicios.

10. Cambios

Podemos actualizar esta política. La fecha de «Última actualización» se revisará cuando cambie el contenido. El uso continuado tras la publicación implica que has sido informado de la versión vigente en la app.

Responsable: $developer.
$contact
''',
      LegalDocumentKind.terms => '''
Términos de uso de ${AppConstants.appName}
Última actualización: $_lastUpdated

Al descargar, instalar o usar ${AppConstants.appName} aceptas estos términos. Si no estás de acuerdo, no uses la app. Desarrollo y publicación: $developer.

1. Descripción del servicio

LocMotos ofrece herramientas para moteros y usuarios de vehículo: mapa de grupo en vivo, navegación GPS integrada, avisos en ruta, paradas e incidencias, y, si el grupo lo activa, intercom de voz. También puedes usar la navegación sin pertenecer a un grupo.

2. Cuenta y acceso

• Puedes registrarte con Google, correo, usuario/contraseña o entrar como invitado (con limitaciones).
• Eres responsable de la confidencialidad de tus credenciales y de la clave de recuperación si te registras con usuario.
• Debes facilitar datos de perfil veraces en la medida en que afecten a la seguridad del grupo (p. ej. nombre reconocible).
• El modo invitado no garantiza conservación de datos ni recuperación posterior.

3. Grupos y códigos

• Te unes a un grupo de forma voluntaria mediante código u otras funciones que ofrezca la app.
• Comparte el código solo con personas de confianza.
• El creador o administradores pueden gestionar el grupo (nombre, miembros, intercom, eliminación, etc.) según las funciones disponibles.
• Cabecera y cola son roles de marcha; no equivalen necesariamente a la administración del grupo.

4. Ubicación, mapa e intercom

• Al compartir posición, los miembros del grupo pueden ver dónde estás.
• El intercom transmite audio en vivo a quien esté en el canal; úsalo solo cuando sea seguro y respetuoso.
• No grabes ni redistribuyas conversaciones ajenas sin base legal o consentimiento.

5. Emergencias y contactos

• Los avisos de emergencia, avería o separado son herramientas de coordinación del grupo; no sustituyen a los servicios de emergencia.
• LocMotos no llama al 112 ni envía mensajes a contactos personales de forma automática. Tú decides si llamar o avisar.
• El uso indebido de avisos de emergencia puede molestar al grupo y, en casos graves, tener consecuencias legales.

6. Navegación y datos de terceros

• Las rutas, ETA, límites, radares, peajes y precios de carburante son orientativos y pueden estar incompletos, desactualizados o erróneos.
• Debes obedecer siempre la señalización real, las normas de tráfico y las condiciones de la vía.
• Puedes abrir apps externas (p. ej. Waze o Maps); su uso se rige por sus propias condiciones.

7. Uso permitido

• Coordinar salidas y navegar de forma responsable.
• Usar la app conforme a la ley y respetando a otros usuarios.

8. Uso no permitido

• Consultar el mapa o el teléfono de forma que distraiga la conducción.
• Acosar, amenazar, suplantar, publicar datos falsos o difundir contenido ilícito.
• Intentar acceder a grupos, cuentas o datos ajenos sin autorización.
• Interferir con el servicio, automatizar abusos o eludir medidas de seguridad.
• Usar LocMotos para actividades ilegales.

9. Disponibilidad y cambios

• El servicio puede interrumpirse por mantenimiento, cobertura, fallos de red o de proveedores.
• Podemos modificar funciones, estos términos o retirar el servicio. El uso continuado tras cambios publicados en la app implica aceptación de la versión vigente.

10. Propiedad intelectual

• LocMotos, su marca, diseño y código propio pertenecen a $developer o a sus licenciantes.
• Las bibliotecas de terceros, mapas y conjuntos de datos se usan bajo sus respectivas licencias y condiciones (consulta Licencias y atribuciones en Acerca de).

11. Exención y limitación

• LocMotos es una ayuda; no garantiza precisión absoluta ni disponibilidad continua.
• En la máxima medida permitida por la ley aplicable, $developer no responde de daños derivados del uso de la app, de decisiones de conducción, de datos de terceros (mapas, radares, precios, etc.) ni de la conducta de otros usuarios del grupo.
• Nada en estos términos excluye responsabilidad que no pueda limitarse legalmente.

12. Privacidad

El tratamiento de datos personales se describe en la Política de privacidad disponible en la app.

13. Contacto

Para dudas sobre estos términos o sobre el servicio: ${AppConstants.supportEmail}.

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
