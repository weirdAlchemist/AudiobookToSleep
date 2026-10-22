import 'dart:async';

import 'package:audiobook_to_sleep/app_services.dart';
import 'package:audiobook_to_sleep/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a spinner while starting, then the home screen', (tester) async {
    final startup = Future<void>.delayed(const Duration(seconds: 2));
    await tester.pumpWidget(AudiobookToSleepApp(startup: startup, home: const Text('home')));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a failed startup step is shown on screen, not a blank window', (tester) async {
    final startup = Completer<void>();
    await tester.pumpWidget(AudiobookToSleepApp(startup: startup.future, home: const Text('home')));
    startup.completeError(StartupError('Opening the library', 'disk full'));
    await tester.pump();
    expect(find.text('The app could not start'), findsOneWidget);
    expect(find.text('Opening the library failed: disk full'), findsOneWidget);
    expect(find.text('home'), findsNothing);
  });
}
