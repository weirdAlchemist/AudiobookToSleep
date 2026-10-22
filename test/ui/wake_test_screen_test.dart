import 'dart:async';

import 'package:audiobook_to_sleep/answers/camera_listener.dart';
import 'package:audiobook_to_sleep/answers/voice_listener.dart';
import 'package:audiobook_to_sleep/core/voice_commands.dart';
import 'package:audiobook_to_sleep/session/answer_listener.dart';
import 'package:audiobook_to_sleep/ui/wake_test_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeVoice extends VoiceListener {
  FakeVoice({this.available = true});

  final bool available;
  bool listening = false;
  final heardCtrl = StreamController<(String, VoiceCommand?)>.broadcast();

  @override
  Future<bool> prepare() async => available;
  @override
  Future<void> start() async => listening = true;
  @override
  Future<void> stop() async => listening = false;
  @override
  Stream<(String, VoiceCommand?)> get heard => heardCtrl.stream;
}

class FakeCamera extends CameraListener {
  FakeCamera({super.torch});

  bool running = false;
  final answersCtrl = StreamController<Answer>.broadcast();
  final noteValue = ValueNotifier<String?>(null);

  @override
  Future<bool> prepare() async => true;
  @override
  Future<void> start() async => running = true;
  @override
  Future<void> stop() async => running = false;
  @override
  Stream<Answer> get answers => answersCtrl.stream;
  @override
  ValueListenable<String?> get note => noteValue;
}

void main() {
  late FakeVoice voice;
  late List<FakeCamera> cameras;

  Future<void> pump(WidgetTester tester, {bool voiceAvailable = true}) async {
    voice = FakeVoice(available: voiceAvailable);
    cameras = [];
    await tester.binding.setSurfaceSize(const Size(500, 2400));
    await tester.pumpWidget(MaterialApp(
      home: WakeTestScreen(
        voiceFactory: () => voice,
        cameraFactory: ({bool torch = false}) {
          final c = FakeCamera(torch: torch);
          cameras.add(c);
          return c;
        },
      ),
    ));
  }

  testWidgets('tap test counts taps', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Tap here'));
    await tester.tap(find.text('Tap here'));
    await tester.pump();
    expect(find.text('✓ Tap works (2)'), findsOneWidget);
  });

  testWidgets('voice test shows what was heard and whether it counts', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Start listening'));
    await tester.pump();
    expect(voice.listening, isTrue);
    expect(find.text('Listening…'), findsOneWidget);
    voice.hearing.value = 'ok';
    await tester.pump();
    expect(find.text('Hearing: "ok"'), findsOneWidget);
    voice.diagnostics.value = 'Recognizer error: error_language_not_supported';
    await tester.pump();
    expect(find.text('Recognizer error: error_language_not_supported'), findsOneWidget);

    voice.heardCtrl.add(('the rain kept falling', null));
    voice.heardCtrl.add(("I'm awake", VoiceCommand.awake));
    await tester.pump();
    expect(find.text('Heard "the rain kept falling": not a command'), findsOneWidget);
    expect(find.text('Heard "I\'m awake" → awake'), findsOneWidget);
    expect(find.text('✓ Voice works (1)'), findsOneWidget);

    await tester.tap(find.text('Stop listening'));
    await tester.pump();
    expect(voice.listening, isFalse);
  });

  testWidgets('voice test explains when speech recognition is unavailable', (tester) async {
    await pump(tester, voiceAvailable: false);
    await tester.tap(find.text('Start listening'));
    await tester.pump();
    expect(find.textContaining('Speech recognition is unavailable'), findsOneWidget);
  });

  testWidgets('camera test counts waves and shows notes', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Start camera'));
    await tester.pump();
    final camera = cameras.single;
    expect(camera.running, isTrue);
    expect(camera.torch, isFalse);

    camera.answersCtrl.add(Answer.awake);
    camera.noteValue.value = 'Too dark for the camera to see you';
    await tester.pump();
    expect(find.text('✓ Wave detected (1)'), findsOneWidget);
    expect(find.text('Too dark for the camera to see you'), findsOneWidget);
  });

  testWidgets('turning on the flashlight restarts the camera with the torch', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Start camera'));
    await tester.pump();
    await tester.tap(find.text('Flashlight'));
    await tester.pumpAndSettle();
    expect(cameras, hasLength(2));
    expect(cameras.first.running, isFalse);
    expect(cameras.last.torch, isTrue);
    expect(cameras.last.running, isTrue);
    expect(find.textContaining('Back camera with the flashlight on'), findsOneWidget);
  });

  testWidgets('headphone test is hidden without the built-in player', (tester) async {
    await pump(tester);
    expect(find.text('Headphone or lock-screen buttons'), findsNothing);
  });
}
