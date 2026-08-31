# Hanzi Deck

Hanzi Deck is a native, offline macOS flashcard app for learning Chinese words without losing sight of the individual characters inside them.

Type a simplified or traditional Chinese word and the app fills in its tone-marked pinyin and English meaning from the bundled CC-CEDICT dictionary. You can also import screenshots or photos containing several words, review the OCR results, and create the cards together.

## Learning methods

Every deck supports five prompt styles:

- **Hanzi Recognition:** Chinese → pinyin and meaning
- **Meaning Recall:** English → Chinese and pinyin
- **Pinyin Recall:** pinyin → Chinese and meaning
- **Character Context:** one character → contextual readings and source words
- **Mixed Review:** a shuffled combination of all four

The selected method can be combined with Due Reviews, Learn New, Difficult Practice, a 20-card Quick Cram, or an unrestricted Free Practice session. Due Reviews and Learn New update the spaced-repetition schedule; voluntary practice does not move due dates.

## Highlights

- Native SwiftUI interface for macOS 14+
- Device-local decks and review progress with SwiftData
- Separate schedules for word and character mastery
- Automatic, editable offline dictionary lookup
- Offline screenshot and photo import using Apple Vision
- Simplified and traditional Chinese support
- Four-button Again / Hard / Good / Easy scheduling
- Dark-only black and McLaren-orange design
- Full keyboard review controls and VoiceOver labels
- No account, analytics, server, or runtime dependency

## Install or run

### Use the built app

Download a build from the repository's Actions artifacts, or create a local app bundle:

```bash
./Scripts/build_app.sh
open dist/HanziDeck.app
```

The script produces an ad-hoc signed app for local use. Public notarized releases are not currently provided.

### Run in Xcode

Requirements:

- macOS 14 or newer
- Xcode 26 or a newer compatible release

Open `Package.swift` in Xcode, select the `HanziDeck` scheme, choose **My Mac**, and run. The dictionary is included, so the app works without network access.

## Development

```bash
swift test
swift build
```

The codebase uses SwiftUI, SwiftData, Vision, and SQLite directly. Application code lives in `AppSources/HanziDeck`; tests live in `Tests/HanziDeckTests`.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contribution workflow and project conventions. Bug reports and focused pull requests are welcome.

## Dictionary and licenses

Application source code is available under the [MIT License](LICENSE).

The bundled dictionary is CC-CEDICT, published by MDBG and community contributors under CC BY-SA 4.0. Its attribution, source release, and checksum are recorded in `AppSources/HanziDeck/Resources/CC-CEDICT-LICENSE.txt` and inside the app.

To rebuild the read-only SQLite dictionary from an official CC-CEDICT release:

```bash
python3 Scripts/build_dictionary.py /path/to/cedict.txt.gz AppSources/HanziDeck/Resources/cedict.sqlite
```

## Privacy

Hanzi Deck stores decks and progress only on the Mac running the app. OCR and dictionary lookup happen locally. The app does not send study content anywhere.
