// A book may span several audio files. The app tracks one position across the
// whole book and converts to (track, offset) for playback.

typedef TrackPosition = ({int track, Duration offset});

Duration totalDuration(List<Duration> durations) =>
    durations.fold(Duration.zero, (sum, d) => sum + d);

Duration toGlobal(List<Duration> durations, int track, Duration offset) {
  var total = Duration.zero;
  for (var i = 0; i < track && i < durations.length; i++) {
    total += durations[i];
  }
  return total + offset;
}

TrackPosition fromGlobal(List<Duration> durations, Duration position) {
  var remaining = position.isNegative ? Duration.zero : position;
  for (var i = 0; i < durations.length; i++) {
    if (remaining < durations[i]) return (track: i, offset: remaining);
    remaining -= durations[i];
  }
  // Past the end: park at the very end of the last track.
  if (durations.isEmpty) return (track: 0, offset: Duration.zero);
  return (track: durations.length - 1, offset: durations.last);
}

String formatDuration(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
}
