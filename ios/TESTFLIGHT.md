# Chatty TestFlight

- App Store Connect App ID: `6809083972`
- Bundle ID: `ai.chatty.ios`
- Team: Benjamin Zhang (`9247PC9936`)
- Scheme: `Chatty` (production API; exclude `ChattyFixture`)
- Latest uploaded version/build: `0.1.0 (2)` on 2026-09-10 at 20:10 (Asia/Singapore), source commit `cb7a30a942017bab01f8ccec67b2d4332eccae1f`.
- Distribution: **TestFlight Internal Only**. This uploaded build cannot be submitted to external testing or App Store release.
- Console: https://appstoreconnect.apple.com/teams/d429cbf8-b4df-43fe-b7de-3cdb24e874e7/apps/6809083972/testflight

## Current upload: 0.1.0 (2)

The 2026-09-10 iOS activity / Mika update was archived, signature-verified and uploaded through Xcode Organizer. Organizer confirmed `Chatty 0.1.0 (2) uploaded`, followed by `Uploaded to Apple` and build number `2`. Source, validation and upload observations are in [the delivery record](../.sdlc/changes/20260910-ios-activity-mika-flow/release.md).

App Store Connect browser login remains pending. Apple processing, assignment to **Benjamin Internal**, and installation have **not yet been verified for build 2**. After signing in, inspect build `2`, save the prepared [Chinese test notes](../.sdlc/changes/20260910-ios-activity-mika-flow/testflight-notes.zh-Hans.txt), and add it to the existing group.

## Rebuild

```sh
swift scripts/generate-ios-icon.swift
python3 scripts/generate-ios-project.py
xcodebuild -project ios/Chatty.xcodeproj -scheme Chatty \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath .tools/ios-device-derived-data \
  -archivePath .tools/ios-testflight/0.1.0-2/Chatty.xcarchive \
  DEVELOPMENT_TEAM=9247PC9936 CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates -skipPackageUpdates archive
```

`CURRENT_PROJECT_VERSION` is now `2` in `scripts/generate-ios-project.py`. Change that source and regenerate if App Store Connect requires a later number. Avoid overwriting previous archives; use a versioned archive path.

Open the archive in Xcode Organizer, choose **Distribute App → TestFlight Internal Only**. Xcode must be signed into the development team. The first CLI export returned `No Accounts` despite a signed-in GUI account; Organizer successfully uploaded the build. No API key or `asc` installation was required for this upload.

## Release resources

- `Chatty/Assets.xcassets/AppIcon.appiconset`: opaque 1024px icon, compiled by Xcode.
- `Config/PrivacyInfo.xcprivacy`: app-only user defaults (`CA92.1`), app-container file metadata (`C617.1`) and user-selected file metadata (`3B52.1`). Declares email, account ID, chat and attachment content for linked app functionality, with no tracking.
- Encryption: current code uses Apple system networking, Keychain, file protection and CryptoKit SHA-256. The App Store Connect questionnaire was saved as “None of the algorithms mentioned above” because the app uses Apple system facilities and does not implement its own encryption algorithms. No non-exempt-encryption declaration has been hardcoded; revisit the answer if crypto usage changes.

## Historical build 1 evidence (2026-09-06)

Archive log: `.tools/ios-testflight/archive.log`.
Xcode Organizer confirmed **Chatty 0.1.0 (1) uploaded**, followed by **Uploaded to Apple** at 09:55 on 2026-09-06.
Apple processing, test-group assignment and tester installation are separate checks from upload success.

## Historical build 1 distribution state (2026-09-06)

Apple completed processing. Build `ff358207-91f2-42db-aa16-8c3e2cff68de` is **Testing**, assigned to **Benjamin Internal** (`39737e9c-54bf-4189-a3dd-babe20439452`). Automatic distribution is disabled. The group contains the account holder as its sole internal tester. TestFlight reports 90 days remaining; installation on the phone has not been verified.

The build’s Chinese “What to Test” notes were saved in App Store Connect, including production-service scope and the recommended login/chat/attachment/offline checks.

Final browser verification: **1 Tester · 1 Build**, tester status **Invited**. The account holder can accept the invitation on iPhone and install from TestFlight.

## Physical-phone installation attempt (2026-09-06)

iPhone Mirroring showed the iPhone 15 Pro running iOS 26.6.1. TestFlight was already installed. The original invitation returned “revoked or invalid” in TestFlight. Reinvited the existing tester via App Store Connect and observed the new email at 10:14. Before the new invitation could be accepted, mirroring entered **Connection Paused** at 10:16. Chatty installation and launch remain unverified; resume mirroring before continuing.
