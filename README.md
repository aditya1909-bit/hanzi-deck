# Hanzi Deck

Hanzi Deck is a native, offline-first macOS and iPhone flashcard app for learning Chinese words without losing sight of the individual characters inside them.

Type a simplified or traditional Chinese word and the app fills in its tone-marked pinyin and English meaning from the bundled CC-CEDICT dictionary. You can also import screenshots or photos containing several words, review the OCR results, and create the cards together.

## Download

### [Download Hanzi Deck for macOS](https://github.com/aditya1909-bit/hanzi-deck/releases/latest/download/HanziDeck-macOS.dmg)

Requires macOS 14 or newer. The download supports both Apple Silicon and Intel Macs. Open the disk image, then drag **Hanzi Deck** into **Applications**.

The current download is open source and ad-hoc signed. On first launch, macOS may ask you to approve it: open **System Settings → Privacy & Security**, find the Hanzi Deck message, and choose **Open Anyway**. Future tagged releases are configured to require Developer ID signing and Apple notarization so this extra approval is no longer necessary.

### iPhone app

The native iOS 17+ app is included in `HanziDeckMobile.xcodeproj`. It has the same learning modes, schedulers, offline dictionary, screenshot import, and black-and-orange interface, with private iCloud deck sync for signed builds.

Apple does not permit a generally installable unsigned iPhone download from GitHub. The project is ready for a public TestFlight link, the App Store, or an eligible Apple-approved alternative distribution route once the maintainer’s Apple Developer account is configured. See [iPhone distribution and iCloud setup](docs/IOS_DISTRIBUTION.md).

## Learning methods

Every deck supports five prompt styles:

- **Hanzi Recognition:** Chinese → pinyin and meaning
- **Meaning Recall:** English → Chinese and pinyin
- **Pinyin Recall:** pinyin → Chinese and meaning
- **Character Context:** one character → contextual readings and source words
- **Mixed Review:** a shuffled combination of all four

The selected method can be combined with Due Reviews, Learn New, Difficult Practice, a 20-card Quick Cram, or an unrestricted Free Practice session. Due Reviews and Learn New update the spaced-repetition schedule; voluntary practice does not move due dates.

## Scheduling algorithms

Each deck can use a different scheduling algorithm, and you can switch from the deck screen without recreating cards or losing the current due dates:

- **FSRS-6:** the recommended default, with an adjustable 70–97% target retention
- **SM-2 Classic:** the original SuperMemo quality-and-ease algorithm
- **Leitner Boxes:** a simple seven-box progression
- **Simple:** predictable Again / Hard / Good / Easy interval multipliers

The chosen algorithm controls the next scheduled review. Word and character progress remains independent, and Free Practice, Difficult Practice, and Quick Cram never alter scheduling data.

## Highlights

- Native SwiftUI interfaces for macOS 14+ and iOS 17+
- Local-first decks and review progress with SwiftData
- Private iCloud sync in signed mobile builds
- Separate schedules for word and character mastery
- Automatic, editable offline dictionary lookup
- Offline screenshot and photo import using Apple Vision
- Simplified and traditional Chinese support
- Per-deck FSRS-6, SM-2, Leitner, or simple scheduling
- Dark-only black and McLaren-orange design
- Full keyboard review controls and VoiceOver labels
- No account, analytics, server, or runtime dependency

## Build or modify the app

Clone the repository, then create the same local app bundle without installing dependencies:

```bash
./Scripts/build_app.sh
open dist/HanziDeck.app
```

To create the downloadable disk image and ZIP used by GitHub Releases:

```bash
./Scripts/package_release.sh
```

Maintainers can follow [macOS release signing](docs/MACOS_DISTRIBUTION.md) to publish a notarized download.

### Work in Xcode

Requirements:

- macOS 14 or newer
- Xcode 26 or a newer compatible release

Open `Package.swift` in Xcode, select the `HanziDeck` scheme, choose **My Mac**, and run. The dictionary is included, so the app works without network access.

For iPhone development, open `HanziDeckMobile.xcodeproj`, select your development team, choose an iPhone or simulator, and run the `HanziDeckMobile` scheme. A paid Apple Developer account and configured CloudKit container are required for device distribution and iCloud sync.

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

OCR and dictionary lookup happen locally. The macOS direct download stores study data only on that Mac. Signed mobile builds use the learner’s private iCloud database to synchronize decks and review progress between their Apple devices; Hanzi Deck has no separate account, analytics service, or developer-operated study-data server.
