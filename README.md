# GodSense

Asistente de League of Legends para Windows. Conecta automáticamente con el
cliente de Riot y combina datos de partida, reconocimiento del minimapa,
recomendaciones, historial local y preguntas por voz.

## Usar la aplicación

1. Abre GodSense y League of Legends. La conexión con el cliente es automática.
2. En **Mapa**, calibra el minimapa con la partida visible. Si cambias de pantalla,
   resolución o tamaño del minimapa, revisa la calibración.
3. En **Ajustes**, instala los modelos de voz que quieras usar y configura el
   atajo para hablar. La transcripción y la síntesis se ejecutan localmente.
   **Probar micrófono** graba hasta tres segundos, los reproduce y borra el audio
   temporal. Funciona sin descargar modelos. **Detener voz**, también disponible
   en la barra superior mientras habla, corta la respuesta sin desactivar la voz.
4. **Coach** muestra preparación y asistencia según el estado de la partida.
   El chat con IA es opcional y requiere configurar su proveedor/modelo.
5. El overlay aparece durante la partida. **Editar HUD** permite colocar sus
   paneles; salir de la edición guarda la distribución.
   Su interruptor se conserva al reiniciar y restablecer los paneles pide
   confirmación. **Consejo ahora**, en Coach durante la partida, ofrece una
   recomendación local sin usar el micrófono.

En Ajustes puedes exportar o borrar tus datos locales y aplicar la retención.
Los modelos descargados y la calibración se conservan al borrar el historial.

## Desarrollo en Windows

Se necesitan Flutter con Dart 3.13 o superior y las herramientas de compilación
de escritorio de Visual Studio con C++. No se necesita Python ni Node para
ejecutar la aplicación.

```powershell
flutter pub get
flutter run -d windows
```

Verificación local completa (análisis, tests, cobertura, integraciones y build):

```powershell
.\tool\verify_windows.ps1 -ProfileUI
```

La prueba de fluidez también puede ejecutarse por separado. Abre la aplicación,
recorre las pestañas y verifica la respuesta mientras captura la pantalla:

```powershell
.\tool\profile_windows.ps1
```

Para verificar y preparar un ZIP candidato con las DLL de Visual C++ y un
manifiesto de archivos:

```powershell
.\tool\package_windows.ps1
```

El ZIP queda en `build/distribution/`. La identidad de Microsoft Store ya está
configurada para `DiegPS.GodSense` (Store ID `9N6CB23D5LBK`). Para generar un
MSIX local con esa identidad:

```powershell
.\tool\package_store_windows.ps1
```

El MSIX queda en `build/store/`. La validación de instalación y la publicación
se realizan por separado. Consulta la [guía de Store](docs/distribution/microsoft-store.md).

Los informes quedan en `build/performance/`. La build normal está en
`build/windows/x64/runner/Release/`; para distribuirla hay que incluir la carpeta
completa, sus DLL y `data`, no únicamente el ejecutable.

Las integraciones con servicios reales que necesitan configuración adicional
se identifican como omitidas si esa configuración no está disponible. Un test
omitido no equivale a una función validada con el servicio real.

## Documentación

- [Verificación local](docs/development/local-windows-verification.md)
- [Diagnóstico de fluidez](docs/development/windows-responsiveness.md)
- [Estado de funcionalidades](docs/architecture/implementation-status.md)
- [Runtime de IA opcional](docs/architecture/ai-runtime.md)
- [Diseño de interfaz](docs/design-system.md)

GodSense es un proyecto independiente; no es un producto oficial de Riot Games.
