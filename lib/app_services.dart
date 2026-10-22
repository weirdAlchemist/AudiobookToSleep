// App-wide objects, created once at startup.

import 'dart:async';

import 'package:audio_service/audio_service.dart';

import 'audio/book_audio_handler.dart';
import 'data/stores.dart';
import 'session/app_settings.dart';

/// A startup step that failed, with enough detail to report it.
class StartupError implements Exception {
  StartupError(this.step, this.error);

  final String step;
  final Object error;

  @override
  String toString() => '$step failed: $error';
}

class AppServices {
  AppServices._(this.audio, this.library, this.nights, this.settings, this.audioWarning);

  final BookAudioHandler audio;
  final LibraryStore library;
  final NightLog nights;
  AppSettings settings;

  /// Set when background playback couldn't be set up. The app still works,
  /// with plain playback and no lock-screen controls.
  final String? audioWarning;

  static late final AppServices instance;

  static const _stepTimeout = Duration(seconds: 10);

  static Future<void> init() async {
    final (audio, audioWarning) = await _initAudio();
    instance = AppServices._(
      audio,
      await _step('Opening the library', LibraryStore.open),
      await _step('Opening the night log', NightLog.open),
      await _step('Loading settings', SettingsStore.load),
      audioWarning,
    );
  }

  // audio_service waits for its background service to connect before init
  // completes, and on some phones that never happens. Don't let it block the
  // whole app: fall back to playing without the background service.
  static Future<(BookAudioHandler, String?)> _initAudio() async {
    try {
      final handler = await AudioService.init(
        builder: BookAudioHandler.new,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.weirdalchemist.audiobook_to_sleep.playback',
          androidNotificationChannelName: 'Playback',
          androidNotificationOngoing: true,
          rewindInterval: BookAudioHandler.skipInterval,
          fastForwardInterval: BookAudioHandler.skipInterval,
        ),
      ).timeout(_stepTimeout);
      return (handler, null);
    } on TimeoutException {
      return (BookAudioHandler(), 'the background audio service did not respond');
    } catch (e) {
      return (BookAudioHandler(), '$e');
    }
  }

  static Future<T> _step<T>(String name, Future<T> Function() run) async {
    try {
      return await run().timeout(_stepTimeout);
    } catch (e) {
      throw StartupError(name, e is TimeoutException ? 'no response after ${_stepTimeout.inSeconds} s' : e);
    }
  }

  Future<void> updateSettings(AppSettings s) async {
    settings = s;
    await SettingsStore.save(s);
  }
}
