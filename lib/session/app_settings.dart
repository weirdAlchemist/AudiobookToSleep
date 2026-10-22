import '../core/sleep_detector.dart';

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
    this.cameraTorch = false,
  });

  final int checkInIntervalMin;
  final int responseWindowSec;
  final int maxSessionMin;
  final int rewindSec;
  final int fadeOutSec;
  final bool keepScreenOn;
  final bool voiceEnabled;
  final bool cameraEnabled;

  /// Light the scene with the flashlight (back camera) while watching for a wave.
  final bool cameraTorch;

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
    bool? cameraTorch,
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
        cameraTorch: cameraTorch ?? this.cameraTorch,
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
        'cameraTorch': cameraTorch,
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
      cameraTorch: j['cameraTorch'] as bool? ?? d.cameraTorch,
    );
  }
}
