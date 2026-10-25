# Imágenes de Store — datos de demostración

Seis PNG de 1600×1000 generados con los widgets reales de Flutter:

1. Scout: Hide on bush#DEMO, rango y estadísticas ficticios.
2. Draft: selecciones de ejemplo y evaluación de composición.
3. Coach en partida: directivas, amenaza, evolución de oro y pregunta por voz.
4. Ajustes de voz y overlay.
5. Exportación, borrado y retención de datos locales.
6. Mapa: vista de configuración con un mapa estático público de Riot, sin
   posiciones ni mediciones de una partida real. No simula detecciones válidas.

Cada imagen indica que son datos de demostración. No son partidas ni estadísticas
reales de Faker. No se abren perfiles personales, conversaciones, micrófono,
captura de escritorio ni credenciales. Las preferencias están en memoria y el
almacenamiento de runtimes apunta a una carpeta temporal exclusiva del generador.

Las imágenes usan los componentes de producción, incluida la barra superior.
Se renderizan con Flutter en un entorno aislado; no son fotografías de una
partida real ni imágenes de una interfaz inventada con un generador de imágenes.
El código solo sirve ilustraciones públicas descargadas de Data Dragon desde
el caché de esta herramienta. No establece conexiones con Riot Client ni con
proveedores de inferencia. No modifica los ajustes de la aplicación instalada.

Para regenerarlas:

```powershell
.\tool\generate_store_screenshots.ps1
```

`manifest.json` registra tamaños, hashes, procedencia del arte público de Riot y
hash del renderer. El arte corresponde a Data Dragon 16.21.1; no se presenta el
perfil sintético como una recomendación oficial de Riot ni una medición en vivo.
El aviso de demostración es una franja del renderer, ajena al producto normal.

`listing-es-MX.json` contiene la descripción, características y leyendas de cada
imagen. Las seis imágenes y sus leyendas se cargaron en el borrador de Partner
Center; la ficha en español de México quedó marcada como completada. No se ha
enviado el producto a certificación ni publicado en Store.
