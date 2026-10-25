# GodSense: candidato Windows x64

Esta revisión mejora la estabilidad, la respuesta de la interfaz y los controles
de voz y HUD.

- Captura DXGI en un worker nativo, independiente del hilo de la ventana.
- Pestañas que conservan el estado, los borradores y el desplazamiento.
- Logs asíncronos con cola limitada y búsqueda de League en segundo plano.
- Catálogo de modelos de IA cargado y decodificado fuera del hilo de interfaz.
- Corrección del arranque de Flutter en zonas distintas.
- Corrección del cierre nativo de accesibilidad al ocultar el control de
  velocidad de voz; conserva teclado y lector de pantalla.
- Reintentos progresivos cuando la pantalla calibrada no está disponible,
  aviso visible y reintento manual inmediato.
- Overlay creado bajo demanda y arrastre sin bloquear la respuesta del canal.
- El interruptor del overlay se conserva al reiniciar; editar el HUD sigue
  disponible aunque esté desactivado y no cambia esa preferencia.
- Botón «Consejo ahora» en Coach para una recomendación táctica local sin
  micrófono. Se desactiva mientras la respuesta está en curso.
- Ajustes que indican el idioma real de la interfaz y ayuda para configurar
  League en modo Sin bordes cuando el overlay no aparece.
- Prueba local de micrófono: captura de hasta tres segundos, nivel de entrada,
  reproducción, cancelación y borrado del audio temporal; no requiere modelos.
- Botón «Detener voz» en la barra superior, Coach y Ajustes para cortar la
  respuesta y su cola sin desactivar las siguientes respuestas. Las síntesis
  canceladas no se reproducen.
- Estado de voz que distingue funciones apagadas, modelos ausentes, prueba en
  curso y errores. Restablecer el HUD requiere confirmación.
- Verificación local con pruebas, cobertura, perfilado y arranque real de la
  build. El ZIP incluye las DLL de Visual C++ y un manifiesto SHA256.

## Validación

- Analizador sin incidencias; suite unitaria y de widgets aprobada.
- Corpus DartCV de 866 frames: paridad de detección y cajas con la referencia.
- Profile: navegación repetida por debajo de 23 ms y navegación durante captura
  DXGI por debajo de 20 ms en la máquina de desarrollo, con 47 capturas válidas.
- Modelos reales: Canary, VAD, reducción de ruido y síntesis Supertonic.
- Runtime Kilo real: arranque local, health, catálogo y operaciones de sesión.
- Interacción Windows: cambio de pestañas, arrastre, maximizado y apertura/cierre
  de edición del overlay.

## Alcance del candidato

El ZIP es portable, x64 y sin firma digital. Extrae toda la carpeta y ejecuta
`godsense.exe`. Conserva las DLL y `data`. No incluye credenciales, partidas ni
modelos de voz; se configuran localmente desde la aplicación.

No se presenta como validación final de una partida completa de League ni de
todos los proveedores de inferencia. La publicación definitiva y la ficha de
Microsoft Store quedan pendientes de esa aceptación y de la identidad oficial
del producto en Partner Center.

Las versiones de los runtimes de IA están fijadas. Su uso y la disponibilidad
de modelos dependen del proveedor elegido; el coaching con IA es opcional.
