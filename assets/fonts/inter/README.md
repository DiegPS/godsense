# Inter Variable

Official, unmodified Inter 4.1 font files, bundled locally with GodSense.

- Source: https://github.com/rsms/inter/releases/tag/v4.1
- Archive: https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip
- License: SIL Open Font License 1.1, included as `OFL.txt` (upstream `LICENSE.txt`).
- Normal: `InterVariable.ttf`
- Italic: `InterVariable-Italic.ttf`
- Variable axes: `wght` 100–900 and `opsz` 14–32.

SHA-256:

```text
4989b125924991b90d05b2d16e0e388c48f7d5bb8b30539bbf9c755278d0ccaf  InterVariable.ttf
d6f1f6a172d9e588438db9f986fd5cfad7b30f644374080a8a9d4d91e344586f  InterVariable-Italic.ttf
```

Flutter family: `InterVariable`. Do not register duplicate static weights.
On the project's Flutter SDK, `TextStyle.fontWeight` controls `wght` directly;
do not also set a conflicting weight in `fontVariations`.

The shared text theme sets optical size per typography role, clamped to 14–32.
If a custom style changes font size substantially, also choose its optical size
or use the matching theme role. Keep system text scaling enabled; optical size
does not replace accessibility scaling or fix OS/compositor scaling issues.

No runtime font downloads or font-loading package is needed.
