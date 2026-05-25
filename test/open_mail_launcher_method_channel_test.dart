import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_mail_launcher/open_mail_launcher.dart';
import 'package:open_mail_launcher/open_mail_launcher_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelOpenMailLauncher platform =
      MethodChannelOpenMailLauncher();
  const MethodChannel channel = MethodChannel('open_mail_launcher');
  final methodCalls = <MethodCall>[];

  setUp(() {
    methodCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          switch (methodCall.method) {
            case 'getMailApps':
              return [
                {
                  'name': 'Gmail',
                  'id': 'com.google.android.gm',
                  'icon': null,
                  'isDefault': true,
                },
                {
                  'name': 'Outlook',
                  'id': 'com.microsoft.office.outlook',
                  'icon': null,
                  'isDefault': false,
                },
              ];
            case 'openMailApp':
              return {
                'didOpen': false,
                'canOpen': true,
                'options': [
                  {
                    'name': 'Gmail',
                    'id': 'com.google.android.gm',
                    'icon': null,
                    'isDefault': true,
                  },
                  {
                    'name': 'Outlook',
                    'id': 'com.microsoft.office.outlook',
                    'icon': null,
                    'isDefault': false,
                  },
                ],
              };
            case 'openSpecificMailApp':
              return true;
            case 'composeEmail':
              return true;
            case 'isMailAppAvailable':
              return true;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getMailApps', () async {
    final apps = await platform.getMailApps();
    expect(apps.length, 2);
    expect(apps[0].name, 'Gmail');
    expect(apps[0].isDefault, true);
  });

  test('openMailApp', () async {
    final result = await platform.openMailApp();
    expect(result.didOpen, false);
    expect(result.canOpen, true);
    expect(result.options.length, 2);
  });

  test('openSpecificMailApp sends nested emailContent envelope', () async {
    const emailContent = EmailContent(
      to: ['test@example.com'],
      subject: 'Test',
      body: 'Test email',
    );

    final success = await platform.openSpecificMailApp(
      appId: 'test.app',
      emailContent: emailContent,
    );

    expect(success, true);

    final call = methodCalls.singleWhere(
      (methodCall) => methodCall.method == 'openSpecificMailApp',
    );
    final arguments = call.arguments as Map<Object?, Object?>;
    expect(arguments['appId'], 'test.app');
    expect(arguments['emailContent'], emailContent.toMap());
  });

  test('composeEmail', () async {
    final success = await platform.composeEmail(
      emailContent: const EmailContent(
        to: ['test@example.com'],
        subject: 'Test',
        body: 'Test email',
      ),
    );
    expect(success, true);
  });

  test('isMailAppAvailable', () async {
    final available = await platform.isMailAppAvailable();
    expect(available, true);
  });
}
