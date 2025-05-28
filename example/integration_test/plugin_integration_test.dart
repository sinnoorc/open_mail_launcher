// This is a comprehensive Flutter integration test for the open_mail_launcher plugin.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:open_mail_launcher/open_mail_launcher.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('OpenMailLauncher Integration Tests', () {
    testWidgets('isMailAppAvailable should return boolean', (
      WidgetTester tester,
    ) async {
      final bool isAvailable = await OpenMailLauncher.isMailAppAvailable();
      expect(isAvailable, isA<bool>());
    });

    testWidgets('getMailApps should return list of mail apps', (
      WidgetTester tester,
    ) async {
      final List<MailApp> apps = await OpenMailLauncher.getMailApps();
      expect(apps, isA<List<MailApp>>());

      // If apps are available, test their properties
      if (apps.isNotEmpty) {
        for (final app in apps) {
          expect(app.name, isA<String>());
          expect(app.name.isNotEmpty, true);
          expect(app.id, isA<String>());
          expect(app.id.isNotEmpty, true);
          expect(app.isDefault, isA<bool>());
        }

        // There should be at most one default app
        final defaultApps = apps.where((app) => app.isDefault).toList();
        expect(defaultApps.length, lessThanOrEqualTo(1));
      }
    });

    testWidgets('openMailApp should return valid result', (
      WidgetTester tester,
    ) async {
      final OpenMailAppResult result = await OpenMailLauncher.openMailApp();
      expect(result, isA<OpenMailAppResult>());
      expect(result.didOpen, isA<bool>());
      expect(result.canOpen, isA<bool>());
      expect(result.options, isA<List<MailApp>>());

      // If canOpen is true, there should be some options
      if (result.canOpen) {
        expect(result.options.isNotEmpty, true);
      }
    });

    testWidgets('openMailApp with email content should work', (
      WidgetTester tester,
    ) async {
      final emailContent = EmailContent(
        to: ['test@example.com'],
        subject: 'Integration Test Email',
        body: 'This is a test email from the integration test.',
      );

      final OpenMailAppResult result = await OpenMailLauncher.openMailApp(
        emailContent: emailContent,
      );

      expect(result, isA<OpenMailAppResult>());
      expect(result.didOpen, isA<bool>());
      expect(result.canOpen, isA<bool>());
    });

    testWidgets('composeEmail should return boolean result', (
      WidgetTester tester,
    ) async {
      final emailContent = EmailContent(
        to: ['test@example.com'],
        cc: ['cc@example.com'],
        bcc: ['bcc@example.com'],
        subject: 'Integration Test - Compose Email',
        body: 'This is a compose email test from the integration test.',
      );

      final bool result = await OpenMailLauncher.composeEmail(
        emailContent: emailContent,
      );

      expect(result, isA<bool>());
    });

    testWidgets('openSpecificMailApp should handle invalid app gracefully', (
      WidgetTester tester,
    ) async {
      const invalidApp = MailApp(
        name: 'Invalid App',
        id: 'com.invalid.app.that.does.not.exist',
        isDefault: false,
      );

      final bool result = await OpenMailLauncher.openSpecificMailApp(
        mailApp: invalidApp,
      );

      expect(result, isA<bool>());
      // Should return false for invalid app
      expect(result, false);
    });

    testWidgets('openSpecificMailApp with valid app should work', (
      WidgetTester tester,
    ) async {
      // First get available apps
      final List<MailApp> apps = await OpenMailLauncher.getMailApps();

      if (apps.isNotEmpty) {
        final emailContent = EmailContent(
          to: ['test@example.com'],
          subject: 'Specific App Test',
          body: 'Testing opening a specific mail app.',
        );

        final bool result = await OpenMailLauncher.openSpecificMailApp(
          mailApp: apps.first,
          emailContent: emailContent,
        );

        expect(result, isA<bool>());
      }
    });

    testWidgets('EmailContent toMailtoUri should generate valid URI', (
      WidgetTester tester,
    ) async {
      final emailContent = EmailContent(
        to: ['test1@example.com', 'test2@example.com'],
        cc: ['cc@example.com'],
        bcc: ['bcc@example.com'],
        subject: 'Test Subject with Spaces',
        body: 'Test body with special characters & symbols!',
      );

      final String uri = emailContent.toMailtoUri();

      expect(uri.startsWith('mailto:'), true);
      expect(uri.contains('test1@example.com,test2@example.com'), true);
      expect(uri.contains('cc=cc@example.com'), true);
      expect(uri.contains('bcc=bcc@example.com'), true);
      expect(uri.contains('subject='), true);
      expect(uri.contains('body='), true);
    });

    testWidgets('MailApp equality and hashCode should work correctly', (
      WidgetTester tester,
    ) async {
      const app1 = MailApp(name: 'Gmail', id: 'com.google.android.gm');
      const app2 = MailApp(name: 'Gmail', id: 'com.google.android.gm');
      const app3 = MailApp(name: 'Outlook', id: 'com.microsoft.office.outlook');

      expect(app1, equals(app2));
      expect(app1.hashCode, equals(app2.hashCode));
      expect(app1, isNot(equals(app3)));
      expect(app1.hashCode, isNot(equals(app3.hashCode)));
    });

    testWidgets('OpenMailAppResult factories should work correctly', (
      WidgetTester tester,
    ) async {
      final successResult = OpenMailAppResult.success();
      expect(successResult.didOpen, true);
      expect(successResult.canOpen, true);
      expect(successResult.isSuccess, true);

      const testApp = MailApp(name: 'Test App', id: 'test.app');
      final singleAppResult = OpenMailAppResult.multiple(options: [testApp]);
      expect(singleAppResult.didOpen, false);
      expect(singleAppResult.canOpen, true);
      expect(singleAppResult.hasMultipleOptions, false); // Single app = false
      expect(singleAppResult.options.length, 1);

      // Test with multiple apps
      const testApp2 = MailApp(name: 'Test App 2', id: 'test.app2');
      final multipleResult = OpenMailAppResult.multiple(
        options: [testApp, testApp2],
      );
      expect(multipleResult.didOpen, false);
      expect(multipleResult.canOpen, true);
      expect(multipleResult.hasMultipleOptions, true); // Multiple apps = true
      expect(multipleResult.options.length, 2);

      final noAppsResult = OpenMailAppResult.noApps();
      expect(noAppsResult.didOpen, false);
      expect(noAppsResult.canOpen, false);
      expect(noAppsResult.isSuccess, false);

      final errorResult = OpenMailAppResult.error('Test error message');
      expect(errorResult.didOpen, false);
      expect(errorResult.canOpen, false);
      expect(errorResult.error, 'Test error message');
      expect(errorResult.isSuccess, false);
    });
  });
}
