import 'package:flutter_test/flutter_test.dart';
import 'package:open_mail_launcher/open_mail_launcher.dart';
import 'package:open_mail_launcher/open_mail_launcher_method_channel.dart';
import 'package:open_mail_launcher/open_mail_launcher_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockOpenMailLauncherPlatform
    with MockPlatformInterfaceMixin
    implements OpenMailLauncherPlatform {
  @override
  Future<List<MailApp>> getMailApps() async {
    return [
      const MailApp(
        name: 'Gmail',
        id: 'com.google.android.gm',
        isDefault: true,
      ),
      const MailApp(
        name: 'Outlook',
        id: 'com.microsoft.office.outlook',
        isDefault: false,
      ),
    ];
  }

  @override
  Future<OpenMailAppResult> openMailApp({EmailContent? emailContent}) async {
    final apps = await getMailApps();
    if (apps.isEmpty) {
      return OpenMailAppResult.noApps();
    } else if (apps.length > 1) {
      return OpenMailAppResult.multiple(options: apps);
    } else {
      return OpenMailAppResult.success(options: apps);
    }
  }

  @override
  Future<bool> openSpecificMailApp({
    required String appId,
    EmailContent? emailContent,
  }) async {
    return appId.isNotEmpty;
  }

  @override
  Future<bool> composeEmail({required EmailContent emailContent}) async {
    return emailContent.to.isNotEmpty;
  }

  @override
  Future<bool> isMailAppAvailable() async {
    final apps = await getMailApps();
    return apps.isNotEmpty;
  }
}

void main() {
  final OpenMailLauncherPlatform initialPlatform =
      OpenMailLauncherPlatform.instance;

  test('$MethodChannelOpenMailLauncher is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelOpenMailLauncher>());
  });

  test('getMailApps returns list of mail apps', () async {
    OpenMailLauncherPlatform.instance = MockOpenMailLauncherPlatform();

    final apps = await OpenMailLauncher.getMailApps();
    expect(apps.length, 2);
    expect(apps[0].name, 'Gmail');
    expect(apps[0].isDefault, true);
    expect(apps[1].name, 'Outlook');
    expect(apps[1].isDefault, false);
  });

  test(
    'openMailApp returns multiple apps result when more than one app',
    () async {
      OpenMailLauncherPlatform.instance = MockOpenMailLauncherPlatform();

      final result = await OpenMailLauncher.openMailApp();
      expect(result.didOpen, false);
      expect(result.canOpen, true);
      expect(result.options.length, 2);
    },
  );

  test('openSpecificMailApp returns true for valid app', () async {
    OpenMailLauncherPlatform.instance = MockOpenMailLauncherPlatform();

    const mailApp = MailApp(name: 'Gmail', id: 'com.google.android.gm');
    final success = await OpenMailLauncher.openSpecificMailApp(
      mailApp: mailApp,
    );
    expect(success, true);
  });

  test('composeEmail returns true for valid email content', () async {
    OpenMailLauncherPlatform.instance = MockOpenMailLauncherPlatform();

    final emailContent = EmailContent(
      to: ['test@example.com'],
      subject: 'Test',
      body: 'Test email',
    );
    final success = await OpenMailLauncher.composeEmail(
      emailContent: emailContent,
    );
    expect(success, true);
  });

  test('isMailAppAvailable returns true when apps exist', () async {
    OpenMailLauncherPlatform.instance = MockOpenMailLauncherPlatform();

    final available = await OpenMailLauncher.isMailAppAvailable();
    expect(available, true);
  });

  test('EmailContent creates valid mailto URI', () {
    final emailContent = EmailContent(
      to: ['test@example.com', 'test2@example.com'],
      cc: ['cc@example.com'],
      bcc: ['bcc@example.com'],
      subject: 'Test Subject',
      body: 'Test Body with spaces',
    );

    final uri = emailContent.toMailtoUri();
    expect(uri.startsWith('mailto:test@example.com,test2@example.com'), true);
    expect(uri.contains('cc=cc@example.com'), true);
    expect(uri.contains('bcc=bcc@example.com'), true);
    expect(uri.contains('subject=Test%20Subject'), true);
    expect(uri.contains('body=Test%20Body%20with%20spaces'), true);
  });

  test('MailApp equality works correctly', () {
    const app1 = MailApp(name: 'Gmail', id: 'com.google.android.gm');
    const app2 = MailApp(name: 'Gmail', id: 'com.google.android.gm');
    const app3 = MailApp(name: 'Outlook', id: 'com.microsoft.office.outlook');

    expect(app1, equals(app2));
    expect(app1, isNot(equals(app3)));
  });

  test('OpenMailAppResult factories work correctly', () {
    final successResult = OpenMailAppResult.success();
    expect(successResult.didOpen, true);
    expect(successResult.canOpen, true);

    final multipleResult = OpenMailAppResult.multiple(
      options: [
        const MailApp(name: 'App1', id: 'app1'),
        const MailApp(name: 'App2', id: 'app2'),
      ],
    );
    expect(multipleResult.didOpen, false);
    expect(multipleResult.canOpen, true);
    expect(multipleResult.hasMultipleOptions, true);

    final noAppsResult = OpenMailAppResult.noApps();
    expect(noAppsResult.didOpen, false);
    expect(noAppsResult.canOpen, false);

    final errorResult = OpenMailAppResult.error('Test error');
    expect(errorResult.didOpen, false);
    expect(errorResult.canOpen, false);
    expect(errorResult.error, 'Test error');
  });
}
