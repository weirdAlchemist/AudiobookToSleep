import 'package:audiobook_to_sleep/core/sleep_detector.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime(2026, 10, 22, 23);
DateTime at({int min = 0, int sec = 0}) => t0.add(Duration(minutes: min, seconds: sec));
Duration pos(int seconds) => Duration(seconds: seconds);

const settings = SleepSettings(
  checkInInterval: Duration(minutes: 10),
  responseWindow: Duration(seconds: 60),
  maxSession: Duration(minutes: 120),
  rewind: Duration(seconds: 30),
);

SleepSettings withMax(int minutes) => SleepSettings(
      checkInInterval: settings.checkInInterval,
      responseWindow: settings.responseWindow,
      maxSession: Duration(minutes: minutes),
      rewind: settings.rewind,
    );

void main() {
  test('checks in after the interval and falls asleep if unanswered', () {
    final d = SleepDetector(settings)..start(at(), pos(1000));
    expect(d.tick(at(min: 9)), isNull);
    expect(d.tick(at(min: 10)), isA<CheckIn>());
    expect(d.state, DetectorState.checking);
    expect(d.tick(at(min: 10, sec: 59)), isNull);
    final event = d.tick(at(min: 11)) as FellAsleep;
    expect(event.reason, SleepReason.noResponse);
    // Bookmark goes to where we last knew they were awake, minus the rewind.
    expect(event.resumePosition, pos(970));
    expect(event.lastAwakeAt, at());
  });

  test('answering a check-in moves the awake mark and restarts the interval', () {
    final d = SleepDetector(settings)..start(at(), pos(0));
    d.tick(at(min: 10));
    expect(d.markAwake(at(min: 10, sec: 5), pos(605)), isA<AwakeConfirmed>());
    expect(d.state, DetectorState.listening);
    expect(d.tick(at(min: 19)), isNull);
    expect(d.tick(at(min: 20, sec: 5)), isA<CheckIn>());
    expect((d.tick(at(min: 21, sec: 5)) as FellAsleep).resumePosition, pos(575));
  });

  test('activity between check-ins postpones the next one', () {
    final d = SleepDetector(settings)..start(at(), pos(0));
    expect(d.markAwake(at(min: 8), pos(480)), isNull);
    expect(d.tick(at(min: 10)), isNull);
    expect(d.tick(at(min: 18)), isA<CheckIn>());
  });

  test('stops at the max session length even if the listener keeps answering', () {
    final d = SleepDetector(withMax(25))..start(at(), pos(0));
    d.markAwake(at(min: 9), pos(540));
    d.markAwake(at(min: 18), pos(1080));
    final event = d.tick(at(min: 25)) as FellAsleep;
    expect(event.reason, SleepReason.maxSession);
    expect(event.resumePosition, pos(1050));
  });

  test('late ticks still give a full response window', () {
    final d = SleepDetector(settings)..start(at(), pos(0));
    // First tick arrives 30 minutes late: we ask now rather than declaring sleep.
    expect(d.tick(at(min: 40)), isA<CheckIn>());
    expect(d.tick(at(min: 40, sec: 30)), isNull);
    expect(d.tick(at(min: 41)), isA<FellAsleep>());
  });

  test('resume position never goes below zero', () {
    final d = SleepDetector(settings)..start(at(), pos(10));
    d.tick(at(min: 10));
    expect((d.tick(at(min: 11)) as FellAsleep).resumePosition, Duration.zero);
  });

  test('wake() during the fade-out resumes without resetting the session clock', () {
    final d = SleepDetector(withMax(30))..start(at(), pos(0));
    d.tick(at(min: 10));
    d.tick(at(min: 11));
    expect(d.state, DetectorState.asleep);
    expect(d.markAwake(at(min: 11, sec: 5), pos(665)), isNull, reason: 'ignored once asleep');
    expect(d.wake(at(min: 11, sec: 5), pos(665)), isTrue);
    expect(d.state, DetectorState.listening);
    expect((d.tick(at(min: 30)) as FellAsleep).reason, SleepReason.maxSession);
  });

  test('untilNext counts down to whichever comes first', () {
    final d = SleepDetector(withMax(15))..start(at(), pos(0));
    expect(d.untilNext(at(min: 2)), const Duration(minutes: 8));
    d.markAwake(at(min: 9), pos(0));
    expect(d.untilNext(at(min: 9)), const Duration(minutes: 6));
    d.stop();
    expect(d.untilNext(at(min: 9)), isNull);
  });
}
