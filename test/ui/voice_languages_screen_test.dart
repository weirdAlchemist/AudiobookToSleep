import 'package:audiobook_to_sleep/ui/voice_languages_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  final languages = [
    LocaleName('de_DE', 'Deutsch (Deutschland)'),
    LocaleName('en_US', 'English (United States)'),
    LocaleName('ja_JP', '日本語 (日本)'),
    LocaleName('tr_TR', 'Türkçe (Türkiye)'),
  ];
  late List<List<String>> saved;

  Future<void> pump(WidgetTester tester, List<String> initial) async {
    saved = [];
    await tester.binding.setSurfaceSize(const Size(500, 1600));
    await tester.pumpWidget(MaterialApp(
      home: VoiceLanguagesScreen(
        loadLanguages: () async => (languages, languages[2]),
        initial: initial,
        onChanged: saved.add,
      ),
    ));
    await tester.pump();
  }

  testWidgets('follows the phone language by default', (tester) async {
    await pump(tester, const []);
    expect(find.text('Follow phone language'), findsOneWidget);
    expect(find.text('日本語 (日本)'), findsOneWidget, reason: 'phone language shown');
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets('turning it off starts with the phone language, then more can be added', (tester) async {
    await pump(tester, const []);
    await tester.tap(find.text('Follow phone language'));
    await tester.pump();
    expect(saved.last, ['ja_JP']);

    await tester.tap(find.text('English (United States)'));
    await tester.pump();
    expect(saved.last, ['ja_JP', 'en_US']);
    expect(find.textContaining('"起きてる"'), findsOneWidget, reason: 'shows phrases per language');
  });

  testWidgets('languages without built-in phrases say "OK" works', (tester) async {
    await pump(tester, const ['de_DE']);
    expect(find.text('No built-in phrases yet: "OK" works'), findsOneWidget); // Türkçe
    expect(find.textContaining('"ich bin wach"'), findsOneWidget);
  });

  testWidgets('the last language cannot be unticked', (tester) async {
    await pump(tester, const ['de_DE']);
    final tile = tester.widget<CheckboxListTile>(
        find.ancestor(of: find.text('Deutsch (Deutschland)'), matching: find.byType(CheckboxListTile)));
    expect(tile.onChanged, isNull);
  });

  testWidgets('search filters the languages to add', (tester) async {
    await pump(tester, const ['de_DE']);
    await tester.enterText(find.byType(TextField), 'türk');
    await tester.pump();
    expect(find.text('Türkçe (Türkiye)'), findsOneWidget);
    expect(find.text('English (United States)'), findsNothing);
  });
}
