import 'package:audiobook_to_sleep/audio/external_media.dart';
import 'package:audiobook_to_sleep/audio/external_target.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for MediaBridge.kt: one app whose player skips back 30 s per
/// "rewind" press and may or may not support exact seeking.
class FakeAndroid {
  FakeAndroid({required this.canSeek, this.positionMs = 600000});

  final bool canSeek;
  int positionMs;
  bool playing = true;
  int volume = 10;
  final calls = <String>[];

  Future<Object?> handle(MethodCall call) async {
    final args = (call.arguments as Map?)?.cast<String, Object?>() ?? const {};
    switch (call.method) {
      case 'sessions':
        return [
          {
            'package': 'com.audible.application',
            'appName': 'Audible',
            'title': 'The Book',
            'subtitle': 'An Author',
            'durationMs': 3600000,
            'positionMs': positionMs,
            'playing': playing,
            'canSeek': canSeek,
          },
        ];
      case 'control':
        final action = args['action']! as String;
        calls.add(action);
        switch (action) {
          case 'rewind':
            positionMs = (positionMs - 30000).clamp(0, 1 << 31);
          case 'seekTo':
            positionMs = args['positionMs']! as int;
          case 'pause':
            playing = false;
          case 'play':
            playing = true;
        }
        return null;
      case 'getVolume':
        return {'volume': volume, 'max': 15};
      case 'setVolume':
        volume = args['volume']! as int;
        calls.add('volume $volume');
        return null;
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('audiobook_to_sleep/media');

  Future<ExternalTarget> targetFor(FakeAndroid android) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, android.handle);
    return ExternalTarget((await ExternalMedia.sessions()).single);
  }

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test('reads the other app\'s session', () async {
    final target = await targetFor(FakeAndroid(canSeek: true));
    expect(target.title, 'The Book');
    expect(target.sourceId, 'app:com.audible.application');
    final snap = await target.snapshot();
    expect(snap.position, const Duration(minutes: 10));
    expect(snap.playing, isTrue);
  });

  test('seeks exactly when the app supports it', () async {
    final android = FakeAndroid(canSeek: true);
    final target = await targetFor(android);
    await target.seekTo(const Duration(minutes: 7, seconds: 12));
    expect(android.positionMs, 432000);
    expect(android.calls, ['seekTo']);
  });

  test('falls back to pressing rewind until at or just before the target', () async {
    final android = FakeAndroid(canSeek: false);
    final target = await targetFor(android);
    await target.seekTo(const Duration(minutes: 8, seconds: 10)); // 490 s
    // 600 -> 570 -> 540 -> 510 -> 480: first position not more than 5 s past the target.
    expect(android.positionMs, 480000);
    expect(android.calls.where((c) => c == 'rewind'), hasLength(4));
  });

  test('gives up if rewinding does not move the player', () async {
    final android = FakeAndroid(canSeek: false);
    final target = await targetFor(android);
    android.positionMs = 600000;
    // Simulate an app that ignores rewind.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'control') {
        android.calls.add((call.arguments as Map)['action'] as String);
        return null;
      }
      return android.handle(call);
    });
    await target.seekTo(Duration.zero);
    expect(android.calls, ['rewind']);
  });

  test('volume is relative to the level when the session started', () async {
    final android = FakeAndroid(canSeek: true)..volume = 10;
    final target = await targetFor(android);
    await target.setVolume(1);
    await target.setVolume(0.35);
    expect(android.volume, 4);
    await target.setVolume(0);
    expect(android.volume, 0);
    await target.setVolume(1);
    expect(android.volume, 10, reason: 'restored after the fade');
  });

  test('a vanished session reads as paused', () async {
    final android = FakeAndroid(canSeek: true);
    final target = await targetFor(android);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => call.method == 'sessions' ? <Object>[] : null);
    final snap = await target.snapshot();
    expect(snap.playing, isFalse);
    expect(snap.position, const Duration(minutes: 10));
  });
}
