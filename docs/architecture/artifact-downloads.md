# Descargas e instalación de artefactos

GodSense usa una sola frontera de descarga para modelos de voz y futuros
runtimes de coaching. La transferencia HTTP pertenece a
`background_downloader`; la aplicación conserva únicamente las reglas de
producto que una biblioteca genérica no puede conocer.

## Responsabilidades

- `ArtifactDownloader` define transferencia, progreso y cancelación sin acoplar
  aplicación y dominio a una biblioteca concreta.
- `BackgroundArtifactDownloader` exige HTTPS, aplica reintentos, permite
  pausa/reanudación y activa el seguimiento persistente de tareas.
- `ArtifactInstaller` valida tamaño y SHA-256, extrae en staging, comprueba la
  estructura requerida, instala versiones independientes y publica
  `active.json` mediante una sustitución recuperable.
- Los catálogos de cada producto son la única fuente de URL, versión, tamaño,
  digest, estructura esperada y archivos obsoletos que deben retirarse.

## Organización en disco

```text
<application-support>/artifacts/
  .downloads/<group>/<artifact>/<version>/
  <group>/<artifact>/
    active.json
    versions/<version>/
      .godsense-artifact.json
      ...
```

`active.json` mantiene la versión activa y la anterior. Una versión nueva se
valida por completo antes de sustituir ese puntero. Si la publicación se
interrumpe, `active.json.previous` permite recuperar el estado anterior en la
siguiente activación.

## Reglas congeladas

- Solo HTTPS y manifiestos con tamaño y SHA-256 conocidos.
- Ningún archivo se ejecuta o expone antes de validar su instalación completa.
- Las rutas absolutas y cualquier salida del directorio de instalación se
  rechazan.
- Los archivos comprimidos deben declarar un formato compatible con su
  extensión.
- Una descarga verificada puede reutilizarse después de reiniciar la app.
- Voz conserva su layout compatible con los modelos ya migrados desde
  Airstream, pero usa la misma frontera de transferencia y los grupos
  `voice-stt` y `voice-tts`.

Los futuros proveedores de Coach solo deben aportar sus manifiestos y una
sonda de validación del runtime. No deben implementar clientes HTTP ni lógica
de extracción propios.
