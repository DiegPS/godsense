# Verificación local de Windows

GodSense valida el código y genera la aplicación sin depender de GitHub Actions
ni de otro ejecutor remoto. Desde la raíz del repositorio ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\verify_windows.ps1
```

El flujo resuelve dependencias, ejecuta el analizador, corre pruebas unitarias y
de widgets con un piso local de cobertura del 65 %, ejecuta cada archivo de
integración en un proceso separado y finalmente genera la build release de
Windows.

Las pruebas nativas de DartCV se ejecutan, archivo por archivo, en procesos
aislados del resto de la suite. Esto reproduce mejor el proceso único de la
aplicación, evita que sus recursos nativos se solapen entre archivos y conserva
toda la validación de visión. El runner de Flutter todavía puede imprimir el
aviso genérico de callbacks nativos por otros bindings; el aviso no se toma como
evidencia de un fallo de DartCV si la suite aislada finaliza correctamente.

Los archivos de integración se ejecutan por separado porque el runner de
Flutter para Windows no reinicia de manera fiable varias aplicaciones desktop
dentro de una sola invocación. Esta estrategia mantiene la suite completa y
repetible. Las pruebas que requieren servicios o modelos reales conservan sus
variables de entorno y se reportan como omitidas cuando no están configuradas.

Para ciclos de desarrollo más rápidos se pueden omitir etapas costosas:

```powershell
.\tool\verify_windows.ps1 -SkipIntegration -SkipBuild
```

El piso de cobertura también puede ajustarse explícitamente, por ejemplo:

```powershell
.\tool\verify_windows.ps1 -MinimumCoverage 70
```
