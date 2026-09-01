# iPhone distribution and iCloud setup

This guide covers TestFlight, App Store, and CloudKit configuration for the native iOS 17+ app.

## TestFlight and App Store

The repository includes a manually triggered **Upload iPhone app to TestFlight** workflow. TestFlight is the recommended beta channel, and the same App Store Connect project can be used for a public App Store release.

1. Create the app in App Store Connect with bundle ID `com.aditya1909.HanziDeck`.
2. Create the CloudKit container `iCloud.com.aditya1909.HanziDeck` and associate it with the app ID.
3. Add these encrypted GitHub Actions secrets:
   - `APPLE_TEAM_ID`
   - `ASC_ISSUER_ID`
   - `ASC_KEY_ID`
   - `ASC_PRIVATE_KEY` containing the complete `.p8` key
4. Run **Upload iPhone app to TestFlight** from the Actions page.
5. In App Store Connect, add the processed build to an external testing group and create its public link.

For details, see Apple’s guides to [TestFlight public links](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers) and [uploading builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds).

## Alternative distribution

Apple also supports alternative distribution programs in eligible regions. Teams using those programs can start with Apple’s [regional distribution requirements](https://developer.apple.com/documentation/marketplacekit/participating-in-alternative-distribution-for-specific-regions) and [Web Distribution setup](https://developer.apple.com/documentation/marketplacekit/distributing-your-app-from-your-website).

## iCloud deck sync

The mobile target uses SwiftData with the private CloudKit database in `iCloud.com.aditya1909.HanziDeck`. Words, character contexts, scheduler state, and deck settings synchronize through the learner’s Apple Account. Local study remains available while offline and merges when CloudKit reconnects.

Before releasing:

1. Select the development team in `HanziDeckMobile.xcodeproj` and confirm the iCloud, CloudKit, Push Notifications, and Remote notifications capabilities.
2. Run a development build while signed into iCloud so SwiftData creates the development schema.
3. Inspect the schema in CloudKit Console and deploy it to production.
4. Test two devices using the same Apple Account, including offline edits and reconnecting.

The standard macOS build uses local SwiftData storage. A macOS target signed by the same team can join the shared CloudKit store by enabling the same container and capabilities. Apple documents the model setup in [Syncing model data across a person’s devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices).
