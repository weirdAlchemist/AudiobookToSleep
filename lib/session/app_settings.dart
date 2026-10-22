import '../core/sleep_detector.dart';

enum CameraLens { front, back }

/// Light during check-ins so a wave can be seen in the dark.
enum CameraLight { off, flashlight, screen }

class AppSettings {
  const AppSettings({
    this.checkInIntervalMin = 10,
    this.responseWindowSec = 60,
    this.maxSessionMin = 120,
    this.rewindSec = 30,
    this.fadeOutSec = 30,
    this.keepScreenOn = true,
    this.voiceEnabled = true,
    this.cameraEnabled = false,
    this.cameraLens = CameraLens.front,
    this.cameraLight = CameraLight.off,
    this.voiceLocales = const [],
  });

  final int checkInIntervalMin;
  final int responseWindowSec;
  final int maxSessionMin;
  final int rewindSec;
  final int fadeOutSec;
  final bool keepScreenOn;
  final bool voiceEnabled;
  final bool cameraEnabled;

  /// Which camera watches for a wave.
  final CameraLens cameraLens;

  /// Light while watching: the flashlight (works with either camera) or the
  /// screen at full brightness (front camera).
  final CameraLight cameraLight;

  /// Recognizer languages for voice answers, e.g. ['de_DE', 'en_US'].
  /// Empty: follow the phone's language.
  final List<String> voiceLocales;

  SleepSettings get sleep => SleepSettings(
        checkInInterval: Duration(minutes: checkInIntervalMin),
        responseWindow: Duration(seconds: responseWindowSec),
        maxSession: Duration(minutes: maxSessionMin),
        rewind: Duration(seconds: rewindSec),
      );

  Duration get fadeOut => Duration(seconds: fadeOutSec);

  AppSettings copyWith({
    int? checkInIntervalMin,
    int? responseWindowSec,
    int? maxSessionMin,
    int? rewindSec,
    int? fadeOutSec,
    bool? keepScreenOn,
    bool? voiceEnabled,
    bool? cameraEnabled,
    CameraLens? cameraLens,
    CameraLight? cameraLight,
    List<String>? voiceLocales,
  }) =>
      AppSettings(
        checkInIntervalMin: checkInIntervalMin ?? this.checkInIntervalMin,
        responseWindowSec: responseWindowSec ?? this.responseWindowSec,
        maxSessionMin: maxSessionMin ?? this.maxSessionMin,
        rewindSec: rewindSec ?? this.rewindSec,
        fadeOutSec: fadeOutSec ?? this.fadeOutSec,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        voiceEnabled: voiceEnabled ?? this.voiceEnabled,
        cameraEnabled: cameraEnabled ?? this.cameraEnabled,
        cameraLens: cameraLens ?? this.cameraLens,
        cameraLight: cameraLight ?? this.cameraLight,
        voiceLocales: voiceLocales ?? this.voiceLocales,
      );

  Map<String, Object> toJson() => {
        'checkInIntervalMin': checkInIntervalMin,
        'responseWindowSec': responseWindowSec,
        'maxSessionMin': maxSessionMin,
        'rewindSec': rewindSec,
        'fadeOutSec': fadeOutSec,
        'keepScreenOn': keepScreenOn,
        'voiceEnabled': voiceEnabled,
        'cameraEnabled': cameraEnabled,
        'cameraLens': cameraLens.name,
        'cameraLight': cameraLight.name,
        'voiceLocales': voiceLocales,
      };

  factory AppSettings.fromJson(Map<String, Object?> j) {
    const d = AppSettings();
    return AppSettings(
      checkInIntervalMin: j['checkInIntervalMin'] as int? ?? d.checkInIntervalMin,
      responseWindowSec: j['responseWindowSec'] as int? ?? d.responseWindowSec,
      maxSessionMin: j['maxSessionMin'] as int? ?? d.maxSessionMin,
      rewindSec: j['rewindSec'] as int? ?? d.rewindSec,
      fadeOutSec: j['fadeOutSec'] as int? ?? d.fadeOutSec,
      keepScreenOn: j['keepScreenOn'] as bool? ?? d.keepScreenOn,
      voiceEnabled: j['voiceEnabled'] as bool? ?? d.voiceEnabled,
      cameraEnabled: j['cameraEnabled'] as bool? ?? d.cameraEnabled,
      // Before lens/light existed, a flashlight meant the back camera.
      cameraLens: _byName(CameraLens.values, j['cameraLens']) ??
          (j['cameraTorch'] == true ? CameraLens.back : d.cameraLens),
      cameraLight: _byName(CameraLight.values, j['cameraLight']) ??
          (j['cameraTorch'] == true ? CameraLight.flashlight : d.cameraLight),
      voiceLocales: (j['voiceLocales'] as List?)?.cast<String>() ?? d.voiceLocales,
    );
  }
}

T? _byName<T extends Enum>(List<T> values, Object? name) =>
    values.where((v) => v.name == name).firstOrNull;
