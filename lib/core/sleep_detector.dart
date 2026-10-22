// Decides when the listener has fallen asleep.
//
// The detector never measures sleep directly. Instead it periodically asks
// "still awake?" (the app dips the volume and shows a prompt). Any sign of
// life — a tap, a spoken answer, a wave — resets the clock. If a check-in goes
// unanswered, we assume the listener drifted off somewhere after the last
// moment we *knew* they were awake, so that is where the bookmark goes.
//
// Time and position are injected so the logic is deterministic and testable.

import 'dart:math' as math;

class SleepSettings {
  const SleepSettings({
    this.checkInInterval = const Duration(minutes: 10),
    this.responseWindow = const Duration(seconds: 60),
    this.maxSession = const Duration(minutes: 120),
    this.rewind = const Duration(seconds: 30),
  });

  /// Time between "still awake?" checks.
  final Duration checkInInterval;

  /// How long a check-in waits for an answer.
  final Duration responseWindow;

  /// Hard stop, even if the listener keeps answering.
  final Duration maxSession;

  /// Extra rewind before the last awake position.
  final Duration rewind;
}

enum DetectorState { idle, listening, checking, asleep }

enum SleepReason { noResponse, maxSession }

sealed class DetectorEvent {
  const DetectorEvent();
}

class CheckIn extends DetectorEvent {
  const CheckIn();
}

class AwakeConfirmed extends DetectorEvent {
  const AwakeConfirmed();
}

class FellAsleep extends DetectorEvent {
  const FellAsleep({required this.reason, required this.lastAwakeAt, required this.resumePosition});
  final SleepReason reason;
  final DateTime lastAwakeAt;
  final Duration resumePosition;
}

class SleepDetector {
  SleepDetector([this.settings = const SleepSettings()]);

  final SleepSettings settings;
  DetectorState state = DetectorState.idle;
  DateTime? startedAt;
  DateTime? lastAwakeAt;
  Duration? lastAwakePosition;
  DateTime? checkInStartedAt;

  bool get active => state == DetectorState.listening || state == DetectorState.checking;

  void start(DateTime now, Duration position) {
    state = DetectorState.listening;
    startedAt = now;
    _markAwake(now, position);
  }

  /// Any sign the listener is awake. Returns an event if it answered a check-in.
  DetectorEvent? markAwake(DateTime now, Duration position) {
    if (!active) return null;
    final answeredCheckIn = state == DetectorState.checking;
    state = DetectorState.listening;
    _markAwake(now, position);
    return answeredCheckIn ? const AwakeConfirmed() : null;
  }

  /// The listener stirred while the book was fading out after an unanswered
  /// check-in: go back to listening without restarting the session clock.
  bool wake(DateTime now, Duration position) {
    if (state != DetectorState.asleep) return false;
    state = DetectorState.listening;
    _markAwake(now, position);
    return true;
  }

  /// Call often. Timers can run late, so all decisions are based on elapsed
  /// wall-clock time, not on how many ticks happened.
  DetectorEvent? tick(DateTime now) {
    switch (state) {
      case DetectorState.listening:
        if (now.difference(startedAt!) >= settings.maxSession) {
          return _fallAsleep(SleepReason.maxSession);
        }
        if (now.difference(lastAwakeAt!) >= settings.checkInInterval) {
          state = DetectorState.checking;
          checkInStartedAt = now;
          return const CheckIn();
        }
      case DetectorState.checking:
        if (now.difference(checkInStartedAt!) >= settings.responseWindow) {
          return _fallAsleep(SleepReason.noResponse);
        }
      case DetectorState.idle:
      case DetectorState.asleep:
        break;
    }
    return null;
  }

  /// Where to resume next time if the session ended right now.
  Duration? get resumePosition {
    final p = lastAwakePosition;
    if (p == null) return null;
    final r = p - settings.rewind;
    return r.isNegative ? Duration.zero : r;
  }

  /// Time until the next state change, for countdown displays.
  Duration? untilNext(DateTime now) {
    switch (state) {
      case DetectorState.listening:
        final checkIn = lastAwakeAt!.add(settings.checkInInterval);
        final max = startedAt!.add(settings.maxSession);
        final next = checkIn.isBefore(max) ? checkIn : max;
        return _nonNegative(next.difference(now));
      case DetectorState.checking:
        return _nonNegative(checkInStartedAt!.add(settings.responseWindow).difference(now));
      case DetectorState.idle:
      case DetectorState.asleep:
        return null;
    }
  }

  void stop() {
    state = DetectorState.idle;
    checkInStartedAt = null;
  }

  void _markAwake(DateTime now, Duration position) {
    lastAwakeAt = now;
    lastAwakePosition = position;
    checkInStartedAt = null;
  }

  FellAsleep _fallAsleep(SleepReason reason) {
    state = DetectorState.asleep;
    return FellAsleep(reason: reason, lastAwakeAt: lastAwakeAt!, resumePosition: resumePosition!);
  }
}

Duration _nonNegative(Duration d) => Duration(microseconds: math.max(0, d.inMicroseconds));
