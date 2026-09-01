# macOS release signing

Tagged releases produce a universal Apple Silicon and Intel app, a drag-to-Applications disk image, a ZIP archive, and SHA-256 checksums.

The release workflow supports two signing modes:

- With Developer ID credentials, the app and disk image are signed, notarized, and stapled.
- Without Developer ID credentials, the workflow publishes an ad-hoc-signed open-source build.

Developer ID signing is recommended for the smoothest first-launch experience.

## Developer ID configuration

Add these encrypted GitHub Actions secrets to enable signing and notarization:

- `MACOS_CERTIFICATE_P12`: base64-encoded Developer ID Application certificate and private key
- `MACOS_CERTIFICATE_PASSWORD`: password used when exporting the `.p12`
- `MACOS_SIGNING_IDENTITY`: complete certificate name, including the team name and Team ID
- `ASC_ISSUER_ID`: App Store Connect API issuer ID
- `ASC_KEY_ID`: App Store Connect API key ID
- `ASC_PRIVATE_KEY`: complete contents of the corresponding `.p8` key

## Publishing a release

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Support/Info.plist`.
2. Commit and push the version change.
3. Create and push a matching tag, such as `v1.1.0`.
4. Confirm that **Publish macOS release** succeeds before sharing the download link.

Local builds use ad-hoc signing by default. Set `HANZI_DECK_SIGNING_IDENTITY` when testing with a Developer ID Application certificate.
