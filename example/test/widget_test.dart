// Smoke tests for the example app's HomePage.
//
// The platform-channel call in HomePage.initState (`OpenMailLauncher.getMailApps`)
// resolves to an empty list in the test environment because no mock handler is
// registered — `methodChannel.invokeMethod` returns null and the Dart wrapper
// converts that to `[]`. No exceptions are thrown, so the widget tree builds
// the empty-state UI.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_mail_launcher_example/main.dart';

void main() {
  testWidgets('HomePage renders title, action buttons, and refresh control', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    // Pump once to let the initState-fired _loadMailApps() future settle.
    await tester.pump();

    expect(find.text('Open Mail Launcher Demo'), findsOneWidget);
    expect(find.text('Open Mail App'), findsOneWidget);
    expect(find.text('Compose Email'), findsOneWidget);
    expect(find.text('Check Mail App Available'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('HomePage shows the "No mail apps found" empty state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('No mail apps found'), findsOneWidget);
  });
}
