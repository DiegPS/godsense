# Resultado de la pasada completa del 25 de octubre de 2026

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
