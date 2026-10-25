# GodSense: búho cartógrafo

Identidad elegida: un búho visto de cerca con un mapa plegado en el cuello.
Relaciona observación, lectura del terreno y anticipación con el asistente de
partida. Azul oscuro, ocre y blanco; exterior transparente, sin placa de fondo.

`godsense-master.png` es el original raster transparente. La cara y el mapa
conservan el blanco opaco. No es un archivo vectorial ni una separación de tintas
para imprenta. Los conceptos y prompts están en `concepts/owl-cartographer/`.

Generado y editado con ImageGen integrado. El prompt de producción está en
`production-prompt.md`. Las exploraciones descartadas se conservan localmente
en `build/branding-drafts/`; no son recursos de la aplicación.

Para regenerar los recursos desde el master:

```powershell
.\tool\generate_branding_assets.ps1
```

Produce PNG de 64 y 256 píxeles y el ICO nativo con nueve tamaños entre 16 y
256 píxeles. La interfaz usa el PNG pequeño; el MSIX obtiene su arte del PNG
incluido en el candidato verificado, para conservar la identidad de esa build.
Después de regenerar hay que recompilar Windows y volver a empaquetar.
