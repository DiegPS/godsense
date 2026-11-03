# Fluidez de GodSense en Windows

## Revisión del detalle de Scout — 2 de noviembre de 2026

Se volvió a ejecutar `tool/profile_windows.ps1` sobre el árbol de trabajo
actual, después del rediseño, conservando sus límites de 100 ms para navegación
y 250 ms para el intervalo del event loop. El informe nuevo terminó y aprobó:
`build/performance/navigation-407973d86bb645a89b3609451cc087e7.json`.

| Escenario en profile | Navegación p95 | Construcción p95 | Rasterizado p95 |
| --- | ---: | ---: | ---: |
| Primera visita | 20,206 ms | 11,960 ms | 3,010 ms |
| Cambios repetidos | 16,449 ms | 2,348 ms | 2,470 ms |
| Navegación con captura | 13,732 ms | 2,282 ms | 2,368 ms |

Hubo 47 capturas sin errores. El intervalo máximo del event loop fue 42,068 ms
en la primera visita, 23,483 ms en navegación repetida y 22,822 ms con captura.
El catálogo real completó sus tres refrescos, con máximo intervalo de 16,709 ms.
Las cifras de navegación anteriores (19,077 / 13,478 / 11,703 ms) eran menores;
estas dos ejecuciones no constituyen una comparación controlada de causa y efecto.

También se midió la instancia debug que el usuario tenía abierta, con su
historial local: 18 cambios de página, 16 aperturas/cierres del primer detalle
y ocho desplazamientos animados. Se restauraron la pestaña, las expansiones,
el desplazamiento y el foco al terminar. Navegación máxima: 74,228 ms;
apertura/cierre máximo: 45,833 ms; construcción p95: 11,518 ms;
rasterizado p95: 5,637 ms; máximo intervalo del event loop: 76,420 ms.
Evidencia: `build/testing/scout-redesign-live-stress.txt`. Esta segunda medición
es debug y no se compara directamente con profile. No hubo errores de ejecución.

El perfilador general no abre el detalle de Scout; esa interacción se comprobó
por separado en debug. Estos resultados no validan una partida real activa ni
garantizan que todos los cuadros cumplan 16,7 ms. No se repitió la antigua suite
completa de 736 pruebas y 131 casos de interfaz durante esta revisión.

## Revisión de carga de páginas — 31 de octubre de 2026

Se midió el árbol de trabajo con la renovación visual y los cambios de Scout
presentes, no únicamente el commit `668473a`. El inventario inicial está en
`build/testing/speed-review-20261031-source-before.json`; esos cambios previos
se conservaron. La medición inicial aprobó con p95 de 27,857 ms en la primera
visita, 14,072 ms en navegación repetida y 11,787 ms con captura. No reprodujo
las antiguas congelaciones de varios segundos.

Se reprodujo una carga innecesaria al redimensionar: `Offstage` conserva las
páginas pero sigue realizando su layout. Una página oculta volvía a calcular
su distribución para cada ancho nuevo. `RetainedPageStack` ahora evita propagar
esos cambios de tamaño al contenido oculto y realiza su layout con las medidas
actuales al volver. No desmonta páginas ni pierde borradores/desplazamiento.
Las actualizaciones propias de los widgets ocultos pueden seguir ejecutándose;
no se afirma que toda su actividad quede suspendida.

La regresión se reprodujo antes del cambio (`page-loading-layout-red.log`) y
las seis pruebas de retención/desplazamiento aprobaron después
(`page-loading-layout-final.log`), dentro de `build/testing/`. Comprueban también
la actualización de datos durante la ocultación y el ancho correcto al volver.

Profile posterior: primera visita p95 **19,077 ms**, navegación repetida
**13,478 ms**, navegación con captura **11,703 ms**, 47 capturas sin errores y
máximo intervalo del hilo de eventos de 26,134 ms durante el catálogo real.
Informe: `build/performance/navigation-2d19fd10770742f8aea637afb81fb191.json`.
La variación respecto a la primera medición no se atribuye íntegramente a este
cambio; la prueba de regresión demuestra el trabajo de layout que se evita.

El nuevo `tool/profile_page_resize.dart` visita las seis páginas y realiza
24 cambios de tamaño nativos, restaurando el tamaño/posición originales.
Resultado: p95 de 33,301 ms, máximo de 53,860 ms e intervalo máximo del hilo
de eventos de 33,807 ms. Log: `build/testing/page-loading-resize-profile.log`.
Estas mediciones corresponden al equipo/configuración actuales y no equivalen
a una partida real ni a cargar una biblioteca de historial de cualquier tamaño.

Validación posterior: 736 pruebas de base aprobadas y 30 omisiones explícitas
(`page-loading-base-final.log`), 131 casos de interfaz en el motor Windows
(`page-loading-windows-ui.log`), y analizador limpio para la implementación,
la regresión y la herramienta (`page-loading-analysis-final.log`). Los logs
están en `build/testing/`. La prueba de interfaz conserva borradores, navega
entre las seis páginas y comprueba ventanas pequeñas y texto ampliado.
El arranque debug y la recarga en caliente (317 ms) aprobaron, con captura DXGI
activa y sin excepciones reportadas por Dart MCP. Se cerró la aplicación al
terminar; la calibración guardada no se cambió.

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

## Clics de navegación y cierre del HUD (2026-11-01)

La navegación superior no participa en el gesto para mover la ventana. Un
`onPanStart` ancestral cancelaba clics de ratón con un desplazamiento vertical
pequeño: la regresión reproduce una pulsación de Ajustes, Coach y Scout con
8 píxeles de movimiento a 900 y 1400 píxeles de ancho. La marca y el estado
conservan sus áreas explícitas de arrastre.

En Windows, los mensajes de todas las ventanas se entregan a los delegados del
motor para permitir callbacks de audio. Al destruir una vista, el controlador
se desvincula de la ventana **antes** de llamar a
`FlutterDesktopViewControllerDestroy`: esa llamada genera mensajes HWND
sincrónicos durante la destrucción. Reenviarlos a un controlador que ya perdió
su vista producía un acceso nulo en `FlutterWindowsView::GetEngine`, confirmado
con el volcado de Windows.

El cierre en cascada conserva los completers de los padres al cerrar hijos.
Borrarlos durante un cierre anidado dejaba la operación esperando para siempre.
Las pulsaciones repetidas de cerrar comparten una única operación, y las
notificaciones de cierre duplicadas son idempotentes.

Verificación local:

```powershell
flutter test test/presentation/titlebar_navigation_test.dart test/presentation/window_cascade_close_test.dart test/widget_test.dart test/presentation/retained_page_stack_test.dart --no-pub
flutter test integration_test/ui/native_window_test.dart -d windows --no-pub
```

La prueba nativa conserva el proceso principal, abre y destruye cuatro overlays
adicionales (visibles y ocultos) y vuelve a navegar después de cada cierre.
El cierre de toda la aplicación también se comprueba manualmente en el proceso
real; no se representa como un widget test que podría ocultar un crash nativo.
