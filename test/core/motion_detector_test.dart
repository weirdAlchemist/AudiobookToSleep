import 'dart:typed_data';

import 'package:audiobook_to_sleep/core/motion_detector.dart';
import 'package:flutter_test/flutter_test.dart';

const w = 48;
const h = 36;

/// A flat background with an optional bright block (the "arm") at column [armX].
Uint8List frame({int base = 60, int? armX, int noise = 0, int seed = 1}) {
  final f = Uint8List(w * h);
  var s = seed;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      final n = noise > 0 ? (s % (2 * noise + 1)) - noise : 0;
      final arm = armX != null && x >= armX && x < armX + 10 && y > 6 && y < 30;
      f[y * w + x] = ((arm ? base + 90 : base) + n).clamp(0, 255);
    }
  }
  return f;
}

/// Feeds frames every 100 ms; returns the times (ms) at which a wave was reported.
List<int> run(MotionDetector d, List<Uint8List> frames) {
  final waves = <int>[];
  for (var i = 0; i < frames.length; i++) {
    if (d.push(frames[i], Duration(milliseconds: i * 100))) waves.add(i * 100);
  }
  return waves;
}

List<Uint8List> still(int n, {int noise = 0, int? armX}) =>
    List.generate(n, (i) => frame(noise: noise, armX: armX, seed: i + 1));
List<Uint8List> waving(int n) =>
    List.generate(n, (i) => frame(armX: const [4, 18, 32, 18][i % 4], seed: i + 100));

void main() {
  test('a sustained wave is detected', () {
    final waves = run(MotionDetector(), [...still(20), ...waving(15)]);
    expect(waves, hasLength(1));
    expect(waves.single, inInclusiveRange(2000, 2800));
  });

  test('a still scene with sensor noise is not a wave', () {
    expect(run(MotionDetector(), still(60, noise: 8)), isEmpty);
  });

  test('global brightness changes (auto-exposure, screen glow) are ignored', () {
    final frames = List.generate(40, (i) => frame(base: 40 + (i % 2) * 50));
    expect(run(MotionDetector(), frames), isEmpty);
  });

  test('a brief jolt, like turning over in sleep, is not a wave', () {
    expect(run(MotionDetector(), [...still(20), ...waving(3), ...still(20, armX: 30)]), isEmpty);
  });

  test('motion during camera warm-up is ignored', () {
    expect(run(MotionDetector(), [...waving(14), ...still(20)]), isEmpty);
  });

  test('continued waving does not report twice within the cooldown', () {
    final waves = run(MotionDetector(), [...still(16), ...waving(40)]);
    expect(waves, hasLength(2));
    expect(waves[1] - waves[0], greaterThanOrEqualTo(3000));
  });

  test('reports when it is too dark to see', () {
    final d = MotionDetector()..push(frame(base: 3), Duration.zero);
    expect(d.tooDark, isTrue);
    d.push(frame(base: 80), const Duration(milliseconds: 100));
    expect(d.tooDark, isFalse);
  });
}
