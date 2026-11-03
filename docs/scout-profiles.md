# Perfiles de Scout y sesión de League

Scout distingue dos responsabilidades: League controla la sesión de juego;
Scout decide qué historial consultar. Elegir un perfil no inicia sesión,
no cambia la cuenta del cliente de Riot y no guarda credenciales.

## Uso

- En Scout, el selector «Perfil que consultas en Scout» permite seguir la
  cuenta de League o elegir cualquiera de los perfiles guardados en este equipo.
- Ajustes → Perfiles de Scout ofrece el mismo selector y la misma preferencia;
  no hay dos configuraciones independientes.
- «Seguir la cuenta de League» cambia Scout al cambiar la cuenta de League.
  Si no hay cuenta disponible, muestra el estado vacío, no un error de autenticación.
- Elegir un perfil lo mantiene seleccionado aunque cambie o se cierre League.
  Se recuerda al reiniciar GodSense mediante PUUID y plataforma, nunca por nombre.
- Las cuentas detectadas y los Riot ID consultados ya se almacenan en `accounts`.
  El selector reutiliza ese repositorio; no crea otra base de cuentas.
- Abrir un perfil guardado lee el historial local sin sincronizar. «Actualizar
  historial local» intenta obtener datos nuevos; no se promete que el cliente de
  League pueda consultar otra región. La API local rechaza esa actualización y
  conserva los datos anteriores si la región es incompatible.
- Cuando se consulta una cuenta distinta, un texto breve identifica la sesión
  abierta en League. No se conserva la antigua tarjeta redundante «Cuenta Conectada».

## Persistencia y errores

La preferencia `scout.selected_profile.v1` contiene únicamente `[puuid, platform]`.
Su ausencia significa seguir League. Si el perfil dejó de existir en la base
local, se limpia la referencia y se vuelve al modo de seguimiento. Nunca se
recrean partidas borradas a partir de esa preferencia.

Los errores de catálogo ofrecen reintentar. Un fallo al recordar la selección
no impide consultar el perfil y se informa explícitamente. Las escrituras de
preferencia se serializan y los resultados tardíos de consultas se descartan
mediante revisiones, evitando sustituir el último perfil elegido.

La selección no descarga historiales de todas las cuentas: lista los perfiles
locales y carga únicamente el historial elegido. Los cambios de selección no
alteran el contexto activo de captura, Coach, HUD ni el diario de la partida.

## Validación

- `test/application/scout_profile_selection_test.dart`: reinicio, elección por
  región, nombres iguales, desconexión, seguimiento, respuestas tardías,
  preferencias borradas/malformadas, fallo de escritura y disposición.
- `test/presentation/scout_profile_selector_test.dart`: selección real mediante
  dropdown, regreso al seguimiento sin League, escalado y ancho reducido,
  recuperación del error de catálogo.
- `test/application/league_controller_cold_storage_test.dart`: lista persistida
  sin solicitudes LCU ni cambio de sesión activa.
- Pruebas existentes de Scout: búsqueda, caché, sincronización, historial y layouts.

Estas pruebas no equivalen a cambiar manualmente entre dos sesiones reales de
Riot en regiones distintas. Ese recorrido depende de las cuentas y del cliente
League instalado y no se considera verificado por los dobles de prueba.
