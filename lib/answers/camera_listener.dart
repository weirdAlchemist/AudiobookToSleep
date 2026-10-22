// Answer "still awake?" by waving at the front camera. The camera runs only
// during a check-in and the fade-out; frames are shrunk to a tiny grey grid
// and analysed on the device, never stored or sent anywhere.

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../core/frame_sampling.dart';
import '../core/motion_detector.dart';
import '../session/answer_listener.dart';

class CameraListener extends AnswerListener {
  final _answers = StreamController<Answer>.broadcast();
  final MotionDetector _detector = MotionDetector();
  final Stopwatch _clock = Stopwatch()..start();
  final ValueNotifier<String?> _note = ValueNotifier(null);

  /// The running camera, for a small preview on the night screen.
  final ValueNotifier<CameraController?> controller = ValueNotifier(null);

  /// True while the latest frames show movement (preview highlight).
  final ValueNotifier<bool> moving = ValueNotifier(false);

  CameraDescription? _camera;
  bool _wanted = false;
  bool _busy = false;
  Duration _lastSample = Duration.zero;

  @override
  String get hint => 'wave at the phone';

  @override
  Stream<Answer> get answers => _answers.stream;

  @override
  ValueListenable<String?> get note => _note;

  @override
  Future<bool> prepare() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;
      _camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      // Opening it once asks for camera permission while the user is looking.
      final probe = CameraController(_camera!, ResolutionPreset.low, enableAudio: false);
      await probe.initialize();
      await probe.dispose();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> start() async {
    final camera = _camera;
    if (camera == null || _wanted) return;
    _wanted = true;
    _detector.reset();
    final c = CameraController(
      camera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup:
          defaultTargetPlatform == TargetPlatform.iOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );
    try {
      await c.initialize();
      if (!_wanted) {
        await c.dispose();
        return;
      }
      controller.value = c;
      await c.startImageStream(_onFrame);
    } catch (_) {
      _wanted = false;
      controller.value = null;
      await c.dispose();
    }
  }

  @override
  Future<void> stop() async {
    _wanted = false;
    final c = controller.value;
    controller.value = null;
    _note.value = null;
    moving.value = false;
    if (c != null) {
      try {
        if (c.value.isStreamingImages) await c.stopImageStream();
      } catch (_) {}
      await c.dispose();
    }
  }

  void _onFrame(CameraImage image) {
    // About 10 samples a second is plenty, and keeps the CPU (and phone) cool.
    final now = _clock.elapsed;
    if (_busy || now - _lastSample < const Duration(milliseconds: 100)) return;
    _busy = true;
    _lastSample = now;
    try {
      final plane = image.planes.first;
      final frame = downsampleLuma(
        bytes: plane.bytes,
        width: image.width,
        height: image.height,
        bytesPerRow: plane.bytesPerRow,
        bytesPerPixel: plane.bytesPerPixel ?? 1,
      );
      final waved = _detector.push(frame, now);
      moving.value = _detector.moving;
      _note.value = _detector.tooDark ? 'Too dark for the camera to see you' : null;
      if (waved) _answers.add(Answer.awake);
    } finally {
      _busy = false;
    }
  }
}
