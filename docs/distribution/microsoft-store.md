# Microsoft Store

La ficha está reservada y su identidad se conserva en
`windows/packaging/store-identity.json`. Son identificadores públicos del
producto, no contraseñas ni claves de firma.

| Campo de Partner Center | Valor |
| --- | --- |
| Package/Identity/Name | `DiegPS.GodSense` |
| Package/Identity/Publisher | `CN=6BE6AE18-C648-4E5F-8FDA-7901A0B883EF` |
| Package/Properties/PublisherDisplayName | `DiegPS` |
| Package Family Name | `DiegPS.GodSense_5r15ntm5fnab6` |
| Store ID | `9N6CB23D5LBK` |

El SID recibido también se conserva en el JSON como referencia. El PFN y el SID
no se escriben como atributos del manifiesto: Windows los deriva de la identidad.

## Generación local

Con Flutter, Visual Studio C++ y el SDK de Windows instalados:

```powershell
.\tool\package_store_windows.ps1
```

El comando ejecuta la verificación local existente, prepara un candidato con
las DLL de Visual C++ y crea el MSIX mediante MakeAppx, sin instalar paquetes
Dart adicionales ni depender de GitHub Actions.

Para empaquetar un candidato ya verificado, sin recompilarlo:

```powershell
.\tool\package_store_windows.ps1 `
    -CandidateDirectory 'build\distribution\verified-20261025-004508' `
    -PackageVersion 1.0.0.0
```

La versión tiene cuatro componentes; el último permanece en cero. Por defecto
se utiliza la versión de `pubspec.yaml` sin su sufijo de build, seguida de `.0`.
Incrementa explícitamente `-PackageVersion` para una nueva entrega si la versión
de producto no ha cambiado. No reemplaces una versión ya publicada por otro
binario con el mismo número.

Los resultados quedan en una carpeta nueva bajo `build/store/`:

- El MSIX x64 sin firma, su SHA256 y un JSON de procedencia.
- El contenido de preparación y una extracción verificada del paquete.

El script comprueba los hashes del candidato, rechaza archivos adicionales y
enlaces, valida el manifiesto con el SDK y vuelve a comprobar la identidad y los
hashes del payload después de extraer el MSIX. La procedencia distingue el commit
de la aplicación del commit de configuración de empaquetado.

El manifiesto declara aplicación clásica con `runFullTrust`, conectividad y
micrófono. GodSense necesita acceso a League, captura DXGI y procesos locales;
no se configura ejecución elevada. Los identificadores internos de almacenamiento
del ejecutable se conservan para no cambiar las rutas de datos del modo portable.

## Alcance de la validación

Crear, validar y extraer un MSIX no demuestra su instalación ni el comportamiento
con identidad de paquete. Sigue pendiente probar la aplicación instalada, en
partida real, y ejecutar Windows App Certification Kit antes de enviar la ficha.
El icono actual del runner todavía es el de Flutter; los assets del MSIX se
derivan de ese icono y deben sustituirse por la identidad gráfica definitiva.

No se generan certificados privados ni se modifica el almacén de confianza de
Windows. El candidato sin firma está destinado a preparación para Store, no a
instalación directa mediante doble clic. Store vuelve a firmar el paquete después
de su certificación. La ficha comercial, política de privacidad y capturas se
completan en Partner Center.

Referencias oficiales:

- [Crear los componentes de un MSIX](https://learn.microsoft.com/en-us/windows/msix/desktop/desktop-to-uwp-manual-conversion).
- [Requisitos, versiones y firma para Store](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/app-package-requirements).
