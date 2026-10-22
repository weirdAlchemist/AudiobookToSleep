// App-wide objects, created once at startup.

import 'package:audio_service/audio_service.dart';

import 'audio/book_audio_handler.dart';
import 'data/stores.dart';
import 'session/app_settings.dart';

class AppServices {
  AppServices._(this.audio, this.library, this.nights, this.settings);

  final BookAudioHandler audio;
  final LibraryStore library;
  final NightLog nights;
  AppSettings settings;

  static late final AppServices instance;

  static Future<void> init() async {
    final audio = await AudioService.init(
      builder: BookAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.weirdalchemist.audiobook_to_sleep.playback',
        androidNotificationChannelName: 'Playback',
        androidNotificationOngoing: true,
        rewindInterval: BookAudioHandler.skipInterval,
        fastForwardInterval: BookAudioHandler.skipInterval,
      ),
    );
    instance = AppServices._(
      audio,
      await LibraryStore.open(),
      await NightLog.open(),
      await SettingsStore.load(),
    );
  }

  Future<void> updateSettings(AppSettings s) async {
    settings = s;
    await SettingsStore.save(s);
  }
}
