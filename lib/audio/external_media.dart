// Talks to the Android side (MediaBridge.kt), which reads and controls other
// apps' media sessions. Needs "notification access", which Android uses to
// gate this API; the user grants it once in system settings.

import 'dart:io';

import 'package:flutter/services.dart';

class ExternalSession {
  const ExternalSession({
    required this.packageName,
    required this.appName,
    required this.title,
    required this.subtitle,
    required this.position,
    required this.duration,
    required this.playing,
    required this.canSeek,
  });

  final String packageName;
  final String appName;
  final String title;
  final String subtitle;
  final Duration position;
  final Duration? duration;
  final bool playing;

  /// The app supports jumping to an exact position (most do; some only skip).
  final bool canSeek;

  factory ExternalSession.fromMap(Map<Object?, Object?> m) {
    final durationMs = m['durationMs'] as int? ?? 0;
    return ExternalSession(
      packageName: m['package']! as String,
      appName: m['appName'] as String? ?? m['package']! as String,
      title: m['title'] as String? ?? '',
      subtitle: m['subtitle'] as String? ?? '',
      position: Duration(milliseconds: m['positionMs'] as int? ?? 0),
      duration: durationMs > 0 ? Duration(milliseconds: durationMs) : null,
      playing: m['playing'] as bool? ?? false,
      canSeek: m['canSeek'] as bool? ?? false,
    );
  }
}

class ExternalMedia {
  static const _channel = MethodChannel('audiobook_to_sleep/media');

  /// Controlling other apps is only possible on Android.
  static bool get supported => Platform.isAndroid;

  static Future<bool> hasAccess() async =>
      supported && (await _channel.invokeMethod<bool>('hasAccess') ?? false);

  static Future<void> openAccessSettings() => _channel.invokeMethod('openAccessSettings');

  /// Active media sessions of other apps, most recently active first.
  static Future<List<ExternalSession>> sessions() async {
    final list = await _channel.invokeListMethod<Map<Object?, Object?>>('sessions') ?? const [];
    return [for (final m in list) ExternalSession.fromMap(m)];
  }

  static Future<ExternalSession?> session(String packageName) async {
    for (final s in await sessions()) {
      if (s.packageName == packageName) return s;
    }
    return null;
  }

  /// action: play | pause | rewind | fastForward | seekTo (with positionMs)
  static Future<void> control(String packageName, String action, {Duration? position}) =>
      _channel.invokeMethod('control', {
        'package': packageName,
        'action': action,
        if (position != null) 'positionMs': position.inMilliseconds,
      });

  /// Media (music) stream volume as a step index, and its maximum.
  static Future<(int, int)> volume() async {
    final m = await _channel.invokeMapMethod<String, int>('getVolume') ?? const {};
    return (m['volume'] ?? 0, m['max'] ?? 15);
  }

  static Future<void> setVolume(int index) => _channel.invokeMethod('setVolume', {'volume': index});
}
