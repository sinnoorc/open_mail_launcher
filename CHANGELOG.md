## 0.3.0

Toolchain currency release plus one behavior fix. No public Dart API
signatures change, but calling `openMailApp()` / `openSpecificMailApp()`
without `emailContent` now behaves differently — see **Fixed**.

### Fixed

- **Android & iOS:** `openMailApp()` and `openSpecificMailApp()` called
  without `emailContent` now open the mail app itself (inbox / main
  screen) instead of a blank compose window
  ([#18](https://github.com/sinnoorc/open_mail_launcher/issues/18)).
  Android launches the app's launcher intent (single app) or the system
  `CATEGORY_APP_EMAIL` selector (multiple apps); iOS opens the app's
  bare URL scheme. Exception: iOS's synthesized "Default Mail App"
  entry can only be opened via `mailto:`, which still composes — iOS
  has no "open default mail app" API. Passing `emailContent` composes
  exactly as before.

### Changed

- **Flutter SDK floor:** `>=3.32.0` → `>=3.44.0`; **Dart:** `^3.8.0` →
  `^3.12.0`.
- **Android toolchain:** AGP 8.11.1 → 9.0.1, Gradle wrapper (example)
  8.14 → 9.1.0, `compileSdk` 35 → 36 — the Flutter 3.44 template
  defaults. Note: Gradle 9.6+ is incompatible with AGP 8.x/9.0.x
  (removed internal APIs); Flutter's max supported Gradle is currently
  9.3.1.
- **Android `minSdk`:** 21 → 24. Flutter 3.44 itself dropped support
  for API < 24, so this excludes no one who can run the required
  Flutter version.
- **Kotlin:** 2.2.20 → 2.4.0 (Dependabot
  [#13](https://github.com/sinnoorc/open_mail_launcher/pull/13),
  [#14](https://github.com/sinnoorc/open_mail_launcher/pull/14)).

## 0.2.0

Correctness, currency, and pub-score release. No public Dart API
signatures change, but two iOS picker behaviors observably change —
see **Changed** below.

### Added

- **iOS:** Synthesized "Default Mail App" entry at the head of
  `getMailApps()` results. Its `id` is `mailto:` and `isDefault` is
  `true`; opening it routes through the user's iOS-level default mail
  handler (Settings > Default Apps > Mail). Consumers can filter for
  `isDefault: true` to respect the user's choice without showing a
  picker.
- **iOS:** First-class compose-URL builder for Yahoo Mail
  (`ymail://mail/compose?to=…&cc=…&bcc=…&subject=…&body=…`).
- **Models:** `==`, `hashCode`, and `@immutable` on `EmailContent`,
  `MailApp`, and `OpenMailAppResult`.
- **Lints:** Stricter analysis — `strict-casts`, `strict-inference`,
  `strict-raw-types`, plus `avoid_dynamic_calls`, `unawaited_futures`,
  `prefer_const_*`, `require_trailing_commas`, `prefer_final_locals`,
  `cancel_subscriptions`.
- **CI:** Matrix of three jobs — Dart (format, analyze, test, `pana`
  informational), Android (example APK + plugin Kotlin tests via
  `./gradlew open_mail_launcher:testDebugUnitTest`), iOS (`pod lib
  lint` + example simulator build).
- **Repo hygiene:** `.github/dependabot.yml`, structured issue forms
  (bug + feature), and a PR template.
- **AI assistant docs:** `CLAUDE.md` and `AGENTS.md` describing the
  federated-plugin layout, method-channel envelope quirks, and iOS
  scheme list.

### Changed

- **Flutter SDK floor:** `>=3.3.0` → `>=3.32.0`. The previous floor was
  below the actual transitive resolution floor (`>=3.18.0` per
  `pubspec.lock`), so users on 3.3 could never install. 3.32 also lets
  the plugin drop iOS 12 cleanly.
- **iOS deployment target:** 12.0 → 13.0 in podspec, `Package.swift`,
  and the example's `Runner.xcodeproj`. Flutter dropped iOS 12 long
  ago; the previous declaration was advisory at best.
- **Android tooling:** plugin AGP `8.9.0` → `8.11.1`; example AGP
  `8.7.3` → `8.11.1`, Kotlin `2.1.0` → `2.2.20`, and Gradle `8.12`
  → `8.14`. Stays on the 8.x line so consumers avoid AGP 9 churn.
- **Android Kotlin integration:** migrated plugin and example away from
  explicitly applying the Kotlin Gradle Plugin where Flutter Built-in Kotlin
  supplies it.
- **Method-channel envelope (internal):** `openSpecificMailApp` now
  sends `{'appId': …, 'emailContent': {…}?}` instead of flattening
  `appId` into the email-content map. Removes a silent-shadowing risk
  if `EmailContent` ever gained an `appId` field. Public Dart API is
  unchanged.
- **README iOS setup:** Replaced the 5-scheme placeholder with the
  full 16-scheme list the plugin actually probes plus a callout that
  omitted schemes silently fail detection in release builds.
- **iOS picker — observable behavior change:** When multiple mail apps
  are detected, the picker now leads with a "Default Mail App" entry
  that routes via the user's chosen mailto handler. Previously the
  hardcoded "Mail" entry (id `mailto:`) sat at the top with
  `isDefault: true` regardless of what the user had actually set.
- **iOS Apple Mail entry — observable behavior change:** Apple Mail
  now appears only when `canOpenURL("message://")` succeeds (i.e.,
  Mail.app is actually installed). Its `id` is `message://` (was
  `mailto:`) and `isDefault` is `false` (was `true`).
- **Android attachment intent:** MIME `*/*` → `message/rfc822` and
  discovery now resolves the actual attachment intent. The documented
  attachment contract is Android `content://` URIs.

### Fixed

- **iOS:** `getMailApps()` no longer hardcodes Apple Mail as always
  present. Since iOS 10 users can delete Mail.app; previously the
  plugin returned a phantom Mail entry on those devices, and
  `isMailAppAvailable()` would lie. (C-1)
- **iOS:** The Apple Mail entry's `id` no longer conflates "Apple
  Mail.app" with "the user's chosen default mailto handler". Picker
  selection now reliably opens the named app. (C-2)
- **Android:** `content://` attachment URIs now carry
  `FLAG_GRANT_READ_URI_PERMISSION` plus `ClipData`, so receiving mail apps
  can actually read them instead of hitting `SecurityException`. (C-13)

### Removed

- **iOS scheme list:** Newton (`newton://`, mail service shut down July
  2024), Twobird (`twobird://`, shut down 2022 by Ginger Labs),
  Dispatch (`x-dispatch://`, no App Store updates since ~2016), and
  TypeApp (`typeapp://`, redundant alias of BlueMail with the same
  bundle ID). Their entries were also removed from the example app's
  `LSApplicationQueriesSchemes` and the README setup snippet.
- **Legacy iOS trees:** `ios/Classes/`, `ios/Resources/`, and
  `ios/Assets/.gitkeep`. These were byte-identical duplicates of files
  in the canonical SPM tree (`ios/open_mail_launcher/Sources/…`) and
  were unreferenced by the podspec or `Package.swift`.

### Maintenance

- Replaced stale Android Kotlin unit test (tested a `getPlatformVersion`
  method that doesn't exist) with a dispatcher-correctness test.
- Replaced stale example widget test (searched for a "Running on:"
  widget that doesn't exist) with `HomePage` smoke tests.
- Removed unused `import MessageUI` from the iOS plugin.
- Added `FlutterFramework` SPM dependency to `Package.swift` for Flutter
  3.44+ SPM plugin readiness.
- Narrowed the Android `<queries>` block: removed the unused
  `ACTION_SEND` intent, narrowed `SEND_MULTIPLE` MIME from `*/*` to
  `message/rfc822` to match what the plugin actually sends.

## 0.1.2

### Maintenance

- Upgraded `flutter_lints` to 6.0.0
- Fixed lints related to unused parameters

## 0.1.1

### Bug Fixes

- **iOS**: Fixed issue with Swift Package Manager support

## 0.1.0

### Swift Package Manager Support Added

- **iOS Swift Package Manager**: Added complete Swift Package Manager support for iOS platform
  - Added `ios/open_mail_launcher/Package.swift` with iOS 12.0+ support
  - Restructured iOS files to follow SPM conventions
  - Maintained backward compatibility with CocoaPods
  - Updated podspec to point to new SPM structure
  - Added proper resource handling for PrivacyInfo.xcprivacy
- **Enhanced Compatibility**: Plugin now works with both CocoaPods and Swift Package Manager
- **Future-Ready**: Prepared for Flutter's transition to Swift Package Manager as default

### Technical Changes

- Moved iOS source files to `ios/open_mail_launcher/Sources/open_mail_launcher/`

- Updated resource bundling for SPM compatibility
- Added proper Swift Package Manager product naming
- Maintained all existing functionality and API

## 0.0.1

### Initial Release

- **Email App Discovery**: Query for available email applications on both Android and iOS
- **Smart App Opening**: Automatically handle single vs multiple email apps with native choosers
- **Email Composition**: Pre-fill emails with recipients (To, CC, BCC), subject, and body content
- **Cross-Platform Support**: Full Android and iOS implementation with platform-specific optimizations
- **Modern Architecture**: Platform interface pattern with proper error handling and data models
- **Attachment Support**: File attachments on Android platform
- **Built-in UI**: Mail app picker dialog for multiple app selection
- **Comprehensive API**:
  - `getMailApps()` - Get list of available email apps
  - `openMailApp()` - Open email app with smart handling
  - `openSpecificMailApp()` - Open a specific email application
  - `composeEmail()` - Compose email with pre-filled content
  - `isMailAppAvailable()` - Check if any email app is available
  - `showMailAppPicker()` - Show picker dialog for app selection

### Platform Features

**Android:**

- Uses PackageManager for email app discovery
- Supports Intent.ACTION_SENDTO and Intent.ACTION_SEND_MULTIPLE
- Automatic email intent queries for Android 11+ compatibility
- App icon extraction as base64 encoded strings
- Default email app detection
- File attachment support

**iOS:**

- URL scheme-based app detection for known email applications
- Support for popular email apps (Gmail, Outlook, Spark, etc.)
- Custom URL generation for different email clients
- Fallback to default Mail app
- Proper URL encoding for email content

### Models

- `MailApp` - Represents email applications with name, ID, icon, and default status

- `EmailContent` - Comprehensive email data model with mailto URI generation
- `OpenMailAppResult` - Result wrapper for app opening operations with success/error states

### Development

- Comprehensive test coverage with unit tests and mock implementations

- Example app demonstrating all features
- Complete documentation with usage examples
- Flutter 3.3.0+ compatibility
- Modern Dart null safety support
