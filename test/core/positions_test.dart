import 'package:audiobook_to_sleep/core/positions.dart';
import 'package:flutter_test/flutter_test.dart';

Duration s(int seconds) => Duration(seconds: seconds);

void main() {
  final durations = [s(100), s(200), s(50)];

  test('maps global position to track and back', () {
    expect(fromGlobal(durations, s(0)), (track: 0, offset: s(0)));
    expect(fromGlobal(durations, s(99)), (track: 0, offset: s(99)));
    expect(fromGlobal(durations, s(100)), (track: 1, offset: s(0)));
    expect(fromGlobal(durations, s(320)), (track: 2, offset: s(20)));
    expect(toGlobal(durations, 2, s(20)), s(320));
    expect(toGlobal(durations, 0, s(5)), s(5));
  });

  test('clamps out-of-range positions', () {
    expect(fromGlobal(durations, s(-5)), (track: 0, offset: s(0)));
    expect(fromGlobal(durations, s(9999)), (track: 2, offset: s(50)));
    expect(fromGlobal(const [], s(10)), (track: 0, offset: s(0)));
    expect(totalDuration(durations), s(350));
  });

  test('formats durations', () {
    expect(formatDuration(s(0)), '0:00');
    expect(formatDuration(const Duration(milliseconds: 65900)), '1:05');
    expect(formatDuration(s(3 * 3600 + 12 * 60 + 5)), '3:12:05');
  });
}
