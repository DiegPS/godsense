# Registro de pruebas del 25 y 26 de octubre de 2026

La última pasada completa corresponde a `d95198d`, en
`build/testing/runs/20261026-180915/`: **13 737 / 15 709 líneas (87,4467 %)**.
El árbol estaba limpio y no cambiaron los archivos inventariados. Aprobaron
Windows, runtimes instalados y herramientas; el resultado global fue fallo
únicamente por la puerta de cobertura del 100 %. Aprobaron 602 pruebas de base
(24 omisiones explícitas), 16 de visión nativa y 83 casos de interfaz Windows,
además del chat real incluido en los motores instalados. OpenCode y Kilo,
streaming, conversación con cancelación/reinicio, reconocimiento de voz y los
ocho sintetizadores pasaron sus comprobaciones reales. El streaming entregó
135 fragmentos de texto. Las herramientas aprobaron ocho pruebas Python y
seis escenarios PowerShell. Navegación profile: p95 de 38,450 ms en frío,
13,633 ms en caliente y 12,080 ms con captura; intervalo máximo del hilo de
eventos durante el catálogo: 23,192 ms. Informe:
`build/performance/navigation-db50149830a64e18b8b0fb023f98719f.json`.
Estos resultados no certifican una partida real, el audio físico ni un MSIX
posterior. La puerta estricta continúa fallando y falta alcanzar el 100 %.

Después de esa pasada se reprodujeron consultas adicionales de campeones e
historial tras cerrar el controlador de League. Las continuaciones ahora
comprueban su vigencia después de cada espera y detienen la cadena al cerrarse.
Otra regresión demostró que una consulta de maestría pendiente de la selección
anterior impedía cargar la siguiente. Cada selección/cuenta tiene su generación:
la siguiente carga comienza aunque la anterior siga pendiente, y la respuesta
antigua no reemplaza sus datos ni libera el bloqueo de la solicitud nueva.
Se comprueban además los prerrequisitos del estado «Vigilando», sin fingir
reconocimiento disponible cuando faltan retratos o hay un error de captura.
Evidencia anterior a las correcciones: `build/testing/draft-lifecycle-red.log`
y `draft-generation-red.log`. La base posterior aprobó **617 pruebas con 24
omisiones explícitas**, y el analizador de `lib`, `test` e `integration_test`
no encontró incidencias (`draft-lifecycle-base.log`, `draft-analysis-final.log`).
El nuevo test de cambio de cuenta necesitó corregir su propio historial
sintético: los participantes seguían perteneciendo a la cuenta anterior y no
debían generar recomendaciones para la siguiente. Este ajuste no cambia la
regla de producción que exige historial del jugador y posición compatibles.
Esta tanda posterior requiere otra medición global de cobertura.
Los 23 casos conectados de League/Coach también aprobaron sobre el motor
nativo de Windows (`build/testing/draft-lifecycle-native-final.log`).
El arranque debug y la recarga en caliente aprobaron; Dart MCP no encontró
excepciones de runtime. La captura mantuvo el aviso controlado de la pantalla
calibrada ausente; no se modificó la calibración del usuario.

La pasada completa anterior corresponde a `8eab7df`, en
`build/testing/runs/20261026-173842/`: **13 549 / 15 676 líneas (86,4315 %)**.
Aprobaron Windows y motores instalados, sin archivos sin medir ni cambios en
los archivos inventariados; el árbol estaba limpio. La base aprobó 573 pruebas,
con 24 omisiones explícitas; visión nativa, 16; interfaz Windows, 72. Aprobaron
arranque release, fluidez, IA real, reconocimiento y los ocho sintetizadores,
además de ocho pruebas Python y cuatro escenarios PowerShell. El resultado
global sigue en fallo por no alcanzar el 100 % de cobertura. El streaming recibió
140 fragmentos de texto, sin timeout. Navegación con captura: p95 de 10,711 ms;
el intervalo máximo del hilo de eventos durante el catálogo fue de 21,839 ms.
Informe: `build/performance/navigation-d097127a84c543189b950b4593d6b16e.json`.

Las pruebas posteriores de Coach reprodujeron respuestas de importación que
intentaban actualizar un controlador cerrado, operaciones simultáneas y una
importación conjunta que podía seguir con los objetos de otra cuenta o campeón.
El controlador ahora conserva el contexto de la solicitud, serializa la
operación conjunta y descarta resultados obsoletos; una actualización equivalente
de recomendaciones no cancela la solicitud. También se verificaron los informes
por cuenta, recuperación de escritura fallida, metadatos y versiones de recursos,
enriquecimiento de League y captura con backoff. Una comprobación adicional
reprodujo un elogio de participación sólida con KDA vacío o 0/0/0; ahora necesita
evidencia positiva y ofrece una revisión general cuando no la hay.
La prueba de recuperación de captura se corrigió para admitir que, tras el primer
frame exitoso, vuelve la frecuencia normal. Evidencia inicial y corregida:
`build/testing/coach-lifecycle-red.log` y `coach-lifecycle-fixed.log`.
Aprobaron 602 pruebas de base (24 omisiones explícitas), 29 casos específicos,
17 casos en Windows nativo para League/Coach y el analizador sin incidencias.
La mejora del ejecutor evita las compilaciones duplicadas de integraciones
que se probaban sin entorno y se repetían después con los motores preparados;
mantiene la ejecución independiente y pasó seis escenarios PowerShell.
Evidencia: `build/testing/coach-lifecycle-base.log`,
`coach-lifecycle-final-focused.log`, `coach-lifecycle-native.log`,
`coach-empty-report-red.log`, `coach-lifecycle-analysis-final.log` y
`runner-inventory-regressions.log`. La base completa se ejecutó antes del último
ajuste del informe vacío; sus seis casos de informes sí se repitieron después.
La pasada `d95198d` ya incluye estas modificaciones y el último ajuste del
informe vacío, con el resultado global indicado al comienzo.
El arranque debug y la recarga en caliente aprobaron, sin excepciones reportadas
por Flutter; se mantuvo el aviso controlado de la pantalla calibrada ausente.

La pasada completa anterior corresponde a `7678388`, en
`build/testing/runs/20261026-163512/`: **13 414 / 15 593 líneas (86,0258 %)**,
sin archivos sin medir, sin cambios en los archivos inventariados y con árbol
limpio. Aprobaron todas las etapas funcionales: analizador, 527 pruebas de base
(24 omisiones explícitas), 16 pruebas de visión nativa, 60 recorridos/casos de
interfaz Windows, arranque y compilación release, procesos/catálogos de IA,
streaming, conversación y chat reales, reconocimiento de voz y los ocho motores
de síntesis con cancelación y reinicialización. También aprobaron las ocho
pruebas Python y los cuatro escenarios PowerShell de las herramientas.
La puerta global sigue en fallo únicamente por no alcanzar el 100 % de cobertura;
este resultado no certifica una partida real ni dispositivos de audio físicos.

La navegación en profile midió p95 de 52,707 ms en frío, 13,081 ms tras la
carga inicial y 14,383 ms con captura. El refresco del catálogo dejó un intervalo
máximo del hilo de eventos de 21,091 ms. El streaming real recibió 138 fragmentos
de texto antes de completar la respuesta, sin timeout. Informe de fluidez:
`build/performance/navigation-1bc4efe3e06a48d5a1ffd34d26c85f6d.json`.
Estos resultados corresponden exclusivamente a esa revisión y a este equipo.

Después de esa pasada se reprodujeron y corrigieron carreras en calibración y
voz. Un resultado antiguo podía restaurar una calibración borrada, sustituir
una selección de voz más reciente o actualizar un controlador ya cerrado.
Las escrituras solicitadas se ordenan y terminan aunque se cierre su dueño;
los resultados internos obsoletos no escriben ni modifican la interfaz. Las
lecturas esperan las escrituras sin cancelar un borrado, y los errores de una
operación anterior no bloquean ni marcan como fallida la siguiente.

También se corrigió la caché de objetos: conserva el contexto de parche,
región y versión del cliente, evita solicitudes duplicadas y rechaza respuestas
antiguas que podían reemplazar precios nuevos. La captura rechaza dimensiones
inválidas y regiones que ya no caben en su pantalla identificada, sin sustituir
una pantalla desconectada por otra.

Aprobaron 571 pruebas de base (24 omisiones por entorno), 46 casos específicos
de esta tanda y el analizador sin incidencias. En Windows nativo aprobaron los
12 casos de Scout, seis del ciclo conectado de League y 20 de ajustes, incluidos
los resultados tardíos de voz. Scout comprueba carga pendiente, fallo,
reintento, deduplicación y reapertura desde caché con su controlador real.
La prueba de imágenes utiliza respuestas locales simuladas y datos ficticios.
Evidencia: `build/testing/async-safety-base-final.log`,
`build/testing/async-safety-final-focused.log`,
`build/testing/async-safety-native-*.log` y
`build/testing/async-safety-analysis-final.log`. Los logs `async-safety-red.log`,
`queued-intent-red.log` y `calibration-refresh-red.log` conservan los fallos
previos a sus correcciones; uno de los fallos iniciales era la limpieza de una
variable de depuración en la propia prueba de imágenes, también corregida.
La pasada completa `8eab7df` ya incluye estas correcciones y registra el
86,4315 % indicado al comienzo del informe.

El arranque de producción en debug y la recarga en caliente también aprobaron,
sin excepciones de ejecución reportadas por Flutter. La compilación release y
su prueba de arranque de ocho segundos aprobaron; evidencia en
`build/testing/async-safety-release.log` y `async-safety-release-smoke.log`.
El servicio de visión conserva y reintenta una calibración cuya pantalla no
está disponible: ese error controlado sigue en los logs. Se comprobó que la
identidad guardada es una identidad de dispositivo Windows; no se borró esa
calibración ni se reasignó a otra pantalla.

La pasada `build/testing/runs/20261026-005531/`, iniciada en `3018199`,
quedó incompleta: aprobaron 519 pruebas de base (24 omisiones), pero el
recorrido de escritorio se interrumpió y Flutter informó que faltaba su
directorio temporal de escucha. Las compilaciones posteriores también
fallaron y no se generó resumen global. No se certifica esta pasada ni se
atribuye una causa definitiva a la desaparición de los temporales.
El reintento aislado del recorrido de escritorio aprobó sus nueve casos;
evidencia: `build/testing/desktop-resume.log`. Ese reintento no completa las
etapas que quedaron sin terminar en aquella ejecución.

La ampliación posterior de Scout encontró desbordamientos en tarjetas y
equipos al usar texto al 200 %. La cabecera ahora distribuye su contenido
en varias filas cuando falta espacio, permite crecer en altura y apila los
equipos en ventanas estrechas o con texto grande. Aprobaron once casos de
Scout tanto en widgets como en Windows nativo, además del analizador sin
incidencias. Los ocho casos nuevos recorren siete partidas con paginación,
apertura/cierre de diez participantes, eventos y gráfica de oro, y cambio de
cuenta con los mismos identificadores de partida para comprobar que no
conserva la expansión ni la paginación anterior. Utilizan datos ficticios y
no solicitan imágenes externas. Anchos: 640, 800, 1280 y 1600; escalas: 100 %
y 200 %. Evidencia: `build/testing/scout-history-red.log`,
`build/testing/scout-history-expanded.log`, `build/testing/scout-history-native.log`
y `build/testing/scout-history-analysis.log`. La pasada completa `7678388`
ya incluye esta corrección y sus pruebas.

La pasada completa anterior corresponde a `d96d91a`, en
`build/testing/runs/20261025-235441/`: **13 229 / 15 569 líneas (84,9701 %)**,
sin archivos sin medir y con los archivos inventariados sin cambios durante
la ejecución. Aprobaron 495 pruebas de base, las integraciones Windows,
visión, voz, fluidez y arranque release. Hubo 24 omisiones explícitas en la base.
Fallaron las pruebas reales de streaming y chat por timeout; el objetivo
del 100 % también falló. Esta revisión no tiene un resultado global aprobado.

Se reprodujo después un timeout local mientras seguían llegando fragmentos.
`dart_ai_runtime` 0.3.6 distingue inactividad de progreso, mantiene un límite
total y retira los turnos agotados. Aprobaron sus 67 pruebas y el analizador.
La repetición real de streaming en GodSense aprobó con 15 deltas de razonamiento
y 58 de texto; el razonamiento no se mostró como respuesta. La corrección
posterior quedó incluida y aprobada en la pasada completa `7678388`.

El reintento del chat real desde la interfaz también aprobó. La tanda de
seguridad aprobó 24 casos; el overlay aprobó 23 casos en Windows y los ajustes,
nueve. Se corrigieron dos fallos adicionales reproducidos por esos casos:
una consulta específica sobre dragón podía contestar con Barón si faltaba
su estado, y los ganks nativos no activaban el borde de peligro del minimapa.
El borde se comprueba mediante píxeles renderizados a escalas 100 %/200 %;
una observación ordinaria o un aviso caducado no debe pintarlo. Los estados
desconocidos de objetivos tampoco se anuncian como retiradas definitivas.
Los controles del motor comprueban preferencias de inicio automático,
bloqueo de operaciones simultáneas, resultados tardíos y recuperación de fallos.
La evidencia está en `build/testing/safety-boundaries-expanded.log`,
`build/testing/stream-progress-live.log` y `build/testing/progress-*.log`.

## Primera pasada completa

Revisión comprobada: `02b8eca0242ed31a18785cd510cae8174cf6574b`.
Evidencia local: `build/testing/runs/20261025-225725/`.
Inicio: 2026-10-26 04:57:25 UTC; fin: 05:18:44 UTC.
El árbol estaba limpio y ninguno de los archivos inventariados cambió durante
la ejecución. Este resultado corresponde a esa revisión, no certifica cambios
posteriores ni sustituye la aceptación con una partida real.

| Etapa | Resultado |
| --- | --- |
| Analizador | Sin incidencias |
| Unitarias y widgets | 442 aprobadas; 24 omisiones explícitas por entorno |
| DartCV nativo | 16 aprobadas, cuatro suites aisladas |
| Recorridos de escritorio Windows | 19 aprobados: aplicación, ventana nativa, Scout, ajustes y descarga HTTPS |
| Procesos, catálogos y conversación de IA reales | Aprobados, incluida interfaz, SSE, cancelación y limpieza |
| Reconocimiento de voz | Aprobado con audio de prueba y reducción de ruido activada/desactivada |
| Síntesis de voz | Ocho motores aprobados, generación y cancelación/reinicialización |
| Fluidez en modo profile | Aprobada; 46 capturas y cero errores |
| Build release y arranque | Aprobados |
| Herramientas de cobertura y verificación | Ocho pruebas Python y cuatro escenarios PowerShell aprobados |
| Objetivo global del 100 % | **No alcanzado** |

Cobertura combinada: **12 825 / 15 561 líneas medidas (82,4176 %)**.
No quedaron archivos de aplicación sin medir. El informe conserva las líneas
pendientes y no atribuye ejecuciones ficticias a interfaces o archivos que
solo exportan símbolos. Los archivos generados `*.g.dart` y `*.freezed.dart`
quedan fuera del alcance declarado por el recolector.

Navegación p95: 34,775 ms en frío; 9,730 ms tras la carga inicial;
10,982 ms durante captura. El intervalo máximo del hilo de eventos durante
el refresco del catálogo fue 21,385 ms. Son mediciones de este equipo y estos
recorridos, no una garantía para toda combinación de hardware o partida.

Las exportaciones de estrés utilizaron SQLite y archivos reales aislados:
8 000 registros con payload grande y 200 documentos de partidas con timelines
de unos 768 KiB por documento. Comprobaron límites explícitos de crecimiento
de memoria y pausas; no modificaron los datos del usuario.

El estado global del comando es fallo porque la cobertura sigue por debajo
del 100 %. Las comprobaciones funcionales aprobadas no cambian ese resultado.
League no está instalado en este equipo: falta una partida real, además de
la aceptación con micrófono y altavoces físicos. Consulta el alcance completo
en [la matriz de pruebas](testing-matrix.md).

## Regresiones posteriores a la pasada

Al ampliar la cobertura aparecieron dos fallos adicionales: el indicador de
oro podía desbordarse con un panel estrecho o texto grande, y los segundos
fraccionarios podían producir `15:60` en el contexto enviado al coach.
Ambos se reprodujeron antes de corregirlos. El indicador se adapta al ancho
sin truncar el valor y el tiempo usa segundos enteros.

La tanda focalizada posterior aprobó 26 pruebas, incluidas las dos existentes
del constructor de prompts. Los 17 casos del overlay también aprobaron sobre
el motor Windows. Las pruebas adicionales de voz verifican WAV PCM, limpieza
de temporales, continuación tras errores de reproducción, cancelación con
audio tardío y límite de ocho mensajes pendientes. La reproducción se inyecta:
estos casos no certifican el dispositivo físico de salida.

Analizador sin incidencias y recarga en caliente aprobada; el monitor de
Flutter no encontró errores de runtime después de la recarga. La captura
registró por separado que la pantalla de la calibración guardada no está
disponible; no se modificó esa calibración. Los logs de esta tanda están en
`build/testing/new-regression-fixed.log` y
`build/testing/overlay-native-after-fix.log`.

El 82,4176 % anterior pertenece exclusivamente a la pasada congelada de
`02b8eca`; estas pruebas posteriores requieren una nueva medición combinada.

## Segunda pasada completa

La revisión `6cc52f7` se verificó en
`build/testing/runs/20261025-232433/`, con árbol limpio y cero cambios en los
archivos inventariados durante la ejecución. Aprobaron las etapas Windows,
runtimes instalados y herramientas. La base aprobó 466 pruebas con 24
omisiones explícitas; se incluyeron además los 17 casos nativos del overlay.

La cobertura combinada fue **13 004 / 15 562 líneas (83,5625 %)**, sin archivos
de aplicación sin medir. El requisito global del 100 % siguió fallando.
Este resultado sustituye al porcentaje anterior para `6cc52f7`; tampoco
certifica modificaciones posteriores.

## Transporte, almacenamiento en frío y League conectado a la interfaz

Una tanda posterior aprobó 29 pruebas focalizadas y seis casos sobre el motor
Windows. Comprueba respuestas HTTP 401/403/409, escrituras JSON y respuestas
vacías, límites de tamaño, cuerpos detenidos después de los encabezados y
recuperación tras fallos. El servidor HTTP es local y usa un puerto efímero.

Las acciones de almacenamiento arrancan la fábrica de SQLite de producción
en una carpeta temporal comprobada antes de escribir: historial vacío,
exportación, retención, borrado, preguntas de voz, observaciones de visión y
resolución de cuentas Scout sintéticas. Las referencias de los registros
derivados y la deduplicación de observaciones se comprueban en la exportación.

El recorrido conectado usa el controlador real de League, sus eventos y la
conexión de proveedores de la interfaz; únicamente el transporte de League
es sintético. Recorre selección, partida, interrupción, recuperación y
postpartida. Detectó que el gráfico del Coach no recibía los puntos que ya
tenía el controlador: la conexión ahora incorpora esa serie sin modificar el
snapshot original. Se comprueban los puntos recibidos por el widget del gráfico.

Las recomendaciones comprueban la variante elegida para importar, bloqueo de
botones mientras se importa y ausencia de recomendaciones. Los títulos de
grupos de objetos ahora se ajustan al ancho: antes se desbordaban con texto
al 200 %. Los logs están en `build/testing/connected-boundaries-fixed.log` y
`build/testing/connected-windows.log`. Estos cambios requieren otra pasada
combinada; el porcentaje anterior sigue correspondiendo a `6cc52f7`.
