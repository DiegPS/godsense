# Ajustes por tareas del usuario

## Organización

- **Perfiles de Scout:** seleccionar un historial local o seguir la sesión de
  League, sin cambiarla. Reutiliza el selector de Scout y recuerda la elección.
  Véase [Perfiles de Scout](scout-profiles.md).
- **Juego y HUD:** activar la información sobre League, frecuencia de consejos,
  área del minimapa, paneles visibles y comprobación de requisitos. Explica que
  HUD es la información superpuesta, cómo moverla y por qué algunos ajustes
  pueden estar administrados por el motor. El idioma fijo no parece un selector.
- **Voz y micrófono:** dos funciones independientes. En escritorio se presentan
  lado a lado; por debajo de 1000 de ancho local se apilan sin desmontar su
  contenido. No se fijan alturas a campos, etiquetas ni mensajes.
- **IA del coach:** preparar un motor, elegir el modelo y conectar una cuenta
  cuando sea necesaria. Instalar no equivale a iniciar; solo un motor puede
  estar activo. Descargar el motor no descarga modelos locales de IA: requiere
  Internet para consultar al proveedor. No se cambió ese contrato.
- **Datos y privacidad:** plazos de conservación, exportación y limpieza de
  registros vencidos separados del borrado definitivo. El borrado mantiene
  confirmación e informa qué conserva y qué elimina.

Las preferencias existentes conservan claves y valores. No se migran ni se
borran datos. Cambiar de apartado devuelve su scroll al inicio para evitar
mostrar el centro de un formulario distinto. Los errores no se ocultan.

## Micrófono y respuesta hablada

El micrófono convierte audio en una pregunta; la voz reproduce la respuesta.
Activar una función no activa la otra. Desactivarlas conserva sus preferencias
y deshabilita sus controles, con explicación visible. La prueba física de
micrófono es independiente y funciona sin activar las preguntas al coach.

El reconocimiento instalado se comunica como estado, separado de los campos.
La reducción de ruido es un interruptor de preferencia, no un botón de acción.
La prueba de micrófono explica su duración y que no consulta al coach.
Idioma, voz y velocidad preceden a la prueba de respuesta. El botón Detener
permanece disponible durante reproducción, incluso con otros controles bloqueados.

En opciones avanzadas se administra el motor y, si corresponde, su muestra WAV
autorizada y transcripción. Los dos modelos Piper tienen nombres distinguibles.
Eliminar una voz descargada está separado de Probar voz y pide confirmación.
El audio se procesa localmente, pero la consulta textual de IA y el contexto
necesario pueden enviarse al proveedor: no se promete un coach completamente offline.

## Calibración e instalaciones

La calibración manual indica que sus unidades son píxeles de pantalla. Sus
campos ocupan altura natural y muestran validación para enteros y dimensiones
positivas. Restablecer el área pide confirmación. Los fallos de guardado y
restablecimiento muestran un aviso sin lanzar una excepción sin gestionar.
El diálogo es dueño de sus controladores: los libera cuando se desmonta, no
al recibir el resultado antes de terminar la transición de cierre.

El panel de motores conserva instalación, progreso, cancelación, reintento,
inicio, detención y elección de modelo/cuenta. La persistencia posterior a una
operación asíncrona usa el servicio capturado, no un WidgetRef ya desmontado.

## Verificación y límites

Los tests cubren independencia de funciones, controles deshabilitados sin
pérdida de preferencias, confirmación de eliminación, progreso y errores,
cambio de motores con sus valores por defecto, apartados en ventana estrecha
y de escritorio, opciones avanzadas con texto ampliado y validación manual.
Se conservan las pruebas de ciclo de vida de motores y los recorridos de datos.

Las capturas de revisión se generan con widgets reales y datos sintéticos
explícitos en `build/settings-ux/screenshots`; no sustituyen imágenes de Store.
Las pruebas de UI no certifican hardware de audio, descargas remotas ni una
sesión real de League. No se publica GodSense ni se modifica OnAuto por esta revisión.

Resultado local: `dart analyze --fatal-infos` sin incidencias; suite completa
con 736 aprobadas, 30 omitidas y cero fallos (1 min 8 s). Las siete capturas
de revisión se generaron correctamente; se inspeccionaron Voz y privacidad.
Logs: `build/settings-ux-final-analysis.log`, `build/settings-ux-final-tests.log`
y `build/settings-ux-screenshots.log`.
Arranque nativo Windows y hot reload correctos, sin errores de Flutter en el
inspector. Log: `build/settings-ux-windows.log`. La app queda abierta para revisión.
