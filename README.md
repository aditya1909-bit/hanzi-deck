# Hanzi Deck

Hanzi Deck is an offline-first flashcard app for macOS, iPhone, Windows, and Android. It is designed for learning Chinese words without losing sight of the individual characters inside them.

Type a simplified or traditional Chinese word and the app fills in its tone-marked pinyin and English meaning from the bundled CC-CEDICT dictionary. You can also import screenshots or photos containing several words, review the OCR results, and create cards in a batch.

## Download

### [Download Hanzi Deck for macOS](https://github.com/aditya1909-bit/hanzi-deck/releases/latest/download/HanziDeck-macOS.dmg)

Requires macOS 14 or newer. The download supports both Apple Silicon and Intel Macs. Open the disk image, then drag **Hanzi Deck** into **Applications**.

If macOS asks for confirmation on first launch, open **System Settings → Privacy & Security** and choose **Open Anyway** for Hanzi Deck.

### [Download Hanzi Deck for Windows](https://github.com/aditya1909-bit/hanzi-deck/releases/latest/download/HanziDeck-Windows-x64.zip)

Requires 64-bit Windows 10 version 1809 or newer. Extract the ZIP, then open `HanziDeck.exe`.

### [Download Hanzi Deck for Android](https://github.com/aditya1909-bit/hanzi-deck/releases/latest/download/HanziDeck-Android.apk)

Requires Android 6 or newer. Open the APK on your phone and approve installation from your browser when Android asks.

### iPhone app

The repository includes a native iOS 17+ app with the same study modes, schedulers, offline dictionary, image import, and black-and-orange interface. When iCloud is enabled, decks sync privately between the learner’s Apple devices.

Open `HanziDeckMobile.xcodeproj` in Xcode to run it on an iPhone or simulator. Release and CloudKit configuration are covered in the [iPhone distribution guide](docs/IOS_DISTRIBUTION.md).

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
- Native .NET MAUI interfaces for Android 6+ and Windows 10+
- Local-first decks and review progress with SwiftData
- Portable deck export and import with review progress preserved
- Private iCloud sync on iPhone
- Separate schedules for word and character mastery
- Automatic, editable offline dictionary lookup
- Offline screenshot and photo import using Apple Vision
- Simplified and traditional Chinese support
- Per-deck FSRS-6, SM-2, Leitner, or simple scheduling
- Dark-only black and McLaren-orange design
- Full keyboard review controls and VoiceOver labels
- No account or analytics

## Build or modify the app

Clone the repository, then build the app without installing third-party dependencies:

```bash
./Scripts/build_app.sh
open dist/HanziDeck.app
```

To create the downloadable disk image and ZIP used by GitHub Releases:

```bash
./Scripts/package_release.sh
```

Release packaging and optional notarization are documented in the [macOS distribution guide](docs/MACOS_DISTRIBUTION.md).

### Work in Xcode

Requirements:

- macOS 14 or newer
- Xcode 26 or a newer compatible release

Open `Package.swift` in Xcode, select the `HanziDeck` scheme, choose **My Mac**, and run. The dictionary is included, so the app works without network access.

For iPhone development, open `HanziDeckMobile.xcodeproj`, choose an iPhone or simulator, and run the `HanziDeckMobile` scheme. Select a development team when running on a physical device or testing iCloud sync.

### Android and Windows development

The Android and Windows apps share a .NET MAUI project while using native platform controls. See the [cross-platform development guide](CrossPlatform/README.md) for build, packaging, and architecture details.

```bash
dotnet workload install maui-android maui-windows
dotnet build CrossPlatform/HanziDeck/HanziDeck.csproj -f net10.0-android
dotnet build CrossPlatform/HanziDeck/HanziDeck.csproj -f net10.0-windows10.0.19041.0
```

Decks move between every version through the same `.hanzideck.json` import/export format, including cards, character contexts, scheduler choice, and review progress.

## Development

```bash
swift test
swift build
```

The Apple codebase uses SwiftUI, SwiftData, Vision, and SQLite directly. Application code lives in `AppSources/HanziDeck`; tests live in `Tests/HanziDeckTests`. Android and Windows code lives in `CrossPlatform/HanziDeck`.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contribution workflow and project conventions. Bug reports and focused pull requests are welcome.

## Dictionary and licenses

Application source code is available under the [MIT License](LICENSE).

The bundled dictionary is CC-CEDICT, published by MDBG and community contributors under CC BY-SA 4.0. Its attribution, source release, and checksum are recorded in `AppSources/HanziDeck/Resources/CC-CEDICT-LICENSE.txt` and inside the app.

To rebuild the read-only SQLite dictionary from an official CC-CEDICT release:

```bash
python3 Scripts/build_dictionary.py /path/to/cedict.txt.gz AppSources/HanziDeck/Resources/cedict.sqlite
```

## Privacy

OCR and dictionary lookup happen on the device. The macOS, Windows, and Android apps store study data locally, while the iPhone app can use the learner’s private iCloud database for synchronization. Portable deck files can be saved through a cloud-backed Files provider to move progress between platforms. Hanzi Deck has no separate account, analytics service, or developer-operated study-data server.
