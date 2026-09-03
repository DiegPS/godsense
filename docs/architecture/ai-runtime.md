# Runtime local de IA

La IA de GodSense es opcional. El producto base continúa funcionando de forma
nativa; cuando el usuario habilita coaching con modelos, GodSense inicia un
único runtime privado: OpenCode o Kilo.

## Límites

- GodSense integra runtimes, no implementa providers de inferencia.
- En producción no se reutiliza la instalación personal del usuario.
- Las instalaciones personales sólo son fixtures de integración durante el
  desarrollo.
- Los procesos escuchan exclusivamente en `127.0.0.1`, solicitan puerto `0` y
  anuncian el puerto realmente asignado.
- Cada ejecución recibe una contraseña aleatoria que sólo vive en memoria.
- Una respuesta de health válida es obligatoria antes del estado `ready`.
- En Windows el proceso se asigna a un Job Object con cierre en cascada.
- Sólo un runtime puede permanecer activo.

## Versiones fijadas

| Runtime | Versión de producción | Asset |
| --- | --- | --- |
| OpenCode | 1.18.27 | `opencode-windows-x64.zip` |
| Kilo | 7.5.9 | `kilo-windows-x64.zip` |

Tamaño y SHA-256 están congelados en `PinnedAiRuntimeCatalog`. GodSense no usa
`latest` para instalar ni permite el auto-update interno del runtime.

## API implementada

`OpenCodeCompatibleRuntimeClient` implementa el subconjunto común:

```text
GET    /provider
GET    /provider/auth
POST   /session
GET    /session/:id
GET    /session/:id/message
POST   /session/:id/prompt_async
POST   /session/:id/abort
DELETE /session/:id
GET    /event
```

Todas las llamadas usan Basic Auth y el directorio aislado de GodSense. El
stream SSE se transforma en `AiRuntimeEvent`; ninguna capa de Coach depende del
JSON particular del runtime.

## Validación local

### Regresión de streaming y presentación (2026-09-02)

`integration_test/kilo_streaming_test.dart` deshabilita la consulta de mensajes
después de capturar el historial inicial. Así el sondeo no puede ocultar un fallo
de SSE. Antes de la corrección, Kilo emitió 353 deltas y el controlador publicó
0 respuestas parciales: `session.updated.info.id` se interpretaba como ID de
mensaje y bloqueaba los mensajes reales. Tras corregir el filtro por tipo de
evento, una ejecución con Kilo 7.5.9 produjo 431 deltas y 431 textos parciales,
terminando sin error. Es evidencia de esa ejecución, no una garantía de latencia.

`test/presentation/coach/coach_streaming_widget_test.dart` conecta el controlador
real a la tarjeta de Coach con transporte simulado. Comprueba que el Markdown
está renderizado (incluida negrita) y se actualiza antes de finalizar la respuesta.
Las burbujas parciales y finales comparten `CoachMessageBody`, basado en
`flutter_markdown_plus`, sin cargar imágenes externas o archivos del modelo.

### Ejecución

La prueba de integración recibe rutas mediante:

```text
GODSENSE_TEST_OPENCODE_EXE
GODSENSE_TEST_KILO_EXE
```

Arranca cada binario, valida health, providers, métodos de autenticación, SSE y
el ciclo de vida de la sesión. Adicionalmente, cuenta con una prueba de humo con
`kilo/kilo-auto/free` (`GODSENSE_TEST_KILO_AUTO_FREE=true`) que envía un prompt
real y valida la respuesta sin consumir saldo de pago.

## Seguridad y aislamiento de proceso

1. **Saneamiento del entorno:** Se ejecuta con `includeParentEnvironment: false`. Solo
   se preserva una lista blanca explícita de variables de sistema indispensables de
   Windows (`SYSTEMROOT`, `COMSPEC`, `PATH`, etc.), filtrando y excluyendo activamente
   cualquier clave o token de API (`OPENAI_*`, `ANTHROPIC_*`, `GEMINI_*`, `GITHUB_*`, etc.).
2. **Bloqueo comprobado de herramientas:** En Kilo / OpenCode `prompt.ts`, el mapa
   `tools` define reglas de permisos por patrón. Se envía estrictamente `tools: {'*': false}`
   para denegar formalmente cualquier ejecución de herramientas, complementado con las
   directivas de inicio `--pure` y variables `KILO_DISABLE_EXTERNAL_SKILLS=1`.
3. **Conversación y streaming robusto:** Integrado con Riverpod (`aiConversationProvider`):
   - Handshake físico de SSE verificado vía `connectEvents()` (esperando HTTP 200) antes de despachar `promptAsync()`.
   - Distinción estricta entre deltas incrementales (`message.part.delta`) y texto consolidado (`message.part.updated`) evitando duplicación de texto.
   - Correlación estricta de respuestas en sondeo vinculadas al mensaje de usuario del prompt actual, evitando que preguntas consecutivas capturen respuestas anteriores.
   - Control de generaciones (`_currentGenerationId`): descarte absoluto de eventos en búfer o rezagados tras un `abort()`.
   - Renovación automática del cliente HTTP y purga de sesión obsoleta si el endpoint del runtime cambia tras un reinicio.

## Descargas desde Ajustes (2026-09-02)

- Ajustes → Coaching permite descargar e instalar Kilo 7.5.9 y OpenCode
  1.18.27, comprobar su instalación al abrir la pantalla, mostrar progreso por
  fase y cancelar/reintentar. Iniciar y detener son acciones separadas.
- El provider de producción habilita `allowDownloads: true` y no recibe las
  variables `GODSENSE_TEST_*_EXE`. Las pruebas aún pueden inyectar binarios, pero
  el instalador da prioridad a una instalación privada válida.
- El arranque reutiliza la versión fijada instalada por ArtifactInstaller.
  Solo hay un proceso activo; instalar otro detiene el anterior. La UI bloquea
  cambios mientras se genera una respuesta y el chat no descarga silenciosamente.
- Los tamaños y SHA-256 del catálogo se cotejaron con los metadatos de los assets
  oficiales de GitHub. No se descargaron ZIP reales en este bloque. Las pruebas
  de interacción usan un supervisor simulado; las del ciclo de vida usan
  instalador/procesos simulados. No equivalen a validación integral de los binarios.
- Prueba manual: reiniciar GodSense, descargar un motor desde Ajustes → Coaching,
  esperar «Instalado», pulsar «Iniciar» y comprobar «Listo» y su versión; repetir
  con el otro motor. Kilo permite después probar el chat. OpenCode tiene descarga
  y arranque, pero su selección de modelos para el chat continúa pendiente.
