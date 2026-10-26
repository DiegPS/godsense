# Registro de pruebas del 25 y 26 de octubre de 2026

La última pasada completa registrada es `d96d91a`, en
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
y 58 de texto; el razonamiento no se mostró como respuesta. Es una corrección
posterior, todavía pendiente de otra pasada global.

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
