# Open Mail Launcher Example

Demonstrates the public `open_mail_launcher` API:

- checking whether a mail app is available
- listing installed mail apps
- composing email content
- opening the default app or a selected app
- handling no-app and multiple-app results

## Run

```bash
flutter pub get
flutter run
```

On iOS, `Runner/Info.plist` includes the `LSApplicationQueriesSchemes` list
used by the plugin demo. On Android, package visibility queries are provided by
the plugin manifest.

Android attachment examples should use readable `content://` URIs, not plain
file paths.
