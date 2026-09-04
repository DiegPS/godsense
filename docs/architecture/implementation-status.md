# Native architecture implementation status

- Updated: 2026-09-03
- Scope: Native product foundation plus optional local AI runtime integration
- Core runtime target: Flutter/Dart/C++ on Windows, without Python, Node.js or
  Electron. AI coaching may start one isolated, private OpenCode-compatible
  sidecar selected by the user.

## Completed

| Area | Implemented contract | Verification |
| --- | --- | --- |
| UI composition | Native Flutter navigation, modular pages, overlay, window manager; no `go_router` | Widget tests and Windows debug build |
| Core runtime | League, vision, deterministic coaching, voice and persistence remain in-process and do not require a backend | External coach/runtime shims, unused support exporters and IPC placeholders removed |
| Optional AI runtime | Version-pinned OpenCode/Kilo packages, isolated process lifecycle, dynamic loopback port, ephemeral Basic Auth, health gating and Windows Job Object cleanup | Real OpenCode 1.18.25 and Kilo 7.5.9 installations pass process/API integration tests |
| AI local API | Shared typed client covers providers, auth methods, sessions, messages, async prompt, abort, delete and SSE | Same integration test passes against both runtimes without inference or billing |
| Vision | Continuous DXGI Desktop Duplication capture plus isolated DartCV processing; independent from League focus and game phase | Exact parity on 120 synthetic and 866 real frames; real Windows DXGI smoke run |
| Calibration | Automatic search across every corner of every active monitor, manual adjustment, stable display identity, mixed-DPI/negative-coordinate persistence and migration | Controller, topology, and multi-display tests |
| Account lifetime | `AccountContext` survives a game and changes only with account identity | Coordinator tests |
| Game lifetime | Champ Select through Post Game shares one logical generation | Coordinator and foundation tests |
| LCU compatibility | Granular capability results; known endpoint probing only | Probe tests |
| LCU reactivity | `OnJsonApiEvent` accelerates REST reconciliation; polling remains fallback | WebSocket protocol tests |
| Rune recommendations | Native LCU alternatives by champion, role, and map, including summoner spells and explicit import | Live LCU 16.17 probe and source contract tests |
| Item recommendations | Patch-exact Riot champion BIN overrides by map, mode, and role; Data Dragon validation, offline cache, and item-set import | Live Ahri 16.17 extraction and source/cache tests |
| Jungle routes | Patch-exact Riot `Map11` routes for both teams, with validated camp order and offline cache | Live CommunityDragon 16.17 extraction and parser/cache tests |
| Live Client | Native polling, current projection, complete event journal, logical game time | Adapter and projection parity tests |
| Live champion abilities | Patch-resolved Data Dragon passive and Q/W/E/R data enriches the live roster without blocking Live Client polling | Catalog and projection tests |
| Scout | Connected account plus arbitrary Riot ID lookup through LCU; participant identities/stats are normalized; rank, scoreboards, timelines, factual playstyle metrics and signature champions remain available from the account-scoped cache and update progressively | Live LCU 16.17 lookup/schema inspection and SQLite/controller/analyzer/widget tests |
| Data Dragon | Resource contracts, patch resolution, validation, and content-addressed cache | Resolver tests |
| Voice | Sherpa STT, global Push-to-Talk, multiple local TTS models, native playback | Unit/lifecycle tests; copied-model discovery tests |
| Voice coach | `STT -> intent -> live/lobby/vision/Riot facts -> advice -> TTS`; open questions use the selected AI runtime when ready and fall back to deterministic advice on failure | Controller and tactical engine tests |
| Matchup coaching | Uses Riot client playstyle/class/tactical attributes and patch-resolved ability names/cooldowns when available; explicitly falls back to general rules without inventing pair win rates | Tactical engine semantic and fallback tests |
| Optional AI conversation | Persistent local conversation, selected provider/model, incremental SSE rendering, cancellation, runtime auto-start preference and provider API-key/OAuth flows | Controller, client and widget tests plus real Kilo/OpenCode API probes |
| Provenance | Raw source records separated from decoded observations/events/advice | SQLite repository and adapter tests |
| Vision journal | DartCV sightings stored by `MatchKey`, session generation, game time, and confidence | Adapter deduplication tests |
| Advice journal | Voice question and tactical advice stored separately with evidence and confidence | Adapter tests |
| Persistence ownership | One database owner in `NativeLeagueFoundation`; UI uses application ports | Scout and foundation tests |
| Product scope | Coaching, vision, voice, LCU, and Scout are first-class; Highlights and Discord Rich Presence are intentionally excluded | No dormant settings, gateway contracts, or UI placeholders |

## Current measured baseline

Static analysis is kept at zero issues. Native smoke tests that require a live
League session or explicit model-path environment variables remain environment
gates; copied-model discovery is covered separately.

The latest complete real-corpus run processed 866 frames with:

- precision: 100%
- recall: 100%
- identity agreement: 100%
- exact boxes: 1,249 / 1,249
- average IoU: 1.0
- average DartCV time in that run: 19.98 ms/frame

The 19.98 ms result is the honest end-to-end comparator measurement for that
run. It is not reported as less than 10 ms.

The 2026-09-03 native desktop smoke run captured the persisted 527x532 minimap
region continuously without League running. Stable samples measured DXGI at
1.48-2.62 ms/frame and DartCV at 23.53-31.60 ms/frame. Desktop Duplication
keeps its last valid desktop texture when Windows reports no visual change and
recreates its session after display/mode loss; the UI clears current detections
instead of retaining a frozen frame on capture errors.

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

## Optional future input: statistical matchup evidence

GodSense now produces matchup-specific deterministic advice from Riot-owned
champion semantics and ability data. It deliberately does not claim historical
win rates or matchup samples. Adding those statistical claims would require a
trusted, licensed and versioned evidence source, then storing:

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
