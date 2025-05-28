import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'open_mail_launcher_platform_interface.dart';
import 'src/models/email_content.dart';
import 'src/models/mail_app.dart';
import 'src/models/open_mail_app_result.dart';

/// An implementation of [OpenMailLauncherPlatform] that uses method channels.
class MethodChannelOpenMailLauncher extends OpenMailLauncherPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('open_mail_launcher');

  @override
  Future<List<MailApp>> getMailApps() async {
    try {
      final List<dynamic>? result = await methodChannel.invokeMethod(
        'getMailApps',
      );
      if (result == null) return [];

      return result
          .cast<Map<dynamic, dynamic>>()
          .map((map) => MailApp.fromMap(Map<String, dynamic>.from(map)))
          .toList();
    } on PlatformException catch (e) {
      debugPrint('Error getting mail apps: ${e.message}');
      return [];
    }
  }

  @override
  Future<OpenMailAppResult> openMailApp({EmailContent? emailContent}) async {
    try {
      final Map<dynamic, dynamic>? result = await methodChannel.invokeMethod(
        'openMailApp',
        emailContent?.toMap(),
      );

      if (result == null) {
        return OpenMailAppResult.error('Failed to open mail app');
      }

      final Map<String, dynamic> resultMap = Map<String, dynamic>.from(result);
      final bool didOpen = resultMap['didOpen'] as bool? ?? false;
      final bool canOpen = resultMap['canOpen'] as bool? ?? false;
      final List<dynamic> optionsList =
          resultMap['options'] as List<dynamic>? ?? [];

      final List<MailApp> options = optionsList
          .cast<Map<dynamic, dynamic>>()
          .map((map) => MailApp.fromMap(Map<String, dynamic>.from(map)))
          .toList();

      if (didOpen) {
        return OpenMailAppResult.success(options: options);
      } else if (canOpen && options.isNotEmpty) {
        return OpenMailAppResult.multiple(options: options);
      } else {
        return OpenMailAppResult.noApps();
      }
    } on PlatformException catch (e) {
      return OpenMailAppResult.error(e.message ?? 'Unknown error');
    }
  }

  @override
  Future<bool> openSpecificMailApp({
    required String appId,
    EmailContent? emailContent,
  }) async {
    try {
      final bool? result = await methodChannel.invokeMethod(
        'openSpecificMailApp',
        {'appId': appId, ...?emailContent?.toMap()},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error opening specific mail app: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> composeEmail({required EmailContent emailContent}) async {
    try {
      final bool? result = await methodChannel.invokeMethod(
        'composeEmail',
        emailContent.toMap(),
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error composing email: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> isMailAppAvailable() async {
    try {
      final bool? result = await methodChannel.invokeMethod(
        'isMailAppAvailable',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking mail app availability: ${e.message}');
      return false;
    }
  }
}
