# Renovación de interfaz GodSense

## Alcance

Conservar el búho e Inter Variable con una dirección editorial clara. Utilizar
`flutter_consistent_ui` como implementación de geometría y composición, no
copiar sus widgets. No modificar protocolos de League, inferencia, modelos,
credenciales, persistencia ni coordenadas físicas guardadas del HUD.

## Segunda dirección visual: editorial mineral

Se sustituyó el escritorio negro/cian por fondo mineral, tarjetas blancas,
acento violeta, tipografía oscura y estados semánticos sobrios. La cabecera de
Inicio recibe un tratamiento destacado lavanda/arena sin estadísticas falsas.
Se retiraron glows decorativos, se unificaron fondos incrustados de Coach y
Scout y se preservó la geometría de controles de la biblioteca.

El overlay conserva una paleta oscura propia y un tema local independiente:
no hereda texto oscuro del escritorio ni cambia sus coordenadas guardadas.
La verificación visual nueva se genera en `build/editorial/screenshots`, con
fixtures explícitos de demostración, sin sobrescribir capturas de Store.

Verificación de esta dirección: 725 pruebas aprobadas y 30 omitidas, sin
fallos (suite completa, 1 min 31 s). Incluye el contraste de la paleta clara,
la independencia del tema del HUD, tamaños y escalado conservados y las
referencias visuales revisadas antes de su actualización. Siete capturas
de widgets reales con fixtures de demostración pasan, incluida Inicio.
Logs: `build/editorial-final-tests.log`, `build/editorial-final-analysis.log`
y `build/editorial-screenshots.log`.
Arranque nativo Windows y hot reload correctos, sin errores de Flutter en el
inspector. El arranque usa Impeller y la captura nativa inició sin modificar
la calibración guardada. Log: `build/editorial-windows.log`.

## Bloques implementados

- Estructura compartida de páginas: título único, descripción breve, acciones
  reordenables y márgenes comunes, sobre `UiPage` y `UiPageHeader`.
- Tema completo: superficies Material coherentes, estados semánticos y foco.
- Inicio: preparación real del cliente, visión y voz, sin tarjetas de ancho
  fijo ni estadísticas ficticias. Accesos al destino que resuelve cada estado.
- En vivo: métricas y espera de partida legibles; estados vacíos consistentes.
- Mapa: acciones que se apilan, explicaciones completas y previews adaptables.
- Coach: separación clara de fase automática/manual y distribución adaptable
  sin desmontar formularios al cambiar el ancho.
- Scout: búsqueda, perfil y contenido adaptable con estados y acciones claros.
- Ajustes: secciones reconocibles y controles con altura natural.
- Barra de ventana: navegación accesible, acciones alcanzables en ventanas
  estrechas, escalado de texto, arrastre y controles nativos conservados.
- Verificación: medidas pintadas, validación, estados, callbacks, navegación,
  retención, distintos anchos/escalas, previews y arranque Windows.

## Criterios de aceptación

No alturas fijas para formularios, no recortar ayudas para hacerlos caber,
no desactivar TextScaler, no cambios de tamaño por carga ni animaciones
de entrada en actualizaciones de datos. Sin rediseñar la lógica de negocio
para resolver un problema visual. Las omisiones de pruebas externas deben
seguir identificadas como no validadas.

## Evidencia local — 31 de octubre de 2026

- `dart analyze --fatal-infos`: sin incidencias.
- `flutter test --no-pub --reporter expanded`: 724 aprobadas, 30 omitidas,
  cero fallos, 1 min 39 s tras corregir la biblioteca. Incluye las referencias
  visuales sin regenerarlas.
- Recorrido de Inicio, En vivo, Mapa, Coach, Scout y Ajustes en ventanas de
  360/672/1000/1440 y escalas 100/150/200 %, con desplazamiento y sin overflows.
- Geometría compartida hasta escala 300 % y DPR fraccionario, ayudas, validación,
  carga con texto visible, foco y captura conservados.
- Contraste de texto normal, estados semánticos y acción de cierre: mínimo 4.5:1.
- Paginación y expansión de Scout, navegación, confirmación de reset del HUD y
  activación de acciones existentes conservadas en las pruebas.
- Seis capturas con widgets de producción y datos de demostración explícitos
  en `build/design-refresh/screenshots`. No sustituyen las imágenes de Store.
  El renderer existente permite `--dart-define=GODSENSE_CAPTURE_OUTPUT=...`.
- La referencia de componentes se revisó visualmente antes de actualizarla;
  el gate final la comparó sin `--update-goldens`.
- Aplicación Windows: arranque y hot reload correctos; el inspector detectó
  un desbordamiento al actualizar las tarjetas de preparación después del
  primer render. La regresión de la biblioteca reprodujo el fallo en filas de
  dos y cuatro columnas. La corrección conserva altura natural y propaga los
  cambios de tamaño de los descendientes; seis casos verifican crecimiento y
  reducción sin reconstruir el grid.
  El segundo arranque Windows con la corrección y hot reload pasó sin errores
  de Flutter en el inspector, también tras las actualizaciones de estado.
  En aquella comprobación se registró una calibración de
  pantalla no disponible por el módulo de visión. No se borró ni
  sustituyó esa configuración y no se presenta como un fallo de layout resuelto.

La biblioteca pasa 85 pruebas con cobertura y sus cinco pruebas de ejemplo;
`dart analyze --fatal-infos` también está limpio en ella.

Logs principales: `build/design-refresh-fixed-gate.log`,
`build/design-refresh-fixed-analysis.log`,
`build/design-refresh-fixed-windows.log`,
`build/design-refresh-screenshots-final.log`.
Las pruebas de fixtures no equivalen a una sesión física de League, captura
multi-monitor real, uso real del micrófono ni inferencia con proveedores.
La lógica y el almacenamiento de esas integraciones no se modificaron.

## Dependencia publicada y reproducible

La reorganización completa de Ajustes se describe en [settings-ux.md](settings-ux.md),
con los apartados por tarea, voz independiente, opciones avanzadas, confirmaciones
y verificaciones. No cambia datos guardados ni dependencias de los consumidores.

Corrección del scroll: `GsFeaturePage` usa UiPage sin padding exterior y aplica
los márgenes al contenido del ListView. No modifica la biblioteca ni añade
otra scrollbar; mantiene la nativa de escritorio con su espacio lateral.
Cuatro regresiones verifican viewport completo, márgenes, hit testing junto
a la cabecera y última acción accesible en 360/1000, DPR 1.25, LTR/RTL.
Junto con navegación/responsive: 18 pruebas aprobadas y análisis limpio.
Logs: `build/scroll-fix-tests.log`, `build/scroll-fix-analysis.log`.

La dependencia actual es `flutter_consistent_ui` 0.5.0, commit
`a11cd12b8b6a27dcf54a73b2c886a39986cd3938`. GodSense fija ese commit Git
en `pubspec.yaml` y `pubspec.lock`, sin depender de una ruta del equipo.
El override temporal de verificación se eliminó. No se ha actualizado el
consumidor OnAuto ni se ha publicado GodSense.

La actualización a 0.5.0 usa las políticas de borde y superficie. Se eliminaron
las tres definiciones repetidas de OutlineInputBorder del tema; el foco normal
y el foco con error comparten grosor 2. Los menús respetan ahora la superficie
elevada que el tema del producto ya declaraba. No se fuerzan estilos heredados.

Verificación de la actualización 0.5.0 desde Git: análisis limpio y suite
completa con 725 aprobadas, 30 omitidas y cero fallos (1 min 2 s). Las
referencias visuales pasaron sin regenerarlas. Logs: `build/ui-050-analysis.log`
y `build/ui-050-tests.log`.
Arranque Windows con Impeller y hot reload correctos, sin errores de Flutter
en el inspector. La captura nativa inició con la calibración existente.
Log: `build/ui-050-windows.log`.

En la adopción anterior de 0.4.1 desde Git se repitió el análisis (limpio)
y 32 pruebas de adopción, controles, paleta y navegación (todas aprobadas).
Logs: `build/ui-041-analysis.log` y `build/ui-041-integration.log`.

## Scroll y recortes de Coach (2026-11-01)

- El estado vacío del chat tiene altura natural: no comparte el límite del
  historial. Las sugerencias y sus etiquetas admiten varias líneas.
- El historial conserva su viewport independiente para no hacer crecer toda la
  página con cada conversación. Su límite depende de la altura de la ventana;
  no fija alturas a las burbujas. La barra explícita comparte controlador con la
  lista y reserva un gutter direccional de 20, superior a su grosor de 8.
- La lista no toma el controlador primario de Coach. Se desactiva únicamente su
  scrollbar automático, para evitar dibujar dos barras para el mismo historial.
- El streaming sigue la respuesta mientras se lee el final. Un desplazamiento
  del usuario hacia mensajes anteriores suspende ese seguimiento. El botón
  «Ir al último mensaje» lo reanuda. Los cambios de dimensiones del historial
  también respetan esa elección; no hay una animación nueva por cada token.
- Estado de generación, cancelación y cabeceras de burbuja permiten ajuste de
  línea. Amenazas usa una composición ajustable para campeón y ubicación.
- No se modifican geometrías globales ni la biblioteca para estos arreglos.

La regresión permanente vive en
`test/presentation/coach/coach_layout_regression_test.dart`: anchos 360/640,
texto normal/200 %, chat vacío/generando, amenazas, voz, Markdown y seguimiento
del scroll con gutter en LTR/RTL. Se conservan además las pruebas de streaming
con controlador real y del viewport general de la página.

La regresión de rueda de Windows reproduce un evento de solo 20 de subida
desde el fondo: antes volvía inmediatamente a `extentAfter=0`, en LTR y RTL.
La dirección de subida ahora suspende el seguimiento antes de evaluar la
posición nueva. Solo llegar realmente al fondo o pulsar el botón de último
mensaje lo reactiva; no se usa la antigua tolerancia de 32 para esa decisión.

## Selector de modelo en la cabecera del chat

La identidad «Motor · Modelo ▾» ahora es el control para cambiar el modelo.
Se ubica en la zona central de la cabecera, en la misma fila que el título y
las acciones cuando cabe. No añade una línea de subtítulo. Con ancho reducido
o texto ampliado pasa al grupo adaptable de acciones.
Se eliminó el bloque permanente «Proveedor y modelo» del cuerpo del chat.
En ventanas de 600 o más abre un menú anclado; en ventanas menores abre un
panel inferior con área segura y espacio para el teclado. Las opciones
comparten búsqueda por proveedor/nombre/ID, grupos por proveedor, modelo
seleccionado e indicación explícita de costo. La lista es lazy y tiene scroll
propio acotado; no descarga ni inicia otro motor al seleccionar un modelo.
Durante una generación se deshabilita el cambio para no alterar el turno.
La configuración completa permanece en Ajustes.

`ai_chat_model_picker_test.dart` verifica selección, búsqueda vacía, cierre,
modelo de pago, ventanas 360/1200 con texto al 200 %, teclado y bloqueo
durante generación. También verifica por coordenadas que título, selector y
estado compartan la misma fila a 900 de ancho con texto normal. La integración
usa una zona central opcional en la cabecera de las tarjetas; no añade lógica
de negocio a la biblioteca de controles.
