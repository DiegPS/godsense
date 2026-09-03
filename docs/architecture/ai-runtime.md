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
2. **Bloqueo comprobado de herramientas:** Se fuerzan las variables de entorno
   `KILO_DISABLE_TOOLS=1`, `KILO_DISABLE_EXTERNAL_SKILLS=1` y `OPENCODE_DISABLE_TOOLS=1`,
   y se envían los prompts con `tools: {}` y `toolChoice: none` para impedir la ejecución
   de comandos o acceso a archivos desde el modelo.
3. **Conversación y streaming:** Integrado con Riverpod (`aiConversationProvider`),
   recibiendo deltas de texto progresivos vía SSE con capacidad de cancelación inmediata
   (`abort`) y control desde la interfaz de Coach (`AiCoachChatCard`) y Ajustes (`CoachingSettingsSection`).
