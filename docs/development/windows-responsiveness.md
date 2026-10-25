# Fluidez de GodSense en Windows

Revisión del 24 de octubre de 2026, Flutter 3.47.2 / Dart 3.13.2.

## Causas corregidas

- La captura DXGI se invocaba desde un isolate Dart, pero el handler C++ del
  canal se ejecutaba en el hilo de la ventana. Enumerar pantallas, crear el
  dispositivo y esperar/copiar frames bloqueaba la cola de mensajes de Windows.
  Ahora un worker C++ serial conserva los recursos DXGI; una ventana de mensajes
  devuelve los resultados al hilo de plataforma. La cola está limitada y el
  worker se une y libera sus recursos al cerrar el plugin.
- Las pantallas se enumeraban en cada captura. Se reutilizan durante cinco
  segundos y se invalidan ante un error. Una pantalla ausente provoca reintentos
  progresivos de 1, 2, 4 y 8 segundos, en lugar de seis intentos por segundo.
- El logger abría, escribía y sincronizaba el disco en cada entrada desde Dart.
  Ahora las operaciones son asíncronas, seriales y con una cola limitada. La
  inicialización no retrasa la primera ventana. Exportar y borrar respetan el
  orden de las escrituras pendientes.
- La búsqueda de procesos de League hacía Win32 síncrono en el hilo de Dart UI.
  Ahora se ejecuta en un isolate y comparte las búsquedas simultáneas.
- Cada cambio de pestaña desmontaba la pantalla anterior. Las pantallas se
  montan al visitarlas y se conservan, con foco y tickers deshabilitados al
  ocultarlas. Esto conserva borradores, subpestañas y desplazamiento.
- El overlay se creaba a pantalla completa incluso para ocultarlo al inicio.
  Ahora se crea al mostrarlo por primera vez.
- El método de arrastre de la biblioteca bloqueaba la respuesta del canal
  durante el bucle modal de Windows. Ahora publica el mensaje de movimiento.
- Flutter se inicializaba en una zona y ejecutaba la aplicación en otra. La
  inicialización y el arranque ahora comparten la zona protegida.

## Cierre nativo de accesibilidad

La prueba real de navegación produjo un cierre con código `0xc0000409`.
El minidump, abierto con CDB y símbolos del SDK, mostró `std::bad_alloc` en
`ui::AXNodeData::GetStringAttribute`, desde `AXPlatformNodeWin::get_accValue`
y UI Automation. Antes del cierre aparecía `Nodes left pending by the update`.

El único Slider de Material de GodSense creaba un OverlayPortal activo incluso
estando su pestaña oculta. Coincide con
[flutter/flutter#190357](https://github.com/flutter/flutter/issues/190357) y
[la corrección #193372](https://github.com/flutter/flutter/pull/193372), fusionada
el 19 de octubre y ausente en el SDK 3.47.2 usado aquí.

`GsSlider` utiliza un track sin OverlayPortal y conserva teclado y semántica de
slider. El workaround se puede retirar cuando la versión mínima de Flutter
incluya la corrección y la prueba Windows vuelva a pasar.

## Medición reproducible

```powershell
.\tool\profile_windows.ps1
```

El runner ejecuta la aplicación real en profile, mide navegación fría y
repetida, captura una región real con DXGI mientras navega, y registra tiempos
de construcción, rasterizado y respuesta del event loop. Exige un informe
nuevo terminado: `flutter run` puede devolver cero aunque el proceso nativo
haya fallado. Por defecto exige navegación menor de 100 ms, ninguna pausa del
event loop mayor de 250 ms y al menos diez capturas sin errores.

Primera ejecución completa con las correcciones:

| Escenario | Navegación máxima | Construcción p95 | Rasterizado p95 |
| --- | ---: | ---: | ---: |
| Primera visita | 27,1 ms | 11,3 ms | 4,4 ms |
| Visitas repetidas | 12,9 ms | 1,8 ms | 3,0 ms |
| Visitas con captura DXGI | 17,9 ms | 1,7 ms | 3,0 ms |

La prueba completó 46 capturas sin errores. Estos valores corresponden a esta
máquina y esta configuración. La medición inicial debug tenía una pausa máxima
de 603,9 ms y una construcción máxima de 539,0 ms; no se calcula un porcentaje
de mejora entre debug y profile porque no son modos comparables.

Esta prueba no simula una partida completa de League, inferencia de cada
proveedor de IA ni la instalación de todos los modelos de voz. Sus resultados
no sustituyen esas validaciones.

El perfilador tiene un límite total de 90 segundos y espera como máximo cinco
segundos por frame. Si la ventana no puede renderizar (por ejemplo, escritorio
bloqueado o ventana minimizada), termina con error en vez de quedar esperando.
La ventana debe permanecer visible durante la medición. Los marcadores de etapa
permiten identificar dónde se detuvo una ejecución incompleta.

## Catálogo de modelos de IA

Una medición adicional de tres recargas del catálogo Kilo real reprodujo una
pausa de 241,4 ms en el event loop. El cliente compartido decodificaba el JSON
y construía los modelos de todos los proveedores en el isolate de la interfaz,
incluidos los proveedores desconectados.

`BackgroundCatalogRuntimeClient` ejecuta esa operación de lectura en un isolate
con su propio cliente HTTP y reutiliza una petición en curso por cliente. El
worker recibe solo endpoint, directorio y timeout; no captura recursos de UI ni
el puente de prompts. Se conserva el parser del paquete compartido, sin copiar
sus reglas de selección o autenticación. Las operaciones de conversación y
autenticación siguen utilizando el cliente compartido.

El perfilador registra tres recargas, cantidades de proveedores/modelos y la
pausa máxima del event loop. No escribe credenciales, contenido del catálogo
ni mensajes del usuario. Con un runtime listo exige que las recargas terminen
y que la pausa no exceda 100 ms. Si no hay runtime listo, informa explícitamente
que esa parte no se pudo medir. Las pruebas locales cubren autenticación,
peticiones simultáneas, respuesta malformada, reintento, timeout y cierre.

La repetición en profile con el catálogo real (333 modelos conectados) redujo
la pausa máxima durante su recarga de 241,4 a 33,5 ms. La petición completa
sigue tardando aproximadamente un segundo; ese tiempo ya no congela la UI.
En esa ejecución la navegación repetida tuvo un máximo de 13,7 ms y la
navegación con captura de 12,0 ms, con 47 capturas y ningún error. Son medidas
de esta máquina, no garantías para cualquier hardware.
