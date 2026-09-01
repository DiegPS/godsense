# Native architecture implementation status

- Updated: 2026-09-01
- Scope: Phase 1 UI modularization and Phase 2A native data foundation
- Runtime target: Flutter/Dart/C++ on Windows, without Python, Node.js,
  Electron, local HTTP IPC, or local WebSocket IPC

## Completed

| Area | Implemented contract | Verification |
| --- | --- | --- |
| UI composition | Native Flutter navigation, modular pages, overlay, window manager; no `go_router` | Widget tests and Windows debug build |
| Runtime | In-process companion and coach gateways expose only active projection, settings, and support contracts; no external process startup | Legacy runtime sources, unused backend placeholders, and Dio dependency removed |
| Vision | Win32 capture plus DartCV processing | Exact parity on 120 synthetic and 866 real frames |
| Calibration | Native detection, validation, persistence, and UI | Controller tests |
| Account lifetime | `AccountContext` survives a game and changes only with account identity | Coordinator tests |
| Game lifetime | Champ Select through Post Game shares one logical generation | Coordinator and foundation tests |
| LCU compatibility | Granular capability results; known endpoint probing only | Probe tests |
| LCU reactivity | `OnJsonApiEvent` accelerates REST reconciliation; polling remains fallback | WebSocket protocol tests |
| Rune recommendations | Native LCU alternatives by champion, role, and map, including summoner spells and explicit import | Live LCU 16.17 probe and source contract tests |
| Item recommendations | Patch-exact Riot champion BIN overrides by map, mode, and role; Data Dragon validation, offline cache, and item-set import | Live Ahri 16.17 extraction and source/cache tests |
| Jungle routes | Patch-exact Riot `Map11` routes for both teams, with validated camp order and offline cache | Live CommunityDragon 16.17 extraction and parser/cache tests |
| Live Client | Native polling, current projection, complete event journal, logical game time | Adapter and projection parity tests |
| Live champion abilities | Patch-resolved Data Dragon passive and Q/W/E/R data enriches the live roster without blocking Live Client polling | Catalog and projection tests |
| Scout | Connected account plus arbitrary Riot ID lookup through LCU; legacy participant identities/stats are normalized; rank, scoreboards, factual playstyle metrics and signature champions remain available from the account-scoped cache | Live LCU 16.17 lookup/schema inspection and SQLite/controller/analyzer/widget tests |
| Data Dragon | Resource contracts, patch resolution, validation, and content-addressed cache | Resolver tests |
| Voice | Sherpa STT, global Push-to-Talk, multiple local TTS models, native playback | Unit/lifecycle tests; copied-model discovery tests |
| Voice coach | `STT -> intent -> live/lobby/vision/Riot facts -> advice -> TTS`; answers jungle, objective-specific state, build, measured game/lane state, and matchup context, with stale-result suppression | Controller and 17 tactical engine tests |
| Provenance | Raw source records separated from decoded observations/events/advice | SQLite repository and adapter tests |
| Vision journal | DartCV sightings stored by `MatchKey`, session generation, game time, and confidence | Adapter deduplication tests |
| Advice journal | Voice question and tactical advice stored separately with evidence and confidence | Adapter tests |
| Persistence ownership | One database owner in `NativeLeagueFoundation`; UI uses application ports | Scout and foundation tests |
| Product scope | Coaching, vision, voice, LCU, and Scout are first-class; Highlights and Discord Rich Presence are intentionally excluded | No dormant settings, gateway contracts, or UI placeholders |

## Current measured baseline

The complete suite currently has 171 passing tests and 13 explicitly skipped
native smoke tests. The skipped tests require model-path environment variables;
model discovery from the copied Airstream cache is covered separately.

The latest complete real-corpus run processed 866 frames with:

- precision: 100%
- recall: 100%
- identity agreement: 100%
- exact boxes: 1,249 / 1,249
- average IoU: 1.0
- average DartCV time in that run: 19.98 ms/frame

The 19.98 ms result is the honest end-to-end comparator measurement for that
run. It is not reported as less than 10 ms.

## Deliberately not copied from the old coach

`C:\Users\dpahu\scoutr-local-coach\server.js` does not contain a reliable
champion or patch knowledge base. Its fallback returns fixed Electrocute/AP
runes and generic matchup/teamfight prose independent of the actual champion.
Copying that behavior would produce confident but false recommendations.

GodSense reads the League Client's native rune recommendations and exposes all
returned alternatives with their exact recommendation IDs. Item builds come
from Riot's patch-specific champion BIN artifacts, select the map/mode/position
override, validate every item against the same-patch Data Dragon catalog, and
remain available from a same-patch offline cache. No generic Python fallback is
used.

## Gates that require a real League installation/session

Automated local tests cannot prove behavior owned by a running Riot client.
Before a release candidate, run an on-machine acceptance session covering:

1. LCU lockfile discovery and credential rotation.
2. `OnJsonApiEvent` connection against the installed client.
3. Capability degradation when individual endpoints return 404/5xx.
4. Champ Select to In Progress to Post Game session continuity.
5. Rune and item-set writes with explicit user action.
6. Live Client reconnect while the same match remains active.
7. Push-to-Talk, selected Sherpa model, audio playback, overlay focus, and
   fullscreen League behavior on the target machine.

## Next product decision: matchup-specific tactical knowledge

Matchup-specific advice needs a trusted, versioned input. Runes and item builds
now use Riot-owned artifacts and retain their patch, champion, position, map,
mode, IDs, and source URI. The next implementation must choose and license a
matchup evidence source, then store:

- champion, role, opponent, queue, and rank context;
- requested patch and exact resolved artifact version;
- sample size, collection window, and source version;
- runes/items with Data Dragon validation;
- confidence and fallback reason;
- immutable knowledge ID plus lineage into generated advice.

Acceptance must compare GodSense against a held-out match corpus using coverage,
illegal recommendation rate, patch mismatch rate, actionability, temporal
relevance, and outcome-neutral expert review. A recommendation is not “better”
merely because it differs from Python; it must be more correct, more specific,
or better supported by evidence.
