/// Contenido de ayuda a nivel usuario (español).
library;

class HelpSection {
  const HelpSection({required this.title, required this.body});

  final String title;
  final String body;
}

class HelpFaqItem {
  const HelpFaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

/// Guía rápida actualizada: lo esencial en pocos minutos.
const quickGuideSections = <HelpSection>[
  HelpSection(
    title: 'Qué es LocMotos',
    body:
        'LocMotos es una app para moteros: mapa de grupo en vivo y navegador GPS '
        'integrado. Sirve para salidas en pelotón y también para ir solo.\n\n'
        'No sustituye tu atención al tráfico ni el cumplimiento de las normas.',
  ),
  HelpSection(
    title: 'Antes de salir',
    body:
        '1. Activa ubicación y notificaciones cuando la app lo pida.\n'
        '2. En Xiaomi, Samsung y similares, excluye LocMotos de la '
        'optimización de batería (Configuración → Pantalla al navegar).\n'
        '3. Inicia sesión (Google, correo o usuario) o entra como invitado.\n'
        '4. Revisa radares y mapas offline si vas a zonas con poca cobertura.',
  ),
  HelpSection(
    title: 'Grupos en 30 segundos',
    body:
        '• Crear: «Crear grupo», elige un nombre y comparte el código de 6 caracteres.\n'
        '• Unirse: «Unirme con un código» e introduce el código.\n'
        '• Abrir el grupo: toca el grupo en la lista para ver el mapa en vivo.\n'
        '• Roles cabecera/cola: se asignan en el pelotón; no son lo mismo que ser creador.',
  ),
  HelpSection(
    title: 'Mapa del grupo',
    body:
        'Verás a tus compañeros en tiempo real, paradas e incidencias.\n'
        'Abajo o a un lado: avisos (emergencia, avería, separado) e intercom si '
        'el creador lo ha activado.\n'
        'Botones habituales: pelotón, paradas, centrar grupo y navegar (si hay ruta).',
  ),
  HelpSection(
    title: 'Navegar',
    body:
        '• Solo: desde el inicio, «Navegación» → busca destino → Ver ruta → Empezar.\n'
        '• Con grupo: si hay ruta compartida, «Navegar» sigue el destino del pelotón.\n'
        '• Si llegas tarde: puedes ir a la cabecera o directo al destino del grupo.',
  ),
  HelpSection(
    title: 'Avisos importantes',
    body:
        '• Usa Emergencia / Avería / Separado solo cuando haga falta: el grupo lo ve en el mapa.\n'
        '• Si tú envías el aviso, quítalo con el botón de confirmación (check) cuando ya estés bien.\n'
        '• Urgente · 112: puedes avisar contactos personales a mano (SMS/WhatsApp); no se envía solo.',
  ),
  HelpSection(
    title: 'Configuración útil',
    body:
        '• Avisos de navegación: radares, gasolineras, peajes.\n'
        '• Radares / gasolineras offline: descarga y aviso al abrir la app.\n'
        '• Intercom: defaults Hablar/Oír; el canal lo activa el creador del grupo.\n'
        '• Pantalla al navegar: que no se apague el móvil en ruta.',
  ),
];

/// Manual completo a nivel usuario.
const fullManualSections = <HelpSection>[
  HelpSection(
    title: '1. Bienvenida',
    body:
        'LocMotos está pensada para salidas en moto: coordinar un pelotón en el '
        'mapa y navegar con un GPS integrado, con o sin grupo.\n\n'
        'Este manual describe el uso diario de la app. No es un documento técnico '
        'ni sustituye las normas de circulación.',
  ),
  HelpSection(
    title: '2. Cuentas e inicio de sesión',
    body:
        'Puedes entrar de varias formas:\n\n'
        '• Google o correo: cuenta habitual, recuperable según el proveedor.\n'
        '• Usuario y contraseña: si eliges esta opción, guarda bien la clave de '
        'recuperación que se muestra al registrarte; no hay otra vía si la pierdes.\n'
        '• Invitado: solo un nombre; puedes unirte a un grupo con código. Al salir '
        'se borra todo y no se puede recuperar.\n\n'
        'En Mi perfil puedes cambiar el nombre en el mapa, el teléfono, los '
        'vehículos y la contraseña (si aplica). Los vehículos se guardan al '
        'pulsar «Guardar vehículo»; el nombre y teléfono con «Guardar perfil».',
  ),
  HelpSection(
    title: '3. Vehículos',
    body:
        'En el perfil puedes añadir moto, coche o camión, combustible e icono '
        'en el mapa.\n\n'
        'El vehículo activo influye en el tipo de ruta y en qué precios de '
        'gasolinera se destacan. Puedes dejar «Ningún vehículo activo» si lo '
        'prefieres.',
  ),
  HelpSection(
    title: '4. Grupos',
    body:
        'Un grupo es tu pelotón en LocMotos.\n\n'
        'Crear un grupo\n'
        'Desde Mis grupos → Crear grupo. Elige un nombre claro. La app genera un '
        'código de 6 caracteres: compártelo solo con quien deba unirse.\n\n'
        'Unirse\n'
        'Introduce el código exacto. Puedes estar en varios grupos y elegir cuál '
        'abrir cada salida.\n\n'
        'Creador / administrador\n'
        'Quien crea el grupo gestiona opciones (nombre, intercom, expulsar, etc.). '
        'Eliminar el grupo borra el código y la ruta compartida para todos.\n\n'
        'Salir del grupo\n'
        'Desde opciones del grupo. Podrás volver a entrar con el código si sigue activo.',
  ),
  HelpSection(
    title: '5. Roles de marcha (cabecera y cola)',
    body:
        'Cabecera y cola son roles de la ruta, no de administración.\n\n'
        '• Cabecera: referencia del pelotón; útil si alguien llega tarde y quiere '
        'alcanzar al grupo.\n'
        '• Cola: cierra la marcha.\n\n'
        'Se gestionan desde el listado del pelotón en el mapa. Quien organiza la '
        'salida decide quién ocupa cada rol.',
  ),
  HelpSection(
    title: '6. Mapa del grupo',
    body:
        'Al abrir un grupo entras al mapa en vivo.\n\n'
        'Qué verás\n'
        '• Tu posición y la de los compañeros.\n'
        '• Cabecera y cola, si están asignados.\n'
        '• Paradas marcadas (café, gasolina, espera…).\n'
        '• Incidencias activas (avería, separado, emergencia…).\n'
        '• La ruta compartida, si alguien la ha publicado.\n\n'
        'Acciones habituales\n'
        '• Pelotón: lista de moteros y roles.\n'
        '• Paradas: ver o gestionar puntos del grupo.\n'
        '• Centrar: encuadra a todo el pelotón.\n'
        '• Navegar: abre el navegador hacia la ruta o destino del grupo.\n\n'
        'En horizontal los botones de acción están abajo a la derecha; los avisos '
        '(emergencia, etc.) a la izquierda. Mantén pulsado el mapa (si tienes '
        'permisiso) para marcar una parada.',
  ),
  HelpSection(
    title: '7. Incidencias y seguridad',
    body:
        'Botones de aviso (mapa y navegación de grupo):\n\n'
        '• Emergencia: el grupo ve el aviso; puedes indicar gravedad. En Urgente · 112 '
        'se abre el marcador del 112 y puedes avisar a contactos personales a mano.\n'
        '• Avería: problema mecánico o parada forzada.\n'
        '• Separado: te has perdido o vas lejos del grupo.\n'
        '• Esperar / reunir: (si eres admin o cabecera) pedir al pelotón que espere.\n\n'
        'Si tú envías el aviso, no verás el banner naranja: usa el botón circular '
        'con el check (color del aviso) para indicar «Ya estoy OK» y quitarlo.\n\n'
        'Los demás del grupo sí ven el aviso en el mapa o en el navegador.\n\n'
        'Contactos de emergencia\n'
        'En Configuración → Contacto de emergencia puedes guardar 1–2 personas '
        'de fuera del grupo. Tras Urgente · 112 puedes avisarles por SMS o WhatsApp; '
        'LocMotos no envía nada automáticamente.',
  ),
  HelpSection(
    title: '8. Intercom',
    body:
        'El intercom es audio en vivo entre miembros del grupo.\n\n'
        '• Solo el creador puede activar o desactivar el canal en Opciones del grupo.\n'
        '• En el mapa o el HUD verás Hablar y Oír (según preferencias).\n'
        '• En Configuración → Intercom defines si por defecto quieres hablar u oír '
        'al conectar.\n\n'
        'Usa el intercom con casco compatible y sin distraer la conducción. '
        'La app puede bajar el volumen de la voz de navegación cuando alguien habla.',
  ),
  HelpSection(
    title: '9. Navegador integrado',
    body:
        'LocMotos incluye su propio GPS; no dependes de otra app, aunque puedes '
        'abrir Waze o Maps si lo prefieres.\n\n'
        'Planificar una ruta (sin grupo o en modo navegación)\n'
        '1. Abre Navegación.\n'
        '2. El origen suele ser tu GPS; el destino se busca por dirección o tocando el mapa.\n'
        '3. Añade paradas intermedias si hace falta.\n'
        '4. Ajusta estilo (rápida, secundarias…) y evitaciones (autopistas, peajes…).\n'
        '5. Ver ruta → elige alternativa si hay → Empezar navegación.\n\n'
        'En marcha\n'
        'Verás la siguiente maniobra, velocidad, límite, ETA, avisos de radar o '
        'gasolinera (según ajustes) y recálculo si te desvías.\n\n'
        'Pantalla horizontal\n'
        'El HUD se adapta: controles laterales y barra de estado. Es el modo '
        'recomendado en soporte de moto.',
  ),
  HelpSection(
    title: '10. Ruta compartida del grupo',
    body:
        'Quien planifica puede publicar una ruta para todo el pelotón. Entonces:\n\n'
        '• Todos la ven en el mapa del grupo.\n'
        '• «Navegar» abre el GPS de LocMotos hacia ese destino/trazado.\n'
        '• Si llegas tarde y estás lejos, puedes elegir ir a la cabecera '
        '(con el estilo de ruta que quieras) o ir directo al destino del grupo.\n\n'
        'Cuando enganchas el trazado del pelotón, sigues la ruta compartida.',
  ),
  HelpSection(
    title: '11. Mapas, radares y gasolineras offline',
    body:
        'Mapas offline\n'
        'Descarga regiones en Configuración → Mapas offline para navegar sin cobertura.\n\n'
        'Radares offline\n'
        'Descarga el inventario (DGT/SCT/OSM) en Radares offline. Puedes activar un '
        'aviso al abrir la app si llevan X días sin actualizar.\n\n'
        'Gasolineras offline\n'
        'Descarga precios MITECO para consultarlos en ruta según tu combustible.',
  ),
  HelpSection(
    title: '12. Configuración recomendada',
    body:
        '• Tema y mapa día/noche: comodidad visual.\n'
        '• Avisos de navegación: qué alertas quieres y a qué distancia.\n'
        '• Pantalla al navegar: mantener pantalla encendida, brillo, modo casco.\n'
        '• Grupo en ruta: compañeros en el HUD y avisos si alguien se queda.\n'
        '• Intercom: preferencias personales de Hablar/Oír.\n\n'
        'Revisa estos ajustes una vez y olvídate; la app recordará tus preferencias.',
  ),
  HelpSection(
    title: '13. Privacidad y buen uso',
    body:
        '• Comparte el código del grupo solo con personas de confianza.\n'
        '• Tu ubicación se usa para el mapa del grupo y la navegación.\n'
        '• No uses la app si te distrae: la seguridad va primero.\n'
        '• LocMotos es una ayuda; tú decides cómo y cuándo circular.\n\n'
        'Más detalle legal en Acerca de LocMotos (privacidad y condiciones).',
  ),
  HelpSection(
    title: '14. Soporte',
    body:
        'Si algo no cuadra, consulta primero Preguntas y respuestas.\n'
        'Si necesitas ayuda personalizada, escribe a soporte desde Ayuda o '
        'Acerca de LocMotos.',
  ),
];

/// Preguntas frecuentes amplias a nivel usuario.
const faqItems = <HelpFaqItem>[
  HelpFaqItem(
    question: '¿Necesito estar en un grupo para navegar?',
    answer:
        'No. Puedes abrir Navegación desde el inicio y usar el GPS solo, sin grupo.',
  ),
  HelpFaqItem(
    question: '¿Qué diferencia hay entre creador del grupo y cabecera?',
    answer:
        'El creador administra el grupo (código, opciones, intercom, eliminar…). '
        'Cabecera es un rol de marcha: quién va delante en esa salida. Pueden ser '
        'personas distintas.',
  ),
  HelpFaqItem(
    question: 'He perdido el código del grupo. ¿Qué hago?',
    answer:
        'Pídeselo a quien lo creó o a alguien que ya esté dentro. El código aparece '
        'en las opciones o en la ficha del grupo para quien lo gestiona.',
  ),
  HelpFaqItem(
    question: '¿Puedo estar en varios grupos a la vez?',
    answer:
        'Sí. En Mis grupos verás los activos y eliges cuál abrir. Solo uno está '
        '«en mapa» a la vez.',
  ),
  HelpFaqItem(
    question: 'No me ven en el mapa / no veo a los demás',
    answer:
        'Comprueba que la ubicación está activa, que estás dentro del grupo correcto '
        'y que LocMotos no está restringida por la batería. En segundo plano algunos '
        'móviles cortan el GPS: revisa Configuración → Pantalla al navegar y las '
        'excepciones del sistema.',
  ),
  HelpFaqItem(
    question: 'Un compañero aparece «sin señal». ¿Qué significa?',
    answer:
        'Lleva un rato sin enviar posición. Puede estar sin cobertura, con la app '
        'cerrada o con restricciones de batería. No implica necesariamente un '
        'problema en la carretera.',
  ),
  HelpFaqItem(
    question: '¿Cómo publico una ruta para el grupo?',
    answer:
        'Planifica la ruta en el navegador y publícala para el grupo (según las '
        'opciones disponibles al organizar la salida). Cuando esté activa, el resto '
        'la verá en el mapa y podrá navegarla.',
  ),
  HelpFaqItem(
    question: 'Llego tarde y el grupo ya ha salido. ¿Qué hago?',
    answer:
        'Al pulsar Navegar puedes elegir ir a la cabecera (ruta hacia su posición) '
        'o ir al destino del grupo. Cuando te acerques al trazado, seguirás la ruta '
        'compartida.',
  ),
  HelpFaqItem(
    question: 'He marcado una avería / emergencia. ¿Cómo la quito?',
    answer:
        'Pulsa el botón circular con el check (del color del aviso). Eso indica '
        '«Ya estoy OK» y retira el aviso para el grupo. No hace falta el banner '
        'naranja: a quien avisa no se le muestra.',
  ),
  HelpFaqItem(
    question: '¿LocMotos llama al 112 sola?',
    answer:
        'No. En Urgente · 112 la app puede abrir el marcador y copiar la ubicación, '
        'pero la llamada la haces tú. Los contactos personales se avisan a mano '
        '(SMS/WhatsApp) si lo eliges.',
  ),
  HelpFaqItem(
    question: '¿El intercom funciona sin Wi‑Fi?',
    answer:
        'Necesita conexión de datos (o Wi‑Fi). Sin red no hay audio del canal. '
        'El creador debe tener el intercom activado en opciones del grupo.',
  ),
  HelpFaqItem(
    question: 'No oigo / no me oyen en el intercom',
    answer:
        'Revisa Hablar y Oír en el mapa, los permisos de micrófono, el Bluetooth '
        'del casco y que el creador tenga el intercom activo. Prueba a salir y '
        'volver a entrar al mapa del grupo.',
  ),
  HelpFaqItem(
    question: '¿Para qué sirven los radares offline?',
    answer:
        'Descargas un inventario de radares para avisarte en ruta aunque no haya '
        'buena cobertura. Conviene actualizarlos de vez en cuando; puedes configurar '
        'un recordatorio al abrir la app.',
  ),
  HelpFaqItem(
    question: 'La app se cierra o el GPS se corta en segundo plano',
    answer:
        'Es habitual en Android con ahorro de batería agresivo. Excluye LocMotos '
        'de la optimización, deja las notificaciones activas y, en ruta, usa '
        '«mantener pantalla encendida» si te resulta útil.',
  ),
  HelpFaqItem(
    question: '¿Puedo usar Waze o Google Maps en vez del GPS de LocMotos?',
    answer:
        'Sí. Desde el mapa del grupo o las acciones de navegación puedes abrir '
        'Waze o Maps hacia el destino. El navegador integrado sigue disponible '
        'para quien prefiera quedarse en LocMotos.',
  ),
  HelpFaqItem(
    question: 'Entrada de invitado: ¿se guarda algo?',
    answer:
        'No de forma permanente. Al cerrar sesión de invitado se pierde el acceso '
        'y no hay recuperación. Si quieres guardar grupos y perfil, crea una cuenta.',
  ),
  HelpFaqItem(
    question: 'Olvidé la contraseña de usuario (sin correo)',
    answer:
        'Necesitas la clave de recuperación que se mostró al registrarte. Sin ella '
        'no hay restablecimiento. Si te registraste con Google o correo, usa el '
        'flujo de recuperación de ese proveedor.',
  ),
  HelpFaqItem(
    question: '¿Mis datos se comparten fuera del grupo?',
    answer:
        'La posición y avisos del grupo van a los miembros de ese grupo. No publiques '
        'el código en sitios abiertos. Consulta la política de privacidad en Acerca de.',
  ),
  HelpFaqItem(
    question: 'La pantalla en horizontal se ve distinta',
    answer:
        'Es normal: el mapa y el navegador reorganizan botones y avisos para el '
        'manillar. Los controles de emergencia suelen ir a un lado y las acciones '
        '(pelotón, navegar…) abajo o a la derecha.',
  ),
  HelpFaqItem(
    question: '¿Cómo contacto con soporte?',
    answer:
        'Desde Ayuda o Acerca de LocMotos puedes escribir al correo de soporte. '
        'Describe el móvil, la versión de la app y qué estabas haciendo cuando '
        'ocurrió el problema.',
  ),
];
