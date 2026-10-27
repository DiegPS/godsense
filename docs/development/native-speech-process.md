# Cancelación de síntesis: proceso auxiliar nativo

Estado: **prototipo ejecutado, todavía sin integrar en la aplicación**.
El motor de producción continúa usando un isolate Dart con Sherpa 1.13.6.
La pasada completa `20261027-124009` falló en cancelación: Kokoro tardó
5,109 segundos y ZipVoice 5,337 segundos, frente al límite de 5 segundos.
Los pases aislados posteriores no anulan esos fallos ni prueban consistencia.

## Restricción comprobada

En el código de Sherpa correspondiente a la versión instalada, Kokoro invoca
su callback después de `Process(batch_x, ...)`; ZipVoice lo invoca después de
`GenerateChunk(...)`. El indicador de GodSense no puede interrumpir esas
operaciones antes del siguiente callback. Reducir de ocho a cuatro hilos no
mejoró el resultado; ese experimento se revirtió.

Terminar un isolate Dart mientras C++ conserva un `NativeCallable` puede dejar
un puntero a un callback destruido. La espera actual conserva esa memoria hasta
que termina la llamada. Se debe mantener esa protección mientras exista el
backend actual; no se ha eliminado para conseguir que pase una prueba.

Fuentes de la versión instalada:

- [Kokoro 1.13.6](https://github.com/k2-fsa/sherpa-onnx/blob/v1.13.6/sherpa-onnx/csrc/offline-tts-kokoro-impl.h).
- [ZipVoice 1.13.6](https://github.com/k2-fsa/sherpa-onnx/blob/v1.13.6/sherpa-onnx/csrc/offline-tts-zipvoice-impl.h).
- [API C 1.13.6](https://github.com/k2-fsa/sherpa-onnx/blob/v1.13.6/sherpa-onnx/c-api/c-api.h).

## Experimento ejecutado

El prototipo local `build/testing/native-tts-prototype/` contiene un ejecutable
C++ sin ventana, construido con Visual Studio/CMake y la cabecera oficial de
la API C 1.13.6. Carga las DLL instaladas de Sherpa y ONNX Runtime y los modelos
ya preparados para las pruebas. No añade paquetes Dart ni modifica modelos,
preferencias o calibraciones. No se distribuye con GodSense en este estado.

El proceso carga Kokoro o ZipVoice, anuncia el inicio de generación y llama a
la API C con un texto de 80 frases, sin callbacks ni punteros pertenecientes a
Dart. Después de 100 ms el driver termina el proceso, espera su salida real y
crea otro proceso que genera una frase corta y libera sus recursos normalmente.
Se repitió tres veces por motor; el límite comprobado sigue siendo de 5 segundos.

| Motor | Terminación en cada repetición | Recuperación posterior |
| --- | --- | --- |
| Kokoro | 30, 13 y 14 ms | Las tres generaciones devolvieron audio a 24 kHz |
| ZipVoice | 30, 19 y 23 ms | Las tres generaciones devolvieron audio a 24 kHz |

Evidencia: `build/testing/native-tts-process-probe.log`, compilación en
`build/testing/native-tts-prototype-build.log`. El driver terminó con código
cero y se comprobó que no quedaban procesos `speech_process_probe.exe`.
El helper vigila al proceso padre para terminar si este desaparece.

La recuperación comprueba metadatos y un número de muestras superior a un
cuarto de segundo. El prototipo todavía no transporta el PCM de vuelta a Dart
ni comprueba su contenido o su reproducción. Tampoco cubre los otros seis
motores. Estos límites impiden tratarlo como una corrección de producción.

## Integración requerida

1. Construir y empaquetar un helper de GodSense con las DLL existentes. Mantener
   la cabecera/licencia y la procedencia de Sherpa, sin descargas implícitas
   nuevas. Validar el binario incluido tanto en debug como en release/MSIX.
2. Transportar configuración completa de los ocho modelos y PCM float32 con
   un protocolo binario acotado, validando tamaños, versión, UTF-8, errores,
   cierre de tuberías y resultados incompletos. Conservar voces, referencias,
   idiomas, velocidad y pasos; no resolver la cancelación reduciendo calidad.
3. Mantener el trabajo de IPC y ensamblado de audio fuera del hilo de interfaz,
   reutilizando el contrato del worker y las comprobaciones de generación del
   servicio. La cancelación debe terminar el helper real y rechazar o descartar
   su resultado obsoleto sin reproducirlo.
4. Garantizar la terminación del helper al cancelar, liberar el modelo,
   cerrar la app, morir el padre o cerrarse la tubería, también durante la carga
   del modelo. La pérdida del isolate intermediario no debe dejar un helper vivo.
5. Ejecutar los regresores de ciclo de vida y las pruebas nativas existentes de
   los ocho motores, sin debilitar el límite de cancelación. Añadir comprobación
   del PCM transportado y de ausencia de procesos huérfanos. Después verificar
   interfaz, profile, compilación/arranque y la pasada global con código fijo.

La aceptación sobre micrófono y altavoces físicos y una partida real permanece
separada de estas comprobaciones sintéticas. No se ha generado ni enviado un
paquete de Store a partir de este prototipo.
