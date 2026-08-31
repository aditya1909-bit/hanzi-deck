# Contributing to Hanzi Deck

Thanks for considering a contribution. Hanzi Deck is intentionally small and native: SwiftUI, SwiftData, Apple Vision, and SQLite, with no third-party runtime dependencies.

## Getting started

1. Fork and clone the repository.
2. Open `Package.swift` in Xcode and run the `HanziDeck` scheme on **My Mac**.
3. For iPhone changes, open `HanziDeckMobile.xcodeproj` and run the `HanziDeckMobile` scheme.
4. Run `swift test` before making changes.
5. Create a focused branch and keep each commit limited to one coherent change.

The bundled dictionary is already present, so a normal build does not need network access.

Maintainers publish a release by pushing a version tag such as `v1.0.0`. GitHub Actions tests the project and attaches a disk image, ZIP, and SHA-256 checksums to the permanent release page.

## Pull requests

- Explain the learner-facing problem and the chosen behavior.
- Include tests for scheduling, persistence, parsing, or session-selection changes.
- Keep the dark black-and-orange visual language and preserve keyboard and VoiceOver support.
- Avoid unrelated formatting or refactors.
- Do not add a dependency when an Apple framework or a small local implementation is sufficient.
- Never commit personal deck data, DerivedData, build products, or signing credentials.

Bug reports with a minimal reproduction are especially useful. For larger product changes, open a feature request first so the interaction can be agreed on before implementation.

## Dictionary changes

CC-CEDICT is licensed separately under CC BY-SA 4.0. If you rebuild or modify the bundled data, retain its attribution and document the source release and checksum. Run:

```bash
python3 Scripts/build_dictionary.py /path/to/cedict.txt.gz AppSources/HanziDeck/Resources/cedict.sqlite
```

## Scheduler changes

Schedulers are small local implementations behind `Scheduler.apply`. Keep them deterministic and add fixed-clock tests for every changed transition. FSRS behavior follows the published FSRS-6 formulas and default parameters; document any future parameter or formula changes in the pull request.

## Code style

Match the surrounding code. Prefer descriptive names, short functions, and direct control flow. Comments should explain a non-obvious decision, not restate the code.
