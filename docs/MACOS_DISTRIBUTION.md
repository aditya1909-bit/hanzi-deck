# macOS release signing

Tagged releases are built as universal Apple Silicon and Intel apps, signed with Developer ID, submitted to Apple for notarization, stapled, and packaged as a drag-to-Applications disk image.

Configure these encrypted GitHub Actions secrets before pushing a release tag:

- `MACOS_CERTIFICATE_P12`: base64-encoded Developer ID Application certificate and private key
- `MACOS_CERTIFICATE_PASSWORD`: password used when exporting the `.p12`
- `MACOS_SIGNING_IDENTITY`: complete certificate name, including the team name and Team ID
- `ASC_ISSUER_ID`: App Store Connect API issuer ID
- `ASC_KEY_ID`: App Store Connect API key ID
- `ASC_PRIVATE_KEY`: complete contents of the corresponding `.p8` key

The release workflow intentionally stops if any signing value is absent. This prevents an unsigned public download from replacing a notarized release.

To publish:

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Support/Info.plist`.
2. Commit and push the version change.
3. Create and push a matching tag, such as `v1.1.0`.
4. Confirm that **Publish macOS release** succeeds before sharing the download link.

Local contributors do not need signing credentials. `Scripts/build_app.sh` continues to create an ad-hoc-signed local app when `HANZI_DECK_SIGNING_IDENTITY` is not set.
