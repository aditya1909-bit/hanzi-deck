# iPhone distribution and iCloud setup

Hanzi Deck Mobile is a native iOS 17+ app. Apple requires every installable iPhone build to be signed through an Apple-supported distribution method; publishing an unsigned `.ipa` on GitHub does not create a generally installable app.

## Recommended public distribution

For a global, nontechnical audience, publish through the App Store. During beta testing, TestFlight provides a public invitation link for up to 10,000 external testers after Apple approves the beta. The repository includes a manually triggered **Upload iPhone app to TestFlight** workflow.

1. Join the Apple Developer Program and create an app in App Store Connect with bundle ID `com.aditya1909.HanziDeck`.
2. Create the CloudKit container `iCloud.com.aditya1909.HanziDeck` and associate it with the app ID.
3. Add these encrypted GitHub Actions secrets:
   - `APPLE_TEAM_ID`
   - `ASC_ISSUER_ID`
   - `ASC_KEY_ID`
   - `ASC_PRIVATE_KEY` containing the complete `.p8` key
4. Run **Upload iPhone app to TestFlight** from the Actions page.
5. In App Store Connect, add the processed build to an external testing group and create its public link.

Apple’s official guides cover [TestFlight public links](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers) and [uploading builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds).

## Direct website or alternative distribution

Apple calls direct installation from a developer website **Web Distribution**. It is not unrestricted sideloading: Apple authorization, an eligible organization, an Apple-registered domain, signing, and Notarization are required, and availability depends on the user’s region and OS version. If the developer account qualifies, the same Xcode archive can be submitted for Notarization and assembled into Apple’s alternative distribution package. Do not publish a raw development or ad-hoc `.ipa` as a substitute.

Check Apple’s current [regional alternative-distribution requirements](https://developer.apple.com/documentation/marketplacekit/participating-in-alternative-distribution-for-specific-regions) and [Web Distribution setup](https://developer.apple.com/documentation/marketplacekit/distributing-your-app-from-your-website) before choosing this route.

## iCloud deck sync

The mobile target uses SwiftData with the private CloudKit database in `iCloud.com.aditya1909.HanziDeck`. Words, character contexts, scheduler state, and deck settings synchronize through the learner’s Apple Account. Local study remains available while offline and merges when CloudKit reconnects.

Before a production release:

1. Select the development team in `HanziDeckMobile.xcodeproj` and confirm the iCloud, CloudKit, Push Notifications, and Remote notifications capabilities.
2. Run a development build while signed into iCloud so SwiftData creates the development schema.
3. Inspect the schema in CloudKit Console and deploy it to production.
4. Test two devices using the same Apple Account, including offline edits and reconnecting.

The open-source macOS download remains local-only because GitHub cannot sign it with the project’s private iCloud entitlement. A Mac build signed by the same developer team and configured with this same CloudKit container will join the same sync store. Apple documents the required model and capability setup in [Syncing model data across a person’s devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices).
