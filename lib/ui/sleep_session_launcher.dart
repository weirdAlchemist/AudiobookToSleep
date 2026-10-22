// Wires a playback target, the user's settings and the answer listeners into
// a SessionController, and shows the night screen.

import 'package:flutter/material.dart';

import '../answers/camera_listener.dart';
import '../answers/voice_listener.dart';
import '../app_services.dart';
import '../audio/book_target.dart';
import '../session/answer_listener.dart';
import '../session/night_record.dart';
import '../session/playback_target.dart';
import '../session/session_controller.dart';
import 'night_screen.dart';

Future<NightRecord?> runSleepSession(BuildContext context, PlaybackTarget target) async {
  final services = AppServices.instance;
  final settings = services.settings;
  final camera = settings.cameraEnabled ? CameraListener() : null;
  final listeners = <AnswerListener>[
    if (settings.voiceEnabled) VoiceListener(),
    ?camera,
  ];

  var lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  final book = target is BookTarget ? target.book : null;
  final controller = SessionController(
    target: target,
    settings: settings,
    listeners: listeners,
    onCheckpoint: (safe) {
      // If the app is killed overnight, the last-awake bookmark survives.
      if (book == null || DateTime.now().difference(lastSave).inSeconds < 15) return;
      lastSave = DateTime.now();
      book.position = safe;
      services.library.save();
    },
    onFinished: (record) async {
      await services.nights.add(record);
      if (book != null) {
        book
          ..position = record.resumePosition
          ..lastPlayedAt = DateTime.now();
        await services.library.save();
      }
    },
  );

  if (target is BookTarget) target.handler.skipsSignalAwake = true;
  final started = controller.start();
  if (!context.mounted) return null;
  await Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => NightScreen(
      controller: controller,
      camera: camera,
      started: started,
      keepScreenOn: settings.keepScreenOn,
    ),
  ));
  if (target is BookTarget) target.handler.skipsSignalAwake = false;
  final result = controller.result;
  controller.dispose();
  return result;
}
