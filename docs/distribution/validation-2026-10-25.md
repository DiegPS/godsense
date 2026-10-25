# Validación local — 25 de octubre de 2026

GodSense incorpora el búho cartógrafo en la barra superior, el icono nativo
de Windows y las imágenes del MSIX. El original transparente y los prompts
están en [branding](../../design/branding/README.md). La aplicación carga el
PNG pequeño; el original de alta resolución no se incluye en el bundle.

## Evidencia de esta revisión

- Build debug y recarga en caliente aprobadas; consulta de errores de Flutter
  después de la recarga sin incidencias.
- Analizador sin incidencias; 375 pruebas unitarias/de widgets aprobadas,
  15 omitidas por sus condiciones de entorno. Cobertura de aplicación: 66,6 %.
- Cuatro suites nativas de DartCV aprobadas: 16 pruebas en procesos aislados.
- Perfil Windows: seis cambios iniciales con máximo de 39,970 ms;
  18 cambios habituales con máximo de 16,511 ms; 18 cambios durante captura
  con máximo de 13,705 ms. Captura: 47 frames válidos, cero errores.
- Tres refrescos del catálogo de IA completados; intervalo máximo del hilo
  de eventos de 21,815 ms durante esa prueba.
- Nueve frames del ICO decodificados y verificados. PowerShell 5.1 y 7 producen
  exactamente el mismo archivo.
- Build release y chequeo de arranque de ocho segundos aprobados. Se extrajo
  el icono del ejecutable para confirmar que contiene el búho y se revisaron
  Inicio, Mapa y Coach en la aplicación real.
- Integración adicional con Kilo 7.5.9 instalado aprobada: arranque aislado,
  autenticación local, health, catálogo, SSE y ciclo de vida de sesión.
  OpenCode y la inferencia generativa quedaron omitidos por configuración.
- Registro de desarrollo del paquete con identidad oficial completado y estado
  Windows `Ok`; ejecución desde su AppID revisada. No se instalaron certificados
  ni se cambió el modo de desarrollo que ya estaba habilitado. Esto no prueba la
  instalación de una descarga firmada por Store.
- Seis imágenes de Store generadas con widgets reales y datos de demostración,
  sin perfiles, conversaciones, micrófono ni captura del escritorio del usuario.
  [Fuentes, imágenes y manifiesto](../../design/store/README.md).
- Tipografía de controles y ListTile fijada explícitamente a InterVariable;
  diez comprobaciones de tipografía/controles y la exportación visual aprobadas.

Informe local de perfil:
`build/performance/navigation-ddb4f33e62f54a3b87b4967a2f80d955.json`.
Registro de verificación: `build/final-cartographer-verification.log`.
Integración Kilo: `build/final-cartographer-kilo-integration.log`.
Los informes bajo `build/` son artefactos locales y no se versionan.

## Aceptación que sigue pendiente

Una partida real debe confirmar la conexión con Riot, el cambio entre fases,
las escrituras explícitas de runas/items y el overlay sobre League con la
calibración del monitor actual. La pantalla de la calibración guardada no está
disponible en esta sesión; el aviso y los reintentos funcionan, sin sobrescribir
la selección del usuario. No se detectó un proceso de League en esta revisión.

Siguen pendientes instalación desde un paquete firmado y WACK.
El envío a certificación se completó el 25 de octubre de 2026; no equivale a
aprobación ni publicación. El registro de desarrollo sí se comprobó con la identidad oficial.
WACK se intentó ejecutar y Windows exigió elevación; la sesión no está elevada. El candidato MSIX
sin firma, su validación con MakeAppx y la ejecución portable no equivalen a
certificación ni a publicación. Véase la [guía de Store](microsoft-store.md).

Partner Center ya contiene el MSIX 1.0.1.0 con validación de aceptación
`Validated`. Propiedades, privacidad y justificación de `runFullTrust` están
guardadas; la publicación quedó manual. La ficha es-MX está completada con
descripción, ocho características, seis imágenes sintéticas y sus leyendas.
Se guardó precio base cero (MXN), audiencia pública y 240 mercados. La revisión
por mercado mostró precios cero. El titular completó personalmente la aceptación
IARC; la clasificación guardada muestra, entre otras, ESRB E10+, PEGI 3 y USK 6.
El identificador IARC figuraba pendiente antes del envío.

Microsoft recibió el envío 1 (`1152921505702228590`) y Partner Center confirmó
«En proceso de certificación»: envío completado, preprocesamiento en curso,
certificación y publicación sin iniciar en esa observación. La publicación
continúa en espera manual y requiere «Publicar ahora» después de la aprobación.
Comprobante local: `build/publication-proof/store-submitted-certification.png`.
El estado visible del portal es la evidencia de recepción; no se presenta WACK
ni la aceptación en una partida real como pruebas completadas.

El candidato actualizado procede del commit limpio `91904a5` e incorpora la
corrección de tipografía. Build release aprobada; MakeAppx validó, extrajo y
verificó identidad y hashes. El ejecutable extraído permaneció abierto durante
ocho segundos. La prueba no equivale a instalación firmada ni a WACK.
Paquete: `build/store/20261025-133931-31e18bbb/DiegPS.GodSense_1.0.1.0_x64.msix`.
SHA256: `c817048c5e56f135488f3ff6eee3c588657bd7d9ae0484704dae98390fab4155`.
Se prepararon [instrucciones de certificación](../../design/store/certification-notes.txt)
sin credenciales ni cuentas personales.

Se consultó AirDown en modo lectura: ya tiene clasificación IARC y utiliza
`support@diegps.com`. GodSense usa ahora ese mismo contacto público. Teléfono,
direcciones, código postal, ciudad, estado y país de la ficha están vacíos.

La política pública en `https://diegps.com/godsense/privacy` se actualizó para
explicar IA opcional, transcripciones, audio temporal y límites de borrado.
Las imágenes públicas anteriores se sustituyeron por las vistas de demostración,
incluidas las variantes adaptables y la vista social. Despliegue Wrangler
verificado en el dominio, versión `b232e523-973a-4b64-afb4-ef9148060271`.
Cambios de GodSense en el repositorio web: `f723c35` y `052ffd4`; se conservaron
los cambios locales previos del sitio al desplegar. El PNG público de Scout se
descargó y su SHA256 coincidió con la imagen de demostración preparada.

Las pruebas generativas de Kilo/OpenCode requieren configuración explícita de
su entorno. Las omisiones de esas pruebas no se presentan como nuevas llamadas
de inferencia aprobadas.

El contacto de la política de GodSense se cambió al alias público de soporte
y se desplegó con Wrangler, versión `25b8910e-e66f-4ba2-9c5c-3b124618c2fc`.
Build y comprobación TypeScript aprobadas; el HTML público contiene el enlace
`mailto:support@diegps.com`. Commit web `cdcd278`, publicado en `origin/main`.
