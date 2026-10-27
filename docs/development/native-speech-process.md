# Cancelación de síntesis: proceso auxiliar nativo

Estado: **integración Windows implementada; pruebas de voz y cierre aprobadas**.
Windows usa un proceso auxiliar con Sherpa 1.13.6 y un isolate para procesar
el protocolo/PCM. Las demás plataformas conservan el backend Dart/FFI.
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

La recuperación del prototipo comprueba metadatos y un número de muestras superior a un
cuarto de segundo. Ese prototipo no transporta el PCM de vuelta a Dart
ni comprueba su contenido o su reproducción. Tampoco cubre los otros seis
motores. Sus límites no se confunden con las pruebas de la integración descrita
en la sección siguiente, que sí transporta y comprueba PCM de los ocho motores.

## Integración requerida

La implementación Windows está en `windows/speech_worker/` y en los adaptadores
`speech_process_host.dart`, `speech_process_worker.dart` y
`speech_worker_protocol.dart`. CMake compila/instala el ejecutable y su licencia
junto con la aplicación. El empaquetador local exige ambos archivos.

El proceso principal posee el objeto `Process`. El isolate intermediario pide
iniciar el auxiliar y recibe sus bytes por puertos; la desaparición inesperada
del isolate hace que el guard termine el auxiliar desde su dueño. La primera
prueba mostró que matar un isolate no cierra de forma fiable sus tuberías: el
helper podía quedarse esperando. No se confía en ese comportamiento para cerrar
procesos. El helper conserva además vigilancia del padre y del cierre de entrada.

El protocolo GST1 usa longitudes little endian, UTF-8 válido sin NUL, límites de
campos/mensajes/audio y códigos explícitos de resultado. El proxy lee el PCM por
fragmentos y devuelve `TransferableTypedData`; no se usan archivos temporales
para IPC ni callbacks Dart desde el helper. Cada configuración incluye los
archivos del modelo, hilos, silencios y parámetros de generación/referencia.
La cancelación termina el proceso, espera su salida y descarta las muestras.
Un timeout retira también la sesión para exigir una inicialización nueva.

Los 22 regresores de protocolo y ciclo de vida aprobaron en
`build/testing/speech-process-lifecycle-host-final2.log`, incluidos mensajes
truncados/UTF-8/longitudes, pérdida del isolate y reinicialización tras timeout.
La primera tanda de los ocho motores pasó con cancelaciones de 18–37 ms
(`speech-process-all-voices.log`). Esa tanda precede al cambio de dueño del
proceso; su repetición y las comprobaciones amplias finales se registrarán por
separado. Los resultados previos no certifican automáticamente el último árbol.

La repetición con el dueño del proceso en el isolate principal aprobó los ocho
motores: cancelación de Supertonic 36 ms, Piper México/España 26/26 ms, Kitten
28 ms, Kokoro 31 ms, Matcha 35 ms, Pocket 40 ms y ZipVoice 25 ms. En cada caso
se comprobó generación y recuperación con PCM finito y no silencioso. También
aprobaron cuatro casos de reconocimiento y seis del proceso auxiliar. Evidencia:
`build/testing/speech-process-voices-host-final.log`. El límite de cinco segundos
no cambió. La base aprobó 688 pruebas con 30 omisiones explícitas en
`speech-process-base-final.log`; seis omisiones se ejecutan con el auxiliar real
en la etapa de motores instalados. Los regresores PowerShell y Python aprobaron
(`speech-process-runner-regressions.log`, `speech-process-python-regressions.log`).
La validación global y la cobertura combinada actuales aún deben completarse.

Lista de aceptación original, conservada como referencia:

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
