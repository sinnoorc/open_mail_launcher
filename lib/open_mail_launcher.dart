library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'open_mail_launcher_platform_interface.dart';
import 'src/models/email_content.dart';
import 'src/models/mail_app.dart';
import 'src/models/open_mail_app_result.dart';

// Export models
export 'src/models/email_content.dart';
export 'src/models/mail_app.dart';
export 'src/models/open_mail_app_result.dart';

/// Entry point for discovering and launching email apps on Android and iOS.
///
/// All methods are static; the class cannot be instantiated.
///
/// ## Platform notes
///
/// **iOS** detects apps by probing a fixed list of known URL schemes with
/// `canOpenURL`. Each scheme the plugin probes **must** be listed in the
/// consuming app's `Info.plist` under `LSApplicationQueriesSchemes`, or
/// detection silently fails in release builds. See the README for the full
/// list.
///
/// **Android** uses `PackageManager.queryIntentActivities` with an
/// `ACTION_SENDTO mailto:` intent. The required `<queries>` block is
/// contributed automatically by the plugin's `AndroidManifest.xml` via
/// manifest merging — no consumer setup is needed on Android.
class OpenMailLauncher {
  OpenMailLauncher._();

  /// Gets a list of all available email apps on the device
  static Future<List<MailApp>> getMailApps() {
    return OpenMailLauncherPlatform.instance.getMailApps();
  }

  /// Opens the default mail app or returns available options if multiple exist
  ///
  /// If [emailContent] is provided, a compose window is opened with the
  /// content pre-filled. If omitted, the mail app itself is opened (its
  /// inbox / main screen), not a compose window — except iOS's synthesized
  /// "Default Mail App" entry, which iOS can only open via `mailto:`.
  static Future<OpenMailAppResult> openMailApp({EmailContent? emailContent}) {
    return OpenMailLauncherPlatform.instance.openMailApp(
      emailContent: emailContent,
    );
  }

  /// Opens a specific mail app by its ID
  ///
  /// If [emailContent] is provided, a compose window is opened with the
  /// content pre-filled; otherwise the app itself is opened — except iOS's
  /// synthesized "Default Mail App" entry (`mailto:`), which iOS can only
  /// open via a compose window.
  ///
  /// Returns true if the app was successfully opened
  static Future<bool> openSpecificMailApp({
    required MailApp mailApp,
    EmailContent? emailContent,
  }) {
    return OpenMailLauncherPlatform.instance.openSpecificMailApp(
      appId: mailApp.id,
      emailContent: emailContent,
    );
  }

  /// Composes an email in the default mail app
  ///
  /// Returns true if the compose window was successfully opened
  static Future<bool> composeEmail({required EmailContent emailContent}) {
    return OpenMailLauncherPlatform.instance.composeEmail(
      emailContent: emailContent,
    );
  }

  /// Checks if any mail app is available on the device
  static Future<bool> isMailAppAvailable() {
    return OpenMailLauncherPlatform.instance.isMailAppAvailable();
  }

  /// Shows a dialog to pick a mail app from available options
  ///
  /// This is a convenience method for when multiple mail apps are available
  static Future<MailApp?> showMailAppPicker({
    required BuildContext context,
    required List<MailApp> mailApps,
    String? title,
    String? cancelText,
  }) async {
    if (mailApps.isEmpty) return null;
    if (mailApps.length == 1) return mailApps.first;

    return showDialog<MailApp>(
      context: context,
      builder: (BuildContext context) {
        return MailAppPickerDialog(
          mailApps: mailApps,
          title: title,
          cancelText: cancelText,
        );
      },
    );
  }
}

/// A Material [AlertDialog] that lets the user pick one of [mailApps].
///
/// Returned from [OpenMailLauncher.showMailAppPicker] via [Navigator.pop].
/// Tapping outside the dialog or tapping cancel returns `null`.
class MailAppPickerDialog extends StatelessWidget {
  /// The list of mail apps to display. The dialog renders one [ListTile] per
  /// entry. App icons are shown when [MailApp.icon] is a data URI (Android
  /// only); otherwise a generic mail icon is used.
  final List<MailApp> mailApps;

  /// Dialog title shown above the list. Defaults to `'Choose Mail App'`.
  final String? title;

  /// Label of the cancel button. Defaults to `'Cancel'`.
  final String? cancelText;

  /// Creates a [MailAppPickerDialog].
  ///
  /// [mailApps] must not be empty. Use [OpenMailLauncher.showMailAppPicker]
  /// for the typical flow, which short-circuits when zero or one app is
  /// available.
  const MailAppPickerDialog({
    super.key,
    required this.mailApps,
    this.title,
    this.cancelText,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title ?? 'Choose Mail App'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: mailApps.map((mailApp) {
            final iconBytes = _decodeMailAppIcon(mailApp.icon);
            return ListTile(
              leading: iconBytes != null
                  ? Image.memory(
                      iconBytes,
                      width: 32,
                      height: 32,
                      errorBuilder: (_, _, _) => const Icon(Icons.email),
                    )
                  : const Icon(Icons.email),
              title: Text(mailApp.name),
              subtitle: mailApp.isDefault ? const Text('Default') : null,
              onTap: () => Navigator.of(context).pop(mailApp),
            );
          }).toList(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(cancelText ?? 'Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

Uint8List? _decodeMailAppIcon(String? icon) {
  if (icon == null || icon.isEmpty) {
    return null;
  }

  try {
    return Uri.tryParse(icon)?.data?.contentAsBytes();
  } on FormatException {
    return null;
  }
}
