# GodSense: sistema visual

## Fuente de verdad

- `lib/presentation/shared/gs_tokens.dart`: colores semánticos y medidas.
- `flutter_consistent_ui` 0.6.0 (Git fijado a `8e774e1fab0d5b4fa370ed86dd6aa1e79368a046`):
  cálculo de geometría, controles Material y composición de formularios.
  `GsSizes.geometry` instala el perfil propio de GodSense en el tema, sin
  importar los colores ni la tipografía de OnAuto.
  `UiBorderTheme` define los bordes de los campos y sus estados, sin repetirlos
  en InputDecorationTheme. `UiSurfaceStyle` define el borde base de paneles;
  las personalizaciones nativas explícitas siguen teniendo prioridad.
  `UiControls.searchableSelect` comparte métricas y apariencia con el select
  simple, sin copiar parcialmente InputDecorationTheme. `UiDisclosure` agrupa
  opciones secundarias como proveedor/modelo y opciones avanzadas de voz: no
  es un select ni una fila permanentemente seleccionada.
- `lib/app/godsense_theme.dart`: configuración de componentes Material.
- `lib/presentation/shared/godsense_ui_components.dart`: componentes compartidos.
- `lib/presentation/shared/design_system_previews.dart`: catálogo visual sin dependencias nativas.

## Reglas

La composición de Ajustes y sus estados funcionales se describe en
[settings-ux.md](settings-ux.md). La biblioteca aporta geometría; GodSense
organiza las tareas y explica las dependencias, sin mezclar administración
de descargas con las acciones cotidianas.

La dirección actual es editorial clara: fondo mineral, superficies blancas,
tinta ciruela y acento violeta. Los colores se nombran por función (`accent`,
`focus`, `onAccent`) y no por el antiguo cian. Coach y Scout consumen los mismos
tokens; sus estados positivos/negativos tienen tintes claros y texto oscuro.
El HUD tiene una paleta independiente `GsHudColors` y `godsenseOverlayTheme()`:
mantiene contraste sobre la partida sin heredar el escritorio claro.

La marca es el búho cartógrafo, con exterior transparente y cara blanca opaca.
La barra superior carga el PNG de 64 píxeles en un espacio de 48 píxeles lógicos,
anclado abajo y desplazado 5 píxeles bajo el límite con recorte local: el búho
asoma desde la base de la barra, sin flotar ni invadir el contenido. El master no
se incluye en el bundle. Consulta [branding](../design/branding/README.md) para
regenerar el ICO y los PNG de la aplicación.

1. Controles de 40 píxeles lógicos como mínimo; 48 para acciones grandes.
   Compacto reduce padding horizontal, no la altura. Aumentar la altura con el
   escalado de texto; no desactivar el escalado de Windows.
   La biblioteca calcula altura, padding y línea tipográfica conjuntamente.
   No fijar alturas exteriores a inputs o selects: ayuda y error ocupan su
   altura natural fuera del borde. Medir el contenedor de `InputDecorator`
   y la superficie Material del botón, no el campo con toda su ayuda.
2. Espaciados en múltiplos de 4: 8 entre controles, 16 dentro de grupos,
   24 entre secciones y en márgenes de página; margen de 16 en ventanas pequeñas.
3. Inter Variable local; números tabulares. No añadir otra fuente para corregir
   un problema de restricciones o de rasterización.
4. Usar GsSectionHeading para cabeceras y GsCard para superficies. Coach comparte
   los mismos tokens. El HUD mantiene densidad propia y posiciones guardadas.
5. Acciones con botones Material, foco visible y estados deshabilitado/cargando.
   No sustituir botones por GestureDetector. Cargar no debe modificar su ancho.
6. Color acompañado de texto o icono. Estado crítico y éxito necesitan contraste
   sobre su superficie real, no solo sobre el canvas.
7. Formularios y cabeceras deben apilar sus acciones si no caben. Limitar el ancho
   del contenido a 1560 sin afectar las coordenadas físicas del overlay.
8. No introducir animaciones de entrada en cada actualización de datos.
9. `GsFeaturePage` mantiene el viewport a tamaño completo; el padding pertenece
   al `ListView`, nunca a su contenedor exterior. Así no se crea un marco fijo
   que recorte las tarjetas y la scrollbar de escritorio queda en el margen
   lateral, sin superponerse a acciones ni imágenes.

## Verificación

`flutter test test/presentation` cubre componentes, Coach, Scout, voz y HUD.
`unified_controls_test.dart` comprueba alturas al 100/150/200 %, teclado y carga.
`design_system_visual_test.dart` conserva una referencia visual con fuentes reales.
`consistent_ui_adoption_test.dart` comprueba bordes y superficies a escalas
100/150/200/300 %, ventanas de 360/1440 y DPR fraccionario, además de ayudas,
validación, campos grandes y conservación de texto y foco al redimensionar.
Las pruebas de widgets no sustituyen la revisión de todas las fases con datos
reales, escalado de monitor y multiventana en Windows.

## Adopción de la biblioteca externa

Los nombres `Gs*` siguen siendo la interfaz del producto: preservan textos,
variantes, carga, controles de voz y callbacks. `GsInput` delega en `UiControls`,
`GsSelect` usa la decoración y tipografía de `UiControlMetrics` manteniendo su
menú nativo personalizado y `gsButtonStyle` parte de la geometría de acciones
de la biblioteca. `UiControlScope` aplica esa geometría a las acciones nativas
del árbol principal, incluidos diálogos. Inter Variable, foco visible y paleta
editorial siguen perteneciendo a GodSense.

Los formularios de autenticación de IA usan `UiFormFields`, con espacio después
de cada campo completo. Los inputs de ajustes, chat y voz usan `UiControls`.
El modelo de IA conserva `DropdownMenu` con búsqueda y filtrado; solo su
decoración toma la geometría común. No se pierde esa capacidad por migrarlo
a un selector simple.

El HUD, sus coordenadas físicas y su persistencia, las conexiones con League,
el runtime de IA y los workers nativos no forman parte de esta migración.
No hay dependencia por ruta al PC del desarrollador ni copia de la biblioteca.

Verificación inicial de la adopción (31 de octubre de 2026): `flutter analyze`
sin incidencias y `flutter test --no-pub` con 716 pruebas aprobadas y 30
omitidas por sus requisitos externos. La referencia visual original pasó sin
regenerarse. Esto no equivale a una prueba física de League o del HUD en partida.

## Renovación completa

La revisión posterior usa `GsFeaturePage` sobre `UiPage`/`UiPageHeader` en las
seis secciones, `UiMetricGrid` para indicadores, `UiFormGrid` para composición
estable y `UiSplitView` para Scout. No se reserva una columna de metadatos si
no existen relaciones que mostrar. Las ayudas y los errores permanecen fuera
del borde, y los botones en curso conservan su etiqueta y dimensiones.

La barra nativa conserva arrastre, navegación y cierre. Las etiquetas dependen
del espacio medido; los auxiliares pasan a un menú en compacto. Los controles
de ventana son una excepción deliberada: sus iconos tienen un objetivo de 40
unidades independiente del escalado de texto, pero sí respetan el DPR de Windows.
No son campos de formulario. Sus tooltips sí usan el escalado normal.

El tema se compone mediante `UiTheme.apply`, con colores semánticos de GodSense.
Las pruebas de contraste comprueban texto normal con relación mínima 4.5:1.
La renovación y sus verificaciones están en [design-refresh.md](design-refresh.md).
