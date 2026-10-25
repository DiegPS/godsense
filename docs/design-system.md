# GodSense: sistema visual

## Fuente de verdad

- `lib/presentation/shared/gs_tokens.dart`: colores semánticos y medidas.
- `lib/app/godsense_theme.dart`: configuración de componentes Material.
- `lib/presentation/shared/godsense_ui_components.dart`: componentes compartidos.
- `lib/presentation/shared/design_system_previews.dart`: catálogo visual sin dependencias nativas.

## Reglas

La marca es el búho cartógrafo, con exterior transparente y cara blanca opaca.
La barra superior carga el PNG de 64 píxeles a 28 píxeles lógicos. El master no
se incluye en el bundle. Consulta [branding](../design/branding/README.md) para
regenerar el ICO y los PNG de la aplicación.

1. Controles de 40 píxeles lógicos como mínimo; 48 para acciones grandes.
   Compacto reduce padding horizontal, no la altura. Aumentar la altura con el
   escalado de texto; no desactivar el escalado de Windows.
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

## Verificación

`flutter test test/presentation` cubre componentes, Coach, Scout, voz y HUD.
`unified_controls_test.dart` comprueba alturas al 100/150/200 %, teclado y carga.
`design_system_visual_test.dart` conserva una referencia visual con fuentes reales.
Las pruebas de widgets no sustituyen la revisión de todas las fases con datos
reales, escalado de monitor y multiventana en Windows.
