import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'open_mail_launcher_method_channel.dart';
import 'src/models/email_content.dart';
import 'src/models/mail_app.dart';
import 'src/models/open_mail_app_result.dart';

abstract class OpenMailLauncherPlatform extends PlatformInterface {
  /// Constructs a OpenMailLauncherPlatform.
  OpenMailLauncherPlatform() : super(token: _token);

  static final Object _token = Object();

  static OpenMailLauncherPlatform _instance = MethodChannelOpenMailLauncher();

  /// The default instance of [OpenMailLauncherPlatform] to use.
  ///
  /// Defaults to [MethodChannelOpenMailLauncher].
  static OpenMailLauncherPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OpenMailLauncherPlatform] when
  /// they register themselves.
  static set instance(OpenMailLauncherPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Gets the list of available email apps on the device
  Future<List<MailApp>> getMailApps() {
    throw UnimplementedError('getMailApps() has not been implemented.');
  }

  /// Opens the default email app or shows picker if multiple apps exist
  Future<OpenMailAppResult> openMailApp({EmailContent? emailContent}) {
    throw UnimplementedError('openMailApp() has not been implemented.');
  }

  /// Opens a specific email app by its ID
  Future<bool> openSpecificMailApp({
    required String appId,
    EmailContent? emailContent,
  }) {
    throw UnimplementedError('openSpecificMailApp() has not been implemented.');
  }

  /// Composes an email in the default mail app
  Future<bool> composeEmail({required EmailContent emailContent}) {
    throw UnimplementedError('composeEmail() has not been implemented.');
  }

  /// Checks if any mail app is available
  Future<bool> isMailAppAvailable() {
    throw UnimplementedError('isMailAppAvailable() has not been implemented.');
  }
}
