library;

import 'package:flutter/material.dart';

import 'open_mail_launcher_platform_interface.dart';
import 'src/models/email_content.dart';
import 'src/models/mail_app.dart';
import 'src/models/open_mail_app_result.dart';

// Export models
export 'src/models/email_content.dart';
export 'src/models/mail_app.dart';
export 'src/models/open_mail_app_result.dart';

/// Main class for interacting with email apps on the device
class OpenMailLauncher {
  OpenMailLauncher._();

  /// Gets a list of all available email apps on the device
  static Future<List<MailApp>> getMailApps() {
    return OpenMailLauncherPlatform.instance.getMailApps();
  }

  /// Opens the default mail app or returns available options if multiple exist
  ///
  /// If [emailContent] is provided, it will pre-fill the compose window
  static Future<OpenMailAppResult> openMailApp({EmailContent? emailContent}) {
    return OpenMailLauncherPlatform.instance.openMailApp(
      emailContent: emailContent,
    );
  }

  /// Opens a specific mail app by its ID
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

/// A dialog widget for selecting a mail app
class MailAppPickerDialog extends StatelessWidget {
  final List<MailApp> mailApps;
  final String? title;
  final String? cancelText;

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
            return ListTile(
              leading: mailApp.icon != null
                  ? Image.memory(
                      Uri.parse(mailApp.icon!).data!.contentAsBytes(),
                      width: 32,
                      height: 32,
                      errorBuilder: (_, __, ___) => const Icon(Icons.email),
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
