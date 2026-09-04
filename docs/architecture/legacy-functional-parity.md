# Scoutr to GodSense functional parity

- Updated: 2026-09-04
- Sources inspected:
  - installed Electron renderer in `@frontendshell`;
  - extracted `scoutr-backend.exe` Python modules;
  - `scoutr-local-coach/server.js`;
  - current GodSense sources and automated tests.

This document tracks visible, usable product behavior. A class, endpoint, or
empty panel does not count as implemented. Highlights and Discord Rich Presence
are deliberate product exclusions. Deterministic coaching and local Sherpa
STT/TTS work without AI. Generative coaching is optional and runs through a
user-selected Kilo/OpenCode runtime and provider; it is not a backend
requirement for League, vision, Scout or voice.

## Parity matrix

| Scoutr capability | GodSense status | Evidence or remaining work |
| --- | --- | --- |
| Windows desktop shell | **Exceeded** | Native Flutter shell, no Electron or local HTTP bridge |
| In-game multi-panel overlay | **Matched** | Shared Riverpod state, editable/collapsible panels, native window manager |
| Minimap capture and champion detection | **Exceeded** | Continuous DXGI Desktop Duplication/DartCV, independent of focus or game phase; exact identity and boxes on 866 real frames |
| Automatic and manual minimap calibration | **Exceeded** | Searches every active monitor and all four corners; persists stable display identity, local/virtual coordinates, DPI and rotation |
| Gank and jungler sightings | **Matched** | Native event state and Python parity corpus |
| Live Client projection | **Matched** | Players, KDA, CS, items, gold estimate, objectives and event timeline |
| LCU account and gameflow | **Matched** | Lockfile discovery, granular capabilities, event stream plus polling fallback |
| Champion Select roster | **Matched** | Candidate, locks, roles, teams, timer and account/session continuity |
| Rune recommendations and import | **Exceeded** | Real LCU recommendations by champion/role/map; no fixed Electrocute fallback |
| Item recommendations and import | **Exceeded** | Patch-exact Riot artifacts, same-patch validation and offline cache |
| Jungle routes | **Exceeded** | Patch-exact Riot Map11 paths for both teams |
| Push-to-Talk | **Matched** | Global Windows hotkey with configurable key |
| Speech-to-text | **Exceeded** | Local Sherpa STT; old local coach had no working transcription |
| Text-to-speech and voice choice | **Exceeded** | Local Sherpa TTS, copied production models and native playback |
| Immediate macro directives | **Matched** | Death, exact objective, team-gold and lane-state policies with provenance |
| Voice questions | **Exceeded** | Native STT answers factual intents locally and can use the selected AI conversation for open questions, with deterministic fallback |
| Generative coaching model | **Implemented as optional** | Downloadable pinned Kilo/OpenCode runtimes, provider/model selection, auth, streaming, cancellation and local conversation persistence |
| Scout Riot-ID lookup | **Matched** | Arbitrary Riot ID through LCU, account-scoped SQLite cache |
| Scout rank and recent matches | **Matched** | Ranked snapshot, 30 matches, progressive full scoreboard detail and timeline loading on demand |
| Scout playstyle and signature champions | **Matched** | Eight unit-labelled local metrics, evidence-based badges and top-three champion aggregation |
| Live opponent abilities | **Matched** | Patch-resolved Data Dragon passive and Q/W/E/R details enrich every live player; partial fetch failures do not suppress the remaining roster |
| Live opponent ranked profile | **Matched** | Background Riot-ID resolution and PUUID-bound ranked snapshots; loading/unavailable/unranked states are distinct |
| Pick suggestions in Champion Select | **Matched locally** | Actual pickable IDs, bans/picks filtering and personal champion mastery; explicitly labelled comfort picks, not invented counters |
| Matchup-specific knowledge | **Implemented without statistical claims** | Riot champion semantics and abilities drive deterministic advice; historical pair win rates remain intentionally absent without a licensed source |
| Team-composition champion semantics | **Matched locally** | Uses actual LCU champion playstyle axes, classes and damage type; derived guidance is not represented as matchup win-rate evidence |
| First-run guide/help | **Matched** | One-time guide with native navigation to Vision/voice settings; can be reopened from Help |
| Application updates | **Microsoft Store by product decision** | Store-managed delivery; no custom update feed or in-app updater. Store packaging/submission is not claimed as completed here. |
| Player settings | **Matched** | Voice, PTT, overlay, language/cadence, AI runtime, provider and model configuration; internal support/export surfaces are intentionally absent |
| Highlights | **Excluded by product decision** | Intentionally absent, with no feature flag or dormant contract |
| Discord Rich Presence | **Excluded by product decision** | Intentionally absent, with no feature flag or dormant contract |

## Important correction about the old local coach

`scoutr-local-coach/server.js` is not a complete knowledge source. It returns a
fixed AP build, fixed Electrocute runes, a generic matchup response, an empty
player-profile map, and a fixed Ahri pick suggestion. Its voice route sends a
literal “no transcription configured” question to the model. GodSense must not
copy those placeholders merely to turn rows green.

Parity is complete only when every **Missing** or **In progress** row above is
implemented and verified, or the product owner explicitly excludes it.
