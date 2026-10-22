import 'package:audiobook_to_sleep/session/night_record.dart';
import 'package:audiobook_to_sleep/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

NightRecord night(EndReason reason) => NightRecord(
      sourceId: 'book:x',
      title: 'Book',
      startedAt: DateTime(2026, 10, 21, 23),
      endedAt: DateTime(2026, 10, 21, 23, 40),
      lastAwakeAt: DateTime(2026, 10, 21, 23, 20),
      startPosition: Duration.zero,
      endPosition: const Duration(minutes: 40),
      resumePosition: const Duration(minutes: 19, seconds: 30),
      reason: reason,
    );

Future<void> pump(WidgetTester tester, NightRecord n, VoidCallback onResume) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: LastNightCard(night: n, onResumeAtEnd: onResume))));

void main() {
  testWidgets('after falling asleep: shows the bookmark and offers to undo the rewind', (tester) async {
    var resumed = false;
    await pump(tester, night(EndReason.noResponse), () => resumed = true);
    expect(find.textContaining('Bookmark set to 19:30'), findsOneWidget);
    await tester.tap(find.text('I remember more, resume at 40:00'));
    expect(resumed, isTrue);
  });

  testWidgets('after stopping manually: no undo button', (tester) async {
    await pump(tester, night(EndReason.ended), () {});
    expect(find.textContaining('You stopped it yourself after 40 min'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
