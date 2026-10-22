import 'dart:async';

import 'package:audiobook_to_sleep/session/answer_listener.dart';
import 'package:audiobook_to_sleep/session/playback_target.dart';
import 'package:clock/clock.dart';

/// A player whose position advances with the (fake) clock while playing.
class FakeTarget extends PlaybackTarget {
  FakeTarget({Duration position = Duration.zero, this.length = const Duration(hours: 10)})
      : _base = position;

  final Duration length;
  Duration _base;
  DateTime? _playingSince;
  double volume = 1;
  final List<double> volumes = [];
  final List<Duration> seeks = [];
  final skips = StreamController<void>.broadcast();

  @override
  String get title => 'Fake book';
  @override
  String get sourceId => 'book:fake';

  Duration get position {
    final p = _playingSince == null ? _base : _base + clock.now().difference(_playingSince!);
    return p > length ? length : p;
  }

  bool get playing => _playingSince != null && position < length;

  /// Simulates the user pausing from the lock screen or the other app.
  void externalPause() {
    _base = position;
    _playingSince = null;
  }

  @override
  Future<PlaybackSnapshot> snapshot() async =>
      PlaybackSnapshot(position: position, playing: playing, completed: position >= length);

  @override
  Future<void> play() async => _playingSince ??= clock.now();

  @override
  Future<void> pause() async => externalPause();

  @override
  Future<void> seekTo(Duration p) async {
    seeks.add(p);
    _base = p;
    if (_playingSince != null) _playingSince = clock.now();
  }

  @override
  Future<void> setVolume(double level) async {
    volume = level;
    volumes.add(level);
  }

  final List<bool> answerListening = [];

  @override
  Future<void> setAnswerListening(bool active) async => answerListening.add(active);

  @override
  Stream<void> get awakeSignals => skips.stream;
}

class FakeListener extends AnswerListener {
  FakeListener({this.available = true, this.quiet = false, this.onStart});

  final bool available;
  final bool quiet;

  /// Runs when listening starts, e.g. to simulate the speech recognizer
  /// taking audio focus and the player pausing.
  final void Function()? onStart;
  bool running = false;
  int starts = 0;
  final _answers = StreamController<Answer>.broadcast();

  void say(Answer a) => _answers.add(a);

  @override
  String get hint => 'fake';
  @override
  bool get wantsQuietCheckIn => quiet;
  @override
  Future<bool> prepare() async => available;
  @override
  Future<void> start() async {
    running = true;
    starts++;
    onStart?.call();
  }

  @override
  Future<void> stop() async => running = false;
  @override
  Stream<Answer> get answers => _answers.stream;
}
