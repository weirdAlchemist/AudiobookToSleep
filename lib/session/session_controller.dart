// Runs one sleep session: plays the target, asks "still awake?" on schedule,
// listens for answers, and when nobody answers fades out, stops, and moves
// the bookmark back to the last moment the listener was known to be awake.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../core/sleep_detector.dart';
import 'answer_listener.dart';
import 'app_settings.dart';
import 'night_record.dart';
import 'playback_target.dart';

enum SessionPhase { idle, listening, checking, fadingOut }

class SessionController extends ChangeNotifier {
  SessionController({
    required this.target,
    required this.settings,
    this.listeners = const [],
    this.onCheckpoint,
    this.onFinished,
  });

  static const tickInterval = Duration(seconds: 1);
  static const checkInVolume = 0.35;
  static const voiceCheckInVolume = 0.2; // quieter, so the mic hears you over the book
  static const _fadeStep = Duration(milliseconds: 100);

  final PlaybackTarget target;
  final AppSettings settings;
  final List<AnswerListener> listeners;

  /// Called every tick with the bookmark that is safe to persist right now:
  /// the last-awake position, since the listener may already be asleep.
  final void Function(Duration safeBookmark)? onCheckpoint;
  final void Function(NightRecord record)? onFinished;

  late final SleepDetector _detector = SleepDetector(settings.sleep);
  SessionPhase phase = SessionPhase.idle;
  FellAsleep? _fadingOut;

  /// Listeners that are available for this session (permission granted).
  List<AnswerListener> usable = const [];
  Duration? untilNext;
  NightRecord? result;

  DateTime? _startedAt;
  Duration _startPosition = Duration.zero;
  Duration _lastPosition = Duration.zero;
  bool _sawPlaying = false;
  bool _ticking = false;
  bool _ending = false;
  bool _listening = false;

  double _volume = 1;
  Timer? _ticker;
  Timer? _fadeTimer;
  Completer<bool>? _fade;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  bool get active => phase != SessionPhase.idle;
  bool get _quietCheckIn => usable.any((l) => l.wantsQuietCheckIn);

  Future<void> start() async {
    final now = clock.now();
    final snap = await target.snapshot();
    _startedAt = now;
    _startPosition = snap.position;
    _lastPosition = snap.position;
    _detector.start(now, snap.position);
    phase = SessionPhase.listening;
    await _setVolume(1);
    await target.play();
    _sawPlaying = snap.playing;
    _subscriptions.add(target.awakeSignals.listen((_) => signOfLife()));
    _ticker = Timer.periodic(tickInterval, (_) => tick());
    notifyListeners();

    // Ask for mic/camera while the user is still looking at the screen.
    final ready = <AnswerListener>[];
    for (final l in listeners) {
      if (await l.prepare()) ready.add(l);
    }
    if (!active) return;
    usable = ready;
    for (final l in usable) {
      _subscriptions.add(l.answers.listen(_onAnswer));
    }
    notifyListeners();
  }

  Future<void> tick() async {
    if (!active || _ticking) return;
    _ticking = true;
    try {
      final snap = await target.snapshot();
      if (!active) return;
      _lastPosition = snap.position;
      if (snap.playing) _sawPlaying = true;
      if (_fadingOut == null) {
        if (snap.completed) return await end(EndReason.bookEnd);
        // Paused from the lock screen, headphones unplugged, or a call: the
        // listener was clearly awake, so keep their exact place.
        if (!snap.playing && _sawPlaying) return await end(EndReason.interrupted);
      }
      final now = clock.now();
      switch (_detector.tick(now)) {
        case CheckIn():
          _onCheckIn();
        case final FellAsleep event:
          unawaited(_onAsleep(event));
        case AwakeConfirmed():
        case null:
          break;
      }
      untilNext = _fadingOut == null ? _detector.untilNext(now) : null;
      if (_detector.active) onCheckpoint?.call(_detector.resumePosition!);
      notifyListeners();
    } finally {
      _ticking = false;
    }
  }

  /// Any sign the listener is awake: a tap, a spoken answer, a wave.
  void signOfLife() {
    if (!active || _ending) return;
    final now = clock.now();
    final fading = _fadingOut;
    if (fading != null) {
      // Caught it during the fade: carry on listening.
      if (fading.reason == SleepReason.noResponse && _detector.wake(now, _lastPosition)) {
        _fadingOut = null;
        _backToListening();
      }
      return;
    }
    if (_detector.markAwake(now, _lastPosition) is AwakeConfirmed) _backToListening();
    untilNext = _detector.untilNext(now);
    notifyListeners();
  }

  Future<void> end(EndReason reason) async {
    if (!active || _ending) return;
    _ending = true;
    final now = clock.now();
    final snap = await target.snapshot();
    final endPosition = snap.position;
    final resumePosition =
        reason.mayHaveSlept ? (_detector.resumePosition ?? endPosition) : endPosition;
    final record = NightRecord(
      sourceId: target.sourceId,
      title: target.title,
      startedAt: _startedAt!,
      endedAt: now,
      lastAwakeAt: _detector.lastAwakeAt!,
      startPosition: _startPosition,
      endPosition: endPosition,
      resumePosition: resumePosition,
      reason: reason,
    );

    _detector.stop();
    _ticker?.cancel();
    _cancelFade();
    _fadingOut = null;
    await _stopListening();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();

    await target.pause();
    if (reason.mayHaveSlept) await target.seekTo(resumePosition);
    await _setVolume(1);

    result = record;
    phase = SessionPhase.idle;
    untilNext = null;
    _ending = false;
    onFinished?.call(record);
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _cancelFade();
    for (final s in _subscriptions) {
      s.cancel();
    }
    for (final l in usable) {
      l.stop();
    }
    super.dispose();
  }

  // ---- internals ----

  void _onAnswer(Answer answer) {
    if (answer == Answer.stop) {
      unawaited(end(EndReason.ended));
    } else {
      signOfLife();
    }
  }

  void _onCheckIn() {
    phase = SessionPhase.checking;
    _fadeTo(_quietCheckIn ? voiceCheckInVolume : checkInVolume, const Duration(seconds: 2));
    unawaited(_startListening());
  }

  Future<void> _onAsleep(FellAsleep event) async {
    _fadingOut = event;
    phase = SessionPhase.fadingOut;
    // Keep listening through the fade so an answer can still rescue it.
    if (event.reason != SleepReason.noResponse) await _stopListening();
    notifyListeners();
    final finished = await _fadeTo(0, settings.fadeOut);
    if (!finished || _fadingOut != event) return; // rescued, or already ended
    await end(event.reason == SleepReason.maxSession ? EndReason.maxSession : EndReason.noResponse);
  }

  void _backToListening() {
    phase = SessionPhase.listening;
    _fadeTo(1, const Duration(milliseconds: 1500));
    unawaited(_stopListening());
    notifyListeners();
  }

  Future<void> _startListening() async {
    if (_listening) return;
    _listening = true;
    for (final l in usable) {
      await l.start();
    }
  }

  Future<void> _stopListening() async {
    if (!_listening) return;
    _listening = false;
    for (final l in usable) {
      await l.stop();
    }
  }

  Future<void> _setVolume(double level) async {
    _volume = level;
    await target.setVolume(level);
  }

  /// Ramps volume linearly. Completes true when finished, or false if another
  /// fade (or the end of the session) replaced it first.
  Future<bool> _fadeTo(double level, Duration duration) {
    _cancelFade();
    final fade = _fade = Completer<bool>();
    final from = _volume;
    final steps = duration.inMilliseconds ~/ _fadeStep.inMilliseconds;
    if (steps <= 0) {
      _setVolume(level);
      fade.complete(true);
      return fade.future;
    }
    var step = 0;
    _fadeTimer = Timer.periodic(_fadeStep, (timer) {
      step++;
      final t = step / steps;
      unawaited(_setVolume(from + (level - from) * t));
      if (step >= steps) {
        timer.cancel();
        if (!fade.isCompleted) fade.complete(true);
      }
    });
    return fade.future;
  }

  void _cancelFade() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    final fade = _fade;
    if (fade != null && !fade.isCompleted) fade.complete(false);
  }
}
