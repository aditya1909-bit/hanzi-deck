# Android and Windows apps

The `HanziDeck` project is the native Android and Windows edition of Hanzi Deck. It uses .NET MAUI so the two platforms share learning logic while rendering through Android controls and Windows App SDK/WinUI.

## Included features

- Automatic offline CC-CEDICT lookup with editable pinyin and meanings
- Word and contextual character cards with independent review progress
- Hanzi Recognition, Meaning Recall, Pinyin Recall, Character Context, and Mixed Review
- FSRS-6, SM-2, Leitner, and Simple scheduling
- Due Reviews, Learn New, Difficult Practice, Quick Cram, and Free Practice
- On-device Chinese OCR for importing multiple words from screenshots or photos
- Deck creation, editing, deletion, search, import, and export
- The same portable `.hanzideck.json` format used by the Apple apps
- Dark-only black, charcoal, white, and McLaren-orange interface

## Requirements

- .NET 10 SDK
- The `maui-android` workload for Android builds
- The `maui-windows` workload and Windows 10 or 11 for Windows builds
- Visual Studio 2026 with .NET MAUI is the easiest option for contributors who prefer a graphical IDE

Install the command-line workloads on Windows:

```powershell
dotnet workload install maui-android maui-windows
```

## Build

Run the shared learning-logic checks:

```powershell
dotnet run --project CrossPlatform/HanziDeck.CoreChecks/HanziDeck.CoreChecks.csproj --configuration Release
```

Build Android:

```powershell
dotnet build CrossPlatform/HanziDeck/HanziDeck.csproj -f net10.0-android -c Debug
```

Build Windows:

```powershell
dotnet build CrossPlatform/HanziDeck/HanziDeck.csproj -f net10.0-windows10.0.19041.0 -c Debug
```

The GitHub workflows build both targets for every pull request. Tagged releases create a signed Android APK and a self-contained Windows ZIP, then attach both to the same release as the Mac download.

## Project layout

- `Models.cs`, `Scheduler.cs`, and `StudySession.cs`: shared deck and learning behavior
- `DeckStore.cs`: local persistence and Apple-compatible deck transfer
- `DictionaryService.cs`: indexed lookup in the bundled CC-CEDICT SQLite database
- `OcrService.cs`: Android ML Kit and Windows OCR implementations
- `DeckListPage.cs`, `DeckPage.cs`, `CardEditorPage.cs`, `ImageImportPage.cs`, and `StudyPage.cs`: native app screens
- `Platforms`: small Android and Windows host projects

## Android signing

For stable upgradeable APK releases, set these repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`

The release workflow creates an installable temporary-signed APK when those secrets are not configured. Configure a permanent key before publishing updates broadly so future APKs can upgrade existing installations.

## OCR notes

Android bundles the Chinese ML Kit text-recognition model. Windows uses the operating system’s local OCR engine; installing the Simplified Chinese language pack enables Chinese recognition. OCR does not upload images to a Hanzi Deck server.

## Dependencies and licenses

The cross-platform project uses .NET MAUI, the .NET MAUI Community Toolkit, sqlite-net-pcl, and Microsoft’s .NET bindings for Google ML Kit Chinese text recognition. Package licenses and notices remain governed by their respective projects. The bundled CC-CEDICT data remains available under CC BY-SA 4.0; attribution is included with every app build.
