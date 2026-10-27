# Certificación: informe del 27 de octubre de 2026

El informe aportado por el usuario identifica GodSense, producto `9N6CB23D5LBK`,
editor público DiegPS, con estado **Attention needed**. La observación cita
**10.1.5 Software Distribution** y nombra **Kilo Code y OpenCode** como software
cuya adquisición fuera de Store se promueve. Este documento registra ese informe;
no equivale a una consulta nueva del estado de Partner Center.

Los componentes se usan como motores auxiliares opcionales del chat. GodSense
ofrece descargarlos e iniciarlos, los ejecuta en loopback y mantiene separados
sus datos privados y sus binarios. La investigación del arranque en frío también
confirmó que OpenCode prepara dependencias npm internas al inicializar su
configuración. La identidad y las atribuciones de los componentes deben seguir
siendo visibles; cambiarles el nombre no resuelve la observación de distribución.

Que AirDown use componentes descargables y haya sido aprobado no demuestra que
la distribución concreta de GodSense esté aceptada. Falta aclarar la objeción o
adoptar una distribución que Microsoft acepte. Las pruebas locales y un cambio
de interfaz tampoco prueban por sí solos ese cumplimiento.

## Borrador de consulta para Microsoft — no enviado

> Product ID: 9N6CB23D5LBK — GodSense
>
> The certification report dated October 27, 2026 cites policy 10.1.5 and names
> Kilo Code and OpenCode. These are optional supporting runtimes used by
> GodSense's AI chat, rather than separate products promoted to the user. The
> submitted interface includes controls to download, install and start them.
>
> Could you identify the specific screen or action in the submitted package
> that must change, and clarify the accepted distribution approach for these
> supporting runtimes?
>
> Would including the required runtime files and their dependencies in the
> submitted MSIX, and removing external installation controls, address the
> reported issue while preserving the required third-party notices? OpenCode
> can also initialize internal JavaScript dependencies on first use; please
> clarify whether these must be included in the submitted package as well.
>
> We would appreciate guidance before preparing a replacement package so that
> the next submission addresses the actual distribution concern.

El borrador contiene únicamente el identificador público del producto, los
nombres públicos de los componentes y una descripción técnica. No incluye
dirección, correo privado, identificadores de Windows, credenciales ni datos
de partidas. No se ha enviado esta consulta ni se ha cancelado o reemplazado
ningún envío como parte de esta revisión.

## Condiciones antes de reemplazar el binario

- Resolver los fallos funcionales pendientes y conservar evidencia del commit
  concreto y del paquete generado; el resultado global actual sigue en fallo.
- Aclarar la objeción de distribución o verificar una solución aceptada para
  ella. Conservar las atribuciones de los componentes.
- Generar y verificar el MSIX actualizado, con su procedencia y versión.
- Reemplazar el paquete del envío existente sin cancelar ese envío, siguiendo
  la instrucción del usuario, cuando el candidato esté preparado.
