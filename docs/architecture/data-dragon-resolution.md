# Data Dragon resolution contract

GodSense never treats the League client version, gameplay patch, and Data
Dragon build as interchangeable values.

```text
clientVersion 16.17.555.1
        -> PatchKey 16.17
        -> candidates from current regional realm and versions.json
        -> validated DataDragonVersion 16.17.2
```

Every resolved artifact records the client version when known, requested patch,
resolved Data Dragon build, requested and resolved locales, resolution time,
validator version, and SHA-256 content identity.

## Resolution intents

- `currentRegional` may consult the platform realm before `versions.json`.
- `historicalPatch` uses the versions manifest and never lets the current realm
  determine an old match's assets.

Locale fallback may use `en_US` when the requested translation is unavailable.
It cannot select an artifact belonging to a different gameplay patch.

## Local artifact store

Validated bytes are immutable objects under `objects/<prefix>/<sha256>`. Exact
resolution manifests point to those objects and are keyed by intent, patch,
platform, locale, and logical resource. Reads recompute SHA-256, so truncated or
modified objects are rejected rather than silently consumed.

An exact cached resolution can serve startup and offline use without contacting
Data Dragon. A missing exact resolution fails explicitly; GodSense does not
substitute the newest global patch.
