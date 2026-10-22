// Spots a deliberate wave in a stream of small grayscale camera frames.
//
// Frames are compared pairwise. A pixel counts as changed when it differs
// from the previous frame by more than a threshold *after* removing each
// frame's mean brightness, so auto-exposure and the phone screen changing
// brightness don't look like motion. A wave is sustained motion: most of the
// samples within a ~1.2 s window must be moving. A sleeper turning over gives
// a short burst instead and is ignored.

import 'dart:typed_data';

class MotionOptions {
  const MotionOptions({
    this.pixelThreshold = 22,
    this.minChangedFraction = 0.04,
    this.window = const Duration(milliseconds: 1200),
    this.minMovingShare = 0.6,
    this.minSamples = 6,
    this.warmup = const Duration(milliseconds: 1500),
    this.cooldown = const Duration(seconds: 3),
    this.darkLevel = 12,
  });

  /// Grey levels (0-255) a pixel must change by.
  final int pixelThreshold;

  /// Share of pixels that must change for a "moving" sample.
  final double minChangedFraction;

  /// How far back to look for sustained motion.
  final Duration window;

  /// Share of samples in the window that must be moving.
  final double minMovingShare;

  /// At least this many samples in the window.
  final int minSamples;

  /// Ignore frames while the camera settles exposure.
  final Duration warmup;

  /// After a wave, wait before reporting another.
  final Duration cooldown;

  /// Mean brightness below this is "too dark to see".
  final double darkLevel;
}

class MotionDetector {
  MotionDetector([this.options = const MotionOptions()]);

  final MotionOptions options;

  Uint8List? _previous;
  double _previousMean = 0;
  Duration? _startedAt;
  final List<(Duration, bool)> _samples = [];
  Duration? _lastWaveAt;

  /// Mean brightness of the latest frame.
  double? brightness;
  double lastChangedFraction = 0;

  bool get tooDark => brightness != null && brightness! < options.darkLevel;
  bool get moving => lastChangedFraction >= options.minChangedFraction;

  void reset() {
    _previous = null;
    _previousMean = 0;
    _startedAt = null;
    _samples.clear();
    _lastWaveAt = null;
    brightness = null;
    lastChangedFraction = 0;
  }

  /// [frame] holds grayscale pixel values, the same size every time; [t] is a
  /// monotonic timestamp. Returns true when this frame completes a wave.
  bool push(Uint8List frame, Duration t) {
    final o = options;
    _startedAt ??= t;
    final mean = _average(frame);
    brightness = mean;

    final previous = _previous;
    final previousMean = _previousMean;
    _previous = Uint8List.fromList(frame);
    _previousMean = mean;
    if (previous == null || previous.length != frame.length || t - _startedAt! < o.warmup) {
      return false;
    }

    var changed = 0;
    for (var i = 0; i < frame.length; i++) {
      if (((frame[i] - mean) - (previous[i] - previousMean)).abs() > o.pixelThreshold) changed++;
    }
    lastChangedFraction = changed / frame.length;
    _samples.add((t, moving));
    _samples.removeWhere((s) => s.$1 < t - o.window);

    if (_lastWaveAt != null && t - _lastWaveAt! < o.cooldown) return false;
    final movingCount = _samples.where((s) => s.$2).length;
    if (_samples.length >= o.minSamples && movingCount / _samples.length >= o.minMovingShare) {
      _lastWaveAt = t;
      _samples.clear();
      return true;
    }
    return false;
  }
}

double _average(Uint8List frame) {
  if (frame.isEmpty) return 0;
  var sum = 0;
  for (final v in frame) {
    sum += v;
  }
  return sum / frame.length;
}
