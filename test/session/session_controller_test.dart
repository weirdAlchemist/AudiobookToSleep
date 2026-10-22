import 'package:audiobook_to_sleep/session/answer_listener.dart';
import 'package:audiobook_to_sleep/session/app_settings.dart';
import 'package:audiobook_to_sleep/session/night_record.dart';
import 'package:audiobook_to_sleep/session/session_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const settings = AppSettings(
  checkInIntervalMin: 10,
  responseWindowSec: 60,
  maxSessionMin: 120,
  rewindSec: 30,
  fadeOutSec: 30,
);

const sec = Duration(seconds: 1);
Duration mins(int m) => Duration(minutes: m);

void main() {
  late FakeTarget target;
  late List<NightRecord> finished;

  SessionController controller(FakeAsync async,
      {AppSettings s = settings, List<AnswerListener> listeners = const []}) {
    final c = SessionController(
      target: target,
      settings: s,
      listeners: listeners,
      onFinished: finished.add,
    );
    c.start();
    async.flushMicrotasks();
    return c;
  }

  setUp(() {
    target = FakeTarget(position: const Duration(minutes: 60));
    finished = [];
  });

  test('unanswered check-in fades out, stops, and bookmarks the last awake moment', () {
    fakeAsync((async) {
      final c = controller(async);
      expect(target.playing, isTrue);
      async.elapse(mins(10) + sec);
      expect(c.phase, SessionPhase.checking);
      async.elapse(const Duration(seconds: 3));
      expect(target.volume, closeTo(SessionController.checkInVolume, 0.01));

      async.elapse(const Duration(seconds: 60));
      expect(c.phase, SessionPhase.fadingOut);
      async.elapse(const Duration(seconds: 31));

      expect(c.phase, SessionPhase.idle);
      expect(target.playing, isFalse);
      final night = finished.single;
      expect(night.reason, EndReason.noResponse);
      // Awake at the start (60:00) minus the 30 s rewind.
      expect(night.resumePosition, const Duration(minutes: 59, seconds: 30));
      expect(target.position, night.resumePosition);
      expect(night.endPosition, greaterThan(const Duration(minutes: 71)));
      expect(target.volume, 1, reason: 'volume restored for next time');
    });
  });

  test('a tap during a check-in keeps playing and moves the awake mark', () {
    fakeAsync((async) {
      final c = controller(async);
      async.elapse(mins(10) + const Duration(seconds: 5));
      expect(c.phase, SessionPhase.checking);
      c.signOfLife();
      async.elapse(const Duration(seconds: 2));
      expect(c.phase, SessionPhase.listening);
      expect(target.volume, 1);

      // Then falls asleep: bookmark is the answered check-in, minus rewind.
      async.elapse(mins(12));
      async.elapse(const Duration(seconds: 40));
      expect(finished.single.resumePosition.inSeconds, closeTo((70 * 60 + 5) - 30, 2));
    });
  });

  test('an answer during the fade-out rescues the session', () {
    fakeAsync((async) {
      final c = controller(async);
      async.elapse(mins(11) + const Duration(seconds: 10)); // check-in + unanswered
      expect(c.phase, SessionPhase.fadingOut);
      c.signOfLife();
      async.elapse(const Duration(seconds: 40));
      expect(c.phase, SessionPhase.listening);
      expect(target.playing, isTrue);
      expect(finished, isEmpty);
    });
  });

  test('pausing from outside ends the session at the exact position', () {
    fakeAsync((async) {
      final c = controller(async);
      async.elapse(mins(5));
      target.externalPause();
      final pausedAt = target.position;
      async.elapse(const Duration(seconds: 2));
      expect(c.phase, SessionPhase.idle);
      expect(finished.single.reason, EndReason.interrupted);
      expect(finished.single.resumePosition, pausedAt);
      expect(target.seeks, isEmpty);
    });
  });

  test('the book ending mid-session keeps the last-awake bookmark', () {
    target = FakeTarget(position: const Duration(minutes: 55), length: const Duration(minutes: 58));
    fakeAsync((async) {
      controller(async);
      async.elapse(mins(4));
      expect(finished.single.reason, EndReason.bookEnd);
      expect(finished.single.resumePosition, const Duration(minutes: 54, seconds: 30));
    });
  });

  test('max session length stops even when every check-in is answered', () {
    fakeAsync((async) {
      final c = controller(async, s: settings.copyWith(maxSessionMin: 25));
      for (var i = 0; i < 3; i++) {
        async.elapse(mins(10) + sec);
        c.signOfLife();
      }
      async.elapse(const Duration(seconds: 40));
      expect(finished.single.reason, EndReason.maxSession);
    });
  });

  test('listeners run only during check-ins and answer for the user', () {
    fakeAsync((async) {
      final voice = FakeListener(quiet: true);
      final c = controller(async, listeners: [voice]);
      expect(voice.running, isFalse);
      async.elapse(mins(10) + sec);
      expect(voice.running, isTrue);
      async.elapse(const Duration(seconds: 3));
      expect(target.volume, closeTo(SessionController.voiceCheckInVolume, 0.01));
      voice.say(Answer.awake);
      async.flushMicrotasks();
      expect(c.phase, SessionPhase.listening);
      expect(voice.running, isFalse);

      async.elapse(mins(10) + sec);
      voice.say(Answer.stop);
      async.flushMicrotasks();
      expect(finished.single.reason, EndReason.ended);
      expect(target.seeks, isEmpty, reason: '"good night" keeps the exact place');
    });
  });

  test('unavailable listeners (permission denied) are skipped', () {
    fakeAsync((async) {
      final camera = FakeListener(available: false);
      final c = controller(async, listeners: [camera]);
      expect(c.usable, isEmpty);
      async.elapse(mins(10) + sec);
      expect(camera.starts, 0);
    });
  });

  test('lock-screen skip presses count as awake', () {
    fakeAsync((async) {
      final c = controller(async);
      async.elapse(mins(10) + sec);
      target.skips.add(null);
      async.flushMicrotasks();
      expect(c.phase, SessionPhase.listening);
    });
  });

  test('checkpoints report the safe (last-awake) bookmark', () {
    fakeAsync((async) {
      final checkpoints = <Duration>[];
      final c = SessionController(target: target, settings: settings, onCheckpoint: checkpoints.add)
        ..start();
      async.elapse(mins(3));
      expect(checkpoints.last, const Duration(minutes: 59, seconds: 30));
      c.dispose();
    });
  });

  group('the microphone taking audio focus (regression: check-in ended the session)', () {
    test('a pause caused by our own listener is not "you stopped it"', () {
      fakeAsync((async) {
        // Like Spotify, or just_audio by default: pauses when the recognizer starts.
        final voice = FakeListener(quiet: true, onStart: () => target.externalPause());
        final c = controller(async, listeners: [voice]);
        async.elapse(mins(10) + sec);
        expect(voice.running, isTrue);
        expect(target.playing, isFalse);
        async.elapse(const Duration(seconds: 20));
        expect(c.phase, SessionPhase.checking, reason: 'still waiting for an answer');
        expect(finished, isEmpty);
        expect(target.answerListening, [true]);

        // Answering resumes playback.
        voice.say(Answer.awake);
        async.elapse(const Duration(seconds: 2));
        expect(c.phase, SessionPhase.listening);
        expect(target.playing, isTrue);
        expect(target.answerListening, [true, false]);
      });
    });

    test('no answer while paused by the microphone still ends as asleep', () {
      fakeAsync((async) {
        final voice = FakeListener(quiet: true, onStart: () => target.externalPause());
        controller(async, listeners: [voice]);
        async.elapse(mins(10) + sec);
        async.elapse(const Duration(seconds: 95)); // response window + fade
        expect(finished.single.reason, EndReason.noResponse);
        expect(finished.single.resumePosition, const Duration(minutes: 59, seconds: 30));
      });
    });

    test('a real pause after the grace period still ends the session', () {
      fakeAsync((async) {
        final voice = FakeListener(quiet: true, onStart: () => target.externalPause());
        final c = controller(async, listeners: [voice]);
        async.elapse(mins(10) + sec);
        voice.say(Answer.awake);
        async.elapse(SessionController.focusGrace + const Duration(seconds: 2));
        expect(target.playing, isTrue);
        target.externalPause();
        async.elapse(const Duration(seconds: 2));
        expect(c.phase, SessionPhase.idle);
        expect(finished.single.reason, EndReason.interrupted);
      });
    });
  });
}
