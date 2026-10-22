// Ways to answer "still awake?" without touching the phone: voice, camera.
// Listeners run only while a check-in (or the fade-out) is waiting.

import 'dart:async';

import 'package:flutter/foundation.dart';

enum Answer { awake, stop }

abstract class AnswerListener {
  /// Short label for hints, e.g. 'say "I\'m awake"'.
  String get hint;

  /// Check-ins dip the book further so this listener can hear the user.
  bool get wantsQuietCheckIn => false;

  /// Called when a session starts, while the user is looking at the screen,
  /// so permission prompts appear then. Returns false if unavailable.
  Future<bool> prepare();

  Future<void> start();
  Future<void> stop();

  Stream<Answer> get answers;

  /// Optional live note for the night screen, e.g. "Too dark for the camera".
  ValueListenable<String?> get note => _noNote;
}

final ValueNotifier<String?> _noNote = ValueNotifier(null);
