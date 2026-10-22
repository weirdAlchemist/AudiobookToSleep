import 'dart:typed_data';

/// Shrinks a camera frame to a small grayscale grid by averaging blocks.
///
/// Android delivers YUV420, whose first plane is already luminance
/// (`bytesPerPixel` 1). iOS delivers BGRA8888 (`bytesPerPixel` 4), which is
/// converted to luminance here.
Uint8List downsampleLuma({
  required Uint8List bytes,
  required int width,
  required int height,
  required int bytesPerRow,
  int bytesPerPixel = 1,
  int outWidth = 48,
  int outHeight = 36,
}) {
  final out = Uint8List(outWidth * outHeight);
  final blockW = width / outWidth;
  final blockH = height / outHeight;
  // Sample a few pixels per block rather than all of them: plenty for motion.
  const samples = 3;
  for (var oy = 0; oy < outHeight; oy++) {
    for (var ox = 0; ox < outWidth; ox++) {
      var sum = 0;
      for (var sy = 0; sy < samples; sy++) {
        final y = ((oy + (sy + 0.5) / samples) * blockH).floor().clamp(0, height - 1);
        for (var sx = 0; sx < samples; sx++) {
          final x = ((ox + (sx + 0.5) / samples) * blockW).floor().clamp(0, width - 1);
          final i = y * bytesPerRow + x * bytesPerPixel;
          if (bytesPerPixel >= 3) {
            // BGRA
            sum += (bytes[i + 2] * 77 + bytes[i + 1] * 150 + bytes[i] * 29) >> 8;
          } else {
            sum += bytes[i];
          }
        }
      }
      out[oy * outWidth + ox] = sum ~/ (samples * samples);
    }
  }
  return out;
}
