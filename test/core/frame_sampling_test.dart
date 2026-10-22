import 'dart:typed_data';

import 'package:audiobook_to_sleep/core/frame_sampling.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('averages a luminance plane with row padding', () {
    const w = 96, h = 72, stride = 100;
    final bytes = Uint8List(stride * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        bytes[y * stride + x] = x < w / 2 ? 20 : 200; // left dark, right bright
      }
      for (var x = w; x < stride; x++) {
        bytes[y * stride + x] = 255; // padding must be ignored
      }
    }
    final out = downsampleLuma(bytes: bytes, width: w, height: h, bytesPerRow: stride);
    expect(out.length, 48 * 36);
    expect(out[0], 20);
    expect(out[47], 200);
    expect(out[35 * 48 + 10], 20);
  });

  test('converts BGRA to luminance', () {
    const w = 48, h = 36;
    final bytes = Uint8List(w * h * 4);
    for (var i = 0; i < w * h; i++) {
      bytes[i * 4] = 0; // B
      bytes[i * 4 + 1] = 255; // G
      bytes[i * 4 + 2] = 0; // R
      bytes[i * 4 + 3] = 255; // A
    }
    final out = downsampleLuma(bytes: bytes, width: w, height: h, bytesPerRow: w * 4, bytesPerPixel: 4);
    expect(out.every((v) => v == (255 * 150) >> 8), isTrue);
  });
}
