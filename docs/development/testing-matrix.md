# Matriz de verificación de GodSense

Los comandos están en [verificación local de Windows](local-windows-verification.md).
Los resultados de una pasada concreta están en `build/testing/runs/<fecha-hora>`:
`summary.json`, logs de cada etapa y `coverage.json` con las líneas pendientes.
Esta matriz describe el alcance de las pruebas, no certifica que todas hayan
pasado ni sustituye el resultado de esa ejecución.

| Área | Comprobación automatizada | Límite de la comprobación |
| --- | --- | --- |
| Arranque y navegación | Guía inicial, seis pestañas, formularios conservados, tamaños de 900 × 600 a 1920 × 1080 y texto hasta 200 %; arranque release | El perfil usa la configuración local y el hardware de esta sesión |
| Ventana y overlay | Arranque de producción, crear, mostrar, ocultar, reutilizar y destruir ventanas; comprobar número de vistas nativas | Falta aceptación sobre una partida real en pantalla completa |
| Fluidez | Modo profile, navegación fría/caliente, captura simultánea y refresco de catálogo; presupuestos de tiempo explícitos | La captura de estrés usa regiones de 300 × 300, no sustituye toda la visión de una partida |
| League | Selección, partida, interrupción, recuperación, postpartida y reconexión; eventos simultáneos; importación preservando páginas y builds personales | Transportes simulados y SQLite real aislado; League no está instalado en este equipo |
| Scout | Búsqueda desde campos reales, fallos y reintentos, hidratación en isolate, actualización, paginación y detalles de partidas | Los perfiles y respuestas son sintéticos |
| IA | Catálogos de OpenCode/Kilo instalados; SSE; conversación real gratuita con preguntas repetidas, cancelación y reinicio; historial persistente | La disponibilidad y latencia del proveedor gratuito son externas; no se eligen modelos de pago como alternativa |
| Conexión de proveedores | Diálogos, clave oculta, cancelar, entrada vacía, OAuth con código y desconectar, también sobre motor Windows | Controlador de autenticación simulado; nunca se conectan cuentas reales ni se usan claves personales |
| Reconocimiento de voz | Worker real con audio público, VAD, Canary, reducción de ruido activada/desactivada, vaciado final y cierre de recursos | PCM inyectado; no comprueba el micrófono físico ni permisos del dispositivo |
| Síntesis de voz | Supertonic, Piper México/España, Kitten, Kokoro, Matcha, Pocket y ZipVoice: síntesis real, cancelación y recuperación, procesos aislados | Generación de muestras; no comprueba altavoces físicos |
| Modelos | Descarga con tamaño/SHA-256, instalación, archivos requeridos, caché modificada, cancelación, migración e inicio diferido | Las voces opcionales se preparan explícitamente antes de la pasada completa |
| Visión | Cuatro suites nativas aisladas, corpus, selección de plantillas, calibración, pantallas múltiples y captura Windows | Las capturas de corpus y los fixtures no equivalen a observar una partida completa |
| Datos locales | SQLite real aislado, retención repetida, referencias de partidas activas, exportación paginada, fallos, borrado confirmado y estrés de exportación con registros/documentos grandes | La prueba del destino de exportación inyecta el diálogo; no recorre el selector de archivos de Windows |
| Transporte de descargas | Descarga HTTPS real en Windows, SHA-256 del resultado y rechazo de tamaño incorrecto | Registros del plugin en memoria aislada; no modifica la base real de descargas del usuario |
| Diagnóstico | Redacción de secretos, escritura asíncrona, fallos de almacenamiento, cola limitada, exportación y limpieza | Se conservan los errores de cada etapa; ningún aviso se silencia para convertir una prueba en éxito |
| Distribución | Compilación release, arranque y manifiestos/checksums del paquete | La aceptación del paquete firmado, certificación y publicación se verifican aparte |

## Cobertura y resultados pendientes

El objetivo solicitado del 100 % permanece como puerta estricta en
`tool/test_all.ps1`. Un porcentaje inferior o archivos ejecutables sin medir
mantienen el resultado global en fallo. No se han añadido directivas de
exclusión para alcanzar una cifra.

El informe incluye las declaraciones Dart de tablas Drift. La biblioteca Drift
documenta en `ColumnBuilder` que su DSL se analiza durante generación y que sus
métodos no se ejecutan en runtime. Las restricciones reales de SQLite y sus
migraciones se comprueban sobre la base generada. No se añaden invocaciones
artificiales que solo esperen `UnsupportedError` para pintar esos getters de
verde. También deben distinguirse interfaces sin implementación y archivos que
únicamente reexportan una API de los archivos ejecutables pendientes de pruebas.

Los resultados históricos de un candidato de Store se conservan en su propio
informe. Haber probado el código de trabajo no convierte automáticamente un
MSIX anterior en el binario actualizado ni significa que se haya publicado.
