# Verificación local de Windows

GodSense valida el código y genera la aplicación sin depender de GitHub Actions
ni de otro ejecutor remoto. Desde la raíz del repositorio ejecuta:

```powershell
.\tool\test_all.ps1 -RunFreeInference
```

Este es el recorrido ampliado: verificación de Windows, pruebas de la aplicación
real, DartCV nativo, mediciones de fluidez, compilación release, motores de IA
instalados y voz local. Las etapas principales continúan aunque falle otra,
guardan sus logs y terminan con un informe conjunto. `-RunFreeInference` permite
las consultas sintéticas al modelo gratuito de Kilo; no selecciona modelos de
pago como alternativa.

El flujo completo ejecuta las pruebas que requieren motores instalados una
sola vez, en la etapa `installed-runtimes`, con sus variables y modelos de prueba.
El inventario compartido está en `tool/testing_targets.ps1`. Evita compilar una
primera copia que acabaría omitida por falta de entorno. La invocación
independiente de `verify_windows.ps1` conserva sus integraciones habituales;
las integraciones nuevas que no figuren en ese inventario también se ejecutan.

La meta de cobertura combinada es **100 %**. El comando falla mientras no se
alcance; no convierte omisiones en éxitos ni modifica el código para ocultar
líneas sin cubrir. Cada ejecución guarda `summary.json`, logs, LCOV e informe
por archivo en `build/testing/runs/<fecha-hora>/`. Solo combina informes nuevos
de esa ejecución y registra los hashes del código, tests, dependencias, scripts
y fuentes nativas probados. Si cambian durante la pasada, el resultado no se
certifica. El porcentaje de
líneas medidas y los archivos sin medir se muestran por separado.

Las pruebas de `integration_test/ui/` abren el motor Windows. Recorren las seis
pestañas, conservan formularios, muestran fases de coach y partida, completan
la guía inicial y prueban exportación, cancelación, errores del diálogo de
archivos y borrado confirmado. Otro recorrido usa el arranque y la ventana
nativa de producción. Usan preferencias y SQLite aislados y datos sintéticos;
no borran datos personales ni necesitan una partida real.

Se prueban tamaños de ventana desde 900 × 600 y escalas de texto de hasta 200 %,
el detalle de jugadores y habilidades, gráficos y eventos, y la creación,
visibilidad y reutilización del overlay. Con inferencia habilitada, otro
recorrido envía una pregunta desde el Coach real, cambia de pestaña mientras
responde, recupera la conversación y limpia el historial.

Otros recorridos escriben búsquedas de Scout, recuperan errores y actualizan
perfiles. Los controles de ajustes recorren los ocho tipos de voz y sus valores
predeterminados, progreso de descarga, errores y detención. Los diálogos de IA
usan credenciales ficticias: prueban entrada oculta, cancelación, códigos vacíos,
conexión y desconexión contra un controlador de autenticación simulado.

La conversación con Kilo real comprueba preguntas repetidas, cancelación y
reinicio. Cada respuesta se vincula al identificador de su pregunta. Tras una
cancelación se retira el contexto del runtime; el siguiente restaura el historial
previo y excluye los turnos cancelados, cuya marca se conserva localmente.

El recorrido de sesión de League encadena selección, partida, interrupción,
recuperación, postpartida y reconexión contra transportes simulados. No sustituye
una prueba con el cliente de League y una partida real. Los modelos de voz no
instalados quedan explícitamente omitidos; no se descargan automáticamente.

Para preparar voluntariamente todos los motores de voz antes de la pasada
completa, ejecuta lo siguiente, sin otra invocación Flutter en marcha:

```powershell
.\tool\prefetch_voice_test_models.ps1
flutter test tool/prepare_voice_fixtures_test.dart --reporter expanded
```

La descarga comprueba HTTPS, tamaño y SHA-256. El instalador de producción
extrae y valida las copias de prueba en `build/testing/voice-models`; reutiliza
modelos ya instalados sin modificarlos. El manifiesto generado permite probar
Supertonic, Piper México, Piper España, Kitten, Kokoro, Matcha, Pocket y
ZipVoice. Cada motor corre en un proceso separado y debe sintetizar audio,
cancelar una petición y volver a sintetizar tras reinicializarse. Las pruebas
de reconocimiento alimentan el worker real con audio público, con reducción
de ruido activada y desactivada. Esto no comprueba micrófonos ni altavoces
físicos.

Los workers nativos guardan su cobertura mediante el servicio de la VM antes
de cerrarse. El recolector solo se importa desde pruebas y solo actúa cuando
el runner configura `GODSENSE_NATIVE_COVERAGE_DIR`. Así se contabilizan líneas
realmente ejecutadas en isolates que ya terminaron al finalizar la prueba.
El objetivo global sigue siendo 100 %: el piso del 65 % de la etapa base no
reemplaza ese objetivo. Un informe inferior al objetivo mantiene el resultado
global en fallo, aunque las pruebas funcionales hayan pasado.

Para ejecutar únicamente la verificación base:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\verify_windows.ps1
```

El flujo resuelve dependencias, ejecuta el analizador, corre pruebas unitarias y
de widgets con un piso local de cobertura del 65 %, ejecuta cada archivo de
integración en un proceso separado y finalmente genera la build release de
Windows y comprueba que el ejecutable arranca.

Ejecuta un solo comando Flutter de pruebas o compilación a la vez en este
workspace. Las pruebas unitarias también preparan los assets nativos y pueden
chocar con una DLL cargada por otra prueba. Debug, profile y release comparten
`windows/flutter/ephemeral`; dos
compilaciones simultáneas pueden mezclar el motor de una configuración con el
código de otra aunque ambas compilen. El chequeo de arranque detecta esa build
inutilizable.

Las pruebas nativas de DartCV se ejecutan, archivo por archivo, en procesos
aislados del resto de la suite. Esto reproduce mejor el proceso único de la
aplicación, evita que sus recursos nativos se solapen entre archivos y conserva
toda la validación de visión.

Una reproducción mínima del aviso genérico de callbacks nativos lo aisló en
el arranque del almacenamiento persistente de `FileDownloader`, sin importar
GodSense ni DartCV. El adaptador de descargas ahora crea ese servicio al primer
uso real: comprobar modelos instalados ya no lo arranca. La regresión verifica
ese comportamiento y las pruebas de voz y ciclo de vida se repiten sin el aviso.
Una descarga real sigue usando el almacenamiento de la biblioteca; no se ha
modificado su código ni se han silenciado errores del runner.

Los archivos de integración se ejecutan por separado porque el runner de
Flutter para Windows no reinicia de manera fiable varias aplicaciones desktop
dentro de una sola invocación. Esta estrategia mantiene la suite completa y
repetible. Las pruebas que requieren servicios o modelos reales conservan sus
variables de entorno y se reportan como omitidas cuando no están configuradas.

Para ciclos de desarrollo más rápidos se pueden omitir etapas costosas:

```powershell
.\tool\verify_windows.ps1 -SkipIntegration -SkipBuild
```

El piso de cobertura también puede ajustarse explícitamente, por ejemplo:

```powershell
.\tool\verify_windows.ps1 -MinimumCoverage 70
```

Para incluir la comprobación real de fluidez y captura de pantalla antes de
generar la build final, usa `-ProfileUI`. Requiere un escritorio desbloqueado y
una pantalla disponible. Los límites y el diagnóstico están en
[windows-responsiveness.md](windows-responsiveness.md).
