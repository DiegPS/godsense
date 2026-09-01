# Scoutr to GodSense functional parity

- Audited: 2026-09-01
- Sources inspected:
  - installed Electron renderer in `@frontendshell`;
  - extracted `scoutr-backend.exe` Python modules;
  - `scoutr-local-coach/server.js`;
  - current GodSense sources and automated tests.

This document tracks visible, usable product behavior. A class, endpoint, or
empty panel does not count as implemented. Highlights and Discord Rich Presence
are the only deliberate product exclusions requested by the product owner.

## Parity matrix

| Scoutr capability | GodSense status | Evidence or remaining work |
| --- | --- | --- |
| Windows desktop shell | **Exceeded** | Native Flutter shell, no Electron or local HTTP bridge |
| In-game multi-panel overlay | **Matched** | Shared Riverpod state, editable/collapsible panels, native window manager |
| Minimap capture and champion detection | **Exceeded** | Win32/DartCV; exact identity and boxes on 866 real frames |
| Automatic and manual minimap calibration | **Matched** | Native detection, validation, persistence, reset and UI |
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
| Voice questions | **Matched locally** | Jungle, objective, build, game state, lane and matchup intents; no cloud call |
| Scout Riot-ID lookup | **Matched** | Arbitrary Riot ID through LCU, account-scoped SQLite cache |
| Scout rank and recent matches | **Matched** | Ranked snapshot, 30 matches and full scoreboard detail |
| Scout playstyle and signature champions | **Matched** | Eight unit-labelled local metrics, evidence-based badges and top-three champion aggregation |
| Live opponent abilities | **Matched** | Patch-resolved Data Dragon passive and Q/W/E/R details enrich every live player; partial fetch failures do not suppress the remaining roster |
| Live opponent ranked profile | **Missing** | Must connect the existing LCU Scout resolver to the active roster |
| Pick suggestions in Champion Select | **Missing** | Old local coach returned a fixed Ahri placeholder; GodSense needs a defensible local policy |
| Matchup-specific knowledge | **Missing trusted source** | Generic rules exist and are labelled 0.55 confidence; no licensed/versioned matchup corpus yet |
| Team-composition champion semantics | **Partial** | Current profile is role-based, not champion-kit based |
| First-run guide/help | **Missing** | Installed Scoutr contains a local onboarding guide |
| Application update delivery | **Missing distribution contract** | Build works, but no GodSense release feed/installer contract exists yet |
| Settings, support artifact and diagnostics | **Matched** | Voice, PTT, overlay, language/cadence plus local secret-free support artifacts |
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
