# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## What this is

A Flutter **federated plugin** (`open_mail_launcher`) that discovers and launches email apps on Android and iOS, with optional pre-filled `EmailContent`. Published to pub.dev; consumed via `package:open_mail_launcher/open_mail_launcher.dart`.

Min versions: Dart `^3.12.0`, Flutter `>=3.44.0`, Android `minSdk 24` / `compileSdk 36`, iOS `13.0+`. Android toolchain: AGP 9.0.1, Gradle 9.1.0 (example wrapper), Kotlin 2.4.0 — do not bump Gradle past Flutter's max supported version (9.3.1 as of Flutter 3.44; Gradle 9.6+ breaks AGP).

## Common commands

Plugin root (`/`):

```bash
flutter pub get
dart format .                                  # CI runs: dart format --output=none --set-exit-if-changed .
flutter analyze                                # must be clean — CI fails on warnings
flutter test                                   # unit + widget tests in test/
flutter test --coverage                        # produces coverage/lcov.info (CI uploads to Codecov)
flutter test test/open_mail_launcher_test.dart --plain-name "EmailContent creates valid mailto URI"
```

Example app (`example/`) — required for any native-side change, since unit tests can't exercise platform code:

```bash
cd example && flutter pub get
cd example && flutter run                                  # run on a connected device/emulator
cd example && flutter test integration_test/               # runs plugin_integration_test.dart on-device
```

CI (`.github/workflows/main.yml`) runs `dart format` check → `flutter analyze` → `flutter test --coverage` on every push/PR to `main`. All three must pass.

## Architecture

Standard federated-plugin three-layer split. When adding a new method, all four layers must change in lockstep:

1. **Public API** — `lib/open_mail_launcher.dart`
   `OpenMailLauncher` (static facade) + `MailAppPickerDialog` (the Material picker shown when iOS returns multiple options). Also re-exports the three models from `lib/src/models/`.

2. **Platform interface** — `lib/open_mail_launcher_platform_interface.dart`
   Abstract `OpenMailLauncherPlatform` extending `PlatformInterface` (with the `_token` pattern). New methods go here as `throw UnimplementedError(...)`.

3. **Default method-channel impl** — `lib/open_mail_launcher_method_channel.dart`
   `MethodChannelOpenMailLauncher` on `MethodChannel('open_mail_launcher')`. Wraps `PlatformException` into safe defaults (empty list / `false` / `OpenMailAppResult.error`) — callers never see a thrown channel error.

4. **Native implementations**
   - Android: `android/src/main/kotlin/com/sinnoor/open_mail_launcher/OpenMailLauncherPlugin.kt`
   - iOS: `ios/open_mail_launcher/Sources/open_mail_launcher/OpenMailLauncherPlugin.swift` (see "iOS source layout" below)

### Method channel contract

Channel: `open_mail_launcher`. Methods and argument shapes:

| Method | Args | Returns |
|---|---|---|
| `getMailApps` | none | `List<Map>` with `name`, `id`, `icon` (nullable, `data:image/png;base64,...` on Android only), `isDefault` |
| `openMailApp` | `EmailContent.toMap()` or `null` | `Map` with `didOpen`, `canOpen`, `options: List<Map>` |
| `openSpecificMailApp` | `{appId: String, emailContent: EmailContent.toMap()?}` | `bool` |
| `composeEmail` | `EmailContent.toMap()` | `bool` |
| `isMailAppAvailable` | none | `bool` |

Quirk: a `null` email content means "open the mail app" (inbox / main screen), NOT "compose an empty email". Both native sides branch on this: Android uses `getLaunchIntentForPackage` / the `CATEGORY_APP_EMAIL` selector, iOS opens the app's bare URL scheme (except the synthesized `mailto:` default entry, which composes — no iOS API exists to open the default mail app). The `mailto:` intent is still used for app *discovery* on Android in all cases.

### Models (`lib/src/models/`)

- `EmailContent` — `to/cc/bcc` lists, `subject`, `body`, `isHtml`, `attachments`. Owns `toMap`/`fromMap`/`copyWith`/`toMailtoUri` (Dart-side mailto generator used in tests; native sides reimplement their own URI builders).
- `MailApp` — `name`, `id` (Android package name OR iOS URL scheme), `icon`, `isDefault`. Has value-equality.
- `OpenMailAppResult` — named factories `success`/`multiple`/`noApps`/`error`. `hasMultipleOptions` is `!didOpen && canOpen && options.length > 1` — single-app `multiple` returns `false` here.

### Platform behavior differences (load-bearing)

- **Android** discovers apps via `PackageManager.queryIntentActivities(ACTION_SENDTO mailto:)`. When >1 app, returns `didOpen=true` after launching the system chooser — Dart never sees the picker case. Attachments switch the intent to `ACTION_SEND_MULTIPLE` with `EXTRA_STREAM`. Icons are PNG-encoded base64 data URIs.
- **iOS** has no equivalent enumeration API; uses a **hardcoded `knownMailApps` list** of `(name, scheme)` pairs in `OpenMailLauncherPlugin.swift` and probes each with `canOpenURL`. When >1 app, returns `didOpen=false, canOpen=true` and lets Dart show `MailAppPickerDialog`. Icons are always `nil`. No attachment support.
- **iOS consumer requirement**: every URL scheme in `knownMailApps` must be listed in the consuming app's `Info.plist` under `LSApplicationQueriesSchemes`, or `canOpenURL` returns `false` silently. Adding a new mail app means updating both `knownMailApps` AND the example app's `Info.plist` AND documenting it in `README.md`.
- **Per-app URL builders** for Gmail / Outlook / Spark live in `createAppSpecificURL` (iOS only) — other schemes fall back to a `mailto:` string with the prefix swapped. New first-class iOS app support = add a `create<Name>URL` and branch in `createAppSpecificURL`.

### iOS source layout

Single-tree layout under `ios/open_mail_launcher/Sources/open_mail_launcher/`. Both `Package.swift` (SPM) and `open_mail_launcher.podspec` (`s.source_files = 'open_mail_launcher/Sources/open_mail_launcher/**/*.{h,m,swift}'`) reference this path. The privacy manifest sits next to the source as `PrivacyInfo.xcprivacy` and is bundled via `resource_bundles` in the podspec and `.process("PrivacyInfo.xcprivacy")` in `Package.swift`.

## Conventions

- Lints come from `flutter_lints` via `analysis_options.yaml` — no custom rules. Don't add `// ignore:` without cause; CI runs `flutter analyze` with no warning tolerance.
- Native errors must never bubble as `PlatformException` into Dart callers — wrap and return a typed result (`OpenMailAppResult.error`, `false`, or `[]`). The method-channel layer already does this; preserve the pattern.
- Bump `version:` in `pubspec.yaml` AND add a `## x.y.z` section to `CHANGELOG.md` for any release-worthy change (pub.dev validates this).
