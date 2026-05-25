# Audit Upgrade Todo

## Checklist

- [x] Preserve dirty detached worktree in a named safety stash.
- [x] Create `codex/audit-upgrade-open-mail-launcher` from fresh `origin/main`.
- [x] Fix release metadata and documentation drift.
- [x] Fix iOS compose URL builders.
- [x] Fix Android attachment intent handling.
- [x] Harden Dart models, picker icon decoding, and platform-channel tests.
- [x] Commit Flutter 3.44 example platform migrations.
- [x] Polish CI tooling versions.
- [x] Run verification commands and record results.

## Review

- `dart format --output=none --set-exit-if-changed .`: pass.
- Root `flutter analyze`: pass.
- Root `flutter test`: pass.
- `flutter pub publish --dry-run`: pass, 0 warnings.
- Example `flutter analyze`: pass.
- Example `flutter test`: pass.
- Example Android debug APK build: pass.
- Example iOS simulator build: pass.
- `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew open_mail_launcher:testDebugUnitTest --stacktrace`: pass.
- `pod lib lint ios/open_mail_launcher.podspec --allow-warnings`: pass with the expected local-path `s.source` warning.
