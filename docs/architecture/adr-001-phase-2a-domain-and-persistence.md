# ADR-001: Phase 2A domain and persistence foundation

- Status: Accepted
- Date: 2026-09-01
- Owners: GodSense engineering
- Scope: Native League integration, local Scout, vision, coaching, and Data Dragon

## Context

GodSense is replacing the legacy Python, Node.js, Electron, HTTP, and local
WebSocket architecture with a native Flutter/Dart/C++ Windows application. Its
runtime data comes from LCU, Live Client Data, DartCV, Data Dragon, local user
input, and patch-versioned tactical knowledge.

These sources have different lifetimes, reliability, schemas, clocks, and
identity rules. Treating every response as mutable UI state would make account
switching, reconnects, historical analysis, and explanations unreliable. This
ADR freezes the contracts that must exist before the first SQLite schema.

## Decision

### Identity and lifetimes

1. `Puuid` identifies a League account. Account state outlives a game session.
2. A match is identified by `MatchKey(platformId, gameId)`, never by `gameId`
   alone.
3. IDs, platforms, patch keys, versions, generations, and locales are value
   objects rather than interchangeable strings.
4. `AccountContext`, `GameSession`, and transport connections have independent
   lifetimes.
5. `TransportGeneration` changes on reconnect. `GameSessionGeneration` changes
   only when the logical game changes. Transport generation is not event
   identity.

### Capabilities and LCU compatibility

6. Swagger, OpenAPI, and `/help` are development compatibility inputs only.
   Release runtime probes the known operations it needs.
7. LCU capabilities are granular and status-bearing. Connection failures and
   transient failures must not be interpreted as removed endpoints.
8. Write capabilities are not probed by mutating user data at startup.

### Source records, domain entries, and projections

9. The source does not determine semantic category. Inputs can be external
   events, source snapshots, or sensor observations.
10. Original source records are immutable and stored separately from decoded
    domain entries. A newer decoder adds an interpretation; it does not rewrite
    source bytes.
11. Observations, external events, inferences, current projections, knowledge,
    and tactical advice are distinct concepts.
12. Projections are rebuildable read models. They are not appended as complete
    copies on every polling cycle.
13. Riverpod transports application state. Reconciliation, authority, lineage,
    and Data Dragon resolution belong to domain/data services.

### Idempotency, ordering, and time

14. Every adapter declares its ingestion identity strategy. Stable source event
    IDs are scoped by their logical session or match.
15. Equal payloads are not universally equal events.
16. Polling snapshots suppress only consecutive semantic duplicates inside one
    capture epoch. `A -> B -> A` stores all three meaningful snapshots.
17. Derived entries use a deterministic derivation key based on producer,
    producer version, ordered parents, and normalized parameters.
18. Source sequence is comparable only within its producer and scope.
19. Gameplay records preserve logical `GameTime` in integer milliseconds in
    addition to wall-clock timestamps.

### Provenance and lineage

20. Common provenance contains the producer, production/ingestion times, and
    lineage. Category-specific metadata contains observation, event, inference,
    or advice semantics.
21. Authority is evaluated by fact type, temporal relevance, source scope, and
    calibrated confidence. There is no universal source ranking.
22. Original evidence is never overwritten during reconciliation. Corrections,
    contradictions, derivations, and supersession are represented by lineage.

### Schema evolution, retention, and privacy

23. Envelope/record schema versions and payload schema versions evolve
    independently.
24. Unknown payloads are retained so future decoder versions can reinterpret
    them.
25. Raw and canonical hashes serve different purposes: raw hashes verify exact
    bytes; semantic hashes compare normalized payload content.
26. Retention is explicit per adapter: permanent, match lifetime, diagnostic,
    or aggregate only.
27. LCU passwords, authorization headers, lockfile contents, and other secrets
    are never persisted. Diagnostic frames require explicit bounded retention.
28. SQLite uses migrations, foreign keys, WAL, transactions, and a single
    background writer connection.

### Data Dragon

29. Client version, patch key, and Data Dragon version are different values.
30. Data Dragon is resolved through contracts for logical resources. Realm
    entries are used only when the contract says they represent that resource.
31. Current regional resolution and historical patch resolution are separate
    intents. A current realm never resolves a historical match.
32. Requested and resolved locales are recorded. Locale fallback may change
    language, never gameplay patch semantics.
33. Artifacts are content-addressed and validations are versioned separately
    from artifact identity.
34. A cached exact resolution may be returned while it is revalidated. An
    artifact from a different gameplay patch is never a silent fallback.

## Initial physical model

Phase 2A starts with these tables:

```text
accounts                matches
account_matches

capture_epochs          source_records
domain_entries          lineage_edges
snapshot_cursors
```

Data Dragon, knowledge, account synchronization, and materialized gameplay
indexes will be added by later schema migrations. `source_records` owns raw
bytes and capture metadata. `domain_entries` owns versioned interpretations and
derived outputs.

## Ingestion rules

### Stable source event

```text
unique(namespace, match/session scope, sourceRecordKey)
```

A reconnect can redeliver it without creating a second source record.

### Polled snapshot

```text
same capture epoch + same semantic key + same previous semantic hash
    -> suppress
otherwise
    -> append and advance cursor
```

There is deliberately no global unique constraint on snapshot payload hash.

### Derived entry

```text
derivationKey = SHA-256(
  producer + producerVersion + orderedParentIds + canonicalParameters
)
```

Re-running the same deterministic rule produces the same identity.

## Consequences

- The existing native controller can keep operating during incremental
  migration.
- Source adapters can be introduced independently and replayed in tests.
- Reconnects and repeated polling cannot silently duplicate logical events.
- Future decoder releases can reinterpret retained source data.
- Tactical advice can explain which observations, events, rules, and knowledge
  produced it.
- Storage volume must be controlled at adapter boundaries; this is not a raw
  screen-recording system.

## Phase 2A delivery order

1. Domain value objects and journal contracts.
2. SQLite schema v1 and migration verification.
3. Journal repository with idempotent event and snapshot ingestion.
4. Account context and granular LCU capability models.
5. LCU source adapter behind the existing controller.
6. Live Client source adapter and projection parity tests.
7. Data Dragon contracts, resolver, and content-addressed artifact store.

