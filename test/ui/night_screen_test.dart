import 'package:audiobook_to_sleep/session/app_settings.dart';
import 'package:audiobook_to_sleep/session/session_controller.dart';
import 'package:audiobook_to_sleep/ui/night_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../session/fakes.dart';

void main() {
  testWidgets('tap answers a check-in; ending the session closes the screen', (tester) async {
    final target = FakeTarget();
    final controller = SessionController(
      target: target,
      settings: const AppSettings(checkInIntervalMin: 1, responseWindowSec: 30, keepScreenOn: false),
      listeners: [FakeListener(quiet: true)],
    );
    late Future<void> started;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () {
            started = controller.start();
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => NightScreen(controller: controller, started: started, keepScreenOn: false),
            ));
          },
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Listening…'), findsOneWidget);
    expect(find.textContaining('When the volume dips, fake or tap the screen'), findsOneWidget);

    // A minute later: check-in.
    for (var i = 0; i < 62; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('Still awake? Fake!'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Listening…'), findsOneWidget);

    await tester.tap(find.text('End session'));
    await tester.pumpAndSettle();
    expect(find.byType(NightScreen), findsNothing);
    expect(controller.result, isNotNull);
    controller.dispose();
  });
}
