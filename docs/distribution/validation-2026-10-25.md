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

También siguen pendientes instalación con identidad oficial, WACK y envío a
Store. La sesión de herramientas actual no está elevada. El candidato MSIX
sin firma, su validación con MakeAppx y la ejecución portable no equivalen a
certificación ni a publicación. Véase la [guía de Store](microsoft-store.md).

Las pruebas generativas de Kilo/OpenCode requieren configuración explícita de
su entorno. Las omisiones de esas pruebas no se presentan como nuevas llamadas
de inferencia aprobadas.
