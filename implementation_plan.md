# Implementation Plan: Coach modular y determinista

## Objetivo

Reemplazar el panel plano de Coach por una experiencia automática por fases
(`champSelect`, `inGame`, `postGame`, `inactive`) alimentada exclusivamente por
LCU, Live Client, visión, journal y motores locales. No se incorporarán IA,
`opencode`, `generateLobbyBrief` ni dependencias de un backend heredado.

## Restricciones congeladas

- Los modelos de dominio no contienen URLs de CDN ni estados de otros
  controladores.
- `PatchKey` nunca se utiliza como versión de Data Dragon. Todo recurso utiliza
  el `resolvedVersion` de un `DataDragonArtifact` validado.
- La procedencia (`source`, versión, locale y hash) acompaña a los metadatos.
- CommunityDragon es un fallback identificado, nunca la fuente canónica.
- Las recomendaciones permanecen puras; la capa de aplicación crea las
  proyecciones visuales enriquecidas.
- Las puntuaciones de composición se presentan como resultados derivados y
  versionados, no como hechos observados.
- Coach será una biblioteca Dart importable. No se añadirán nuevos archivos
  `part` al monolito de `godsense_app.dart`.
- La interfaz responde a las restricciones de la ventana mediante
  `LayoutBuilder`, conserva navegación por teclado y no comunica estado solo
  mediante color.

## Bloque 1: contratos y catálogos

1. Extender `DataDragonResource`, `DataDragonResolver` y
   `DataDragonCatalogService` para soportar runas y hechizos.
2. Añadir validadores y parsers específicos: `runesReforged.json` es una lista;
   `item.json` y `summoner.json` contienen un mapa `data`.
3. Mantener la resolución offline-first existente: caché exacta válida,
   Data Dragon por manifest, recursos compatibles instalados si existen y
   CommunityDragon como fallback explícito; persistir todo artefacto validado.
4. Crear metadatos tipados (`RuneMetadata`, `SummonerSpellMetadata`,
   `ItemMetadata`, `AssetProvenance`) y el puerto `GameAssetCatalog`.
5. Crear modelos tipados de draft (`DraftSnapshot`, `DraftPlayer`,
   `DraftSelectionState`, `DraftBan`, `DraftSide`) y adaptar el snapshot LCU.
6. Tipar la salida del `ChampionCompositionAnalyzer`, conservar la escala 0–3
   y registrar `evaluatorVersion`.
7. Cubrir formatos, locale fallback, diferencias patch/version, caché y datos
   incompletos con fixtures unitarios sin red.

## Bloque 2: coordinación y proyecciones

1. Crear `CoachPhaseResolver` con precedencia:
   - Live Client activo y partida no terminada: `inGame`.
   - Champ Select LCU normalizado: `champSelect`.
   - sesión recién terminada con resumen disponible: `postGame`.
   - cualquier otro estado: `inactive`.
2. Crear `CoachState` y `CoachController` con dependencias inyectadas.
3. Proyectar recomendaciones como `RuneRecommendationViewData` y
   `RecommendedItemViewData`, sin modificar sus modelos de origen.
4. Proyectar visión, oro, directivas y voz a tipos propios de Coach; nunca
   exponer `NativeVisionState` ni otro estado de controlador.
5. Leer el historial de voz del journal con límite explícito. Si no existe un
   resumen post-game persistido, la fase muestra preparación/conexión y no
   inventa conclusiones.
6. Añadir feedback tipado para importaciones LCU exitosas y fallidas.

## Bloque 3: presentación modular

```text
lib/presentation/coach/
├── coach_page.dart
├── matchup/matchup_hero_card.dart
├── draft/draft_matrix_card.dart
├── draft/composition_breakdown_card.dart
├── draft/pick_advice_card.dart
├── setup/rune_tree_view.dart
├── setup/item_bundles_view.dart
├── setup/riot_jungle_route_view.dart
├── live/live_directives_card.dart
├── live/threat_and_sightings_card.dart
├── live/gold_timeline_card.dart
├── live/voice_coach_card.dart
├── post_game/post_game_summary.dart
└── shared/
```

- Hero contextual: identidades, roles y setup disponible. Una condición de
  victoria solo aparece cuando procede de un evaluador local comprobado.
- Champ Select: draft 5v5, bans, estado explícito LOCKED/HOVER/PICKING,
  composición derivada, runas, objetos y ruta recomendada por Riot.
- In Game: directivas locales, amenazas y avistamientos nativos, serie de oro
  y consultas de voz locales.
- Post Game: solo datos persistidos de la sesión terminada.
- Navegación secundaria permite consultar otras fases sin alterar la fase
  automática.

## Bloque 4: verificación

- Tests unitarios de catálogos, draft, composición, fases, proyecciones e
  importación.
- Widget tests de las cuatro fases, degradación offline, transición en vivo,
  feedback, teclado y anchos de 800 y 1280 px.
- Test de frontera que impida dependencias nuevas de `opencode` y del flujo
  heredado en Coach.
- `dart format lib test`, `flutter analyze` sin issues y `flutter test` sin
  fallos ni skips inesperados.
- Cada bloque funcional se valida y se commitea antes de continuar.

