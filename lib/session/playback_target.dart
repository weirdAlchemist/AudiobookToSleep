// What a sleep session controls: the built-in book player, or another app's
// player (Spotify, Audible, ...) through Android's media session APIs.

import 'dart:async';

class PlaybackSnapshot {
  const PlaybackSnapshot({required this.position, required this.playing, this.completed = false});

  final Duration position;
  final bool playing;

  /// The book reached its end.
  final bool completed;
}

abstract class PlaybackTarget {
  /// Shown in the UI and the night log.
  String get title;

  /// Stable id for the night log: `book:<id>` or `app:<package>`.
  String get sourceId;

  Future<PlaybackSnapshot> snapshot();
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);

  /// Volume relative to where it was when the session started (0..1).
  Future<void> setVolume(double level);

  /// Called when the app's own answer listeners (microphone, camera) start or
  /// stop. The speech recognizer takes audio focus, so a player that can
  /// should keep playing through that instead of pausing.
  Future<void> setAnswerListening(bool active) async {}

  /// Presses of lock-screen / headphone skip buttons that should count as
  /// "I'm awake" during a session. Only the built-in player receives these.
  Stream<void> get awakeSignals => const Stream.empty();
}
