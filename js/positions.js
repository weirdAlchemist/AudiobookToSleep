// A book may span several audio files. The app tracks one "global" position in
// seconds across the whole book and converts to (track, time) for playback.

export function totalDuration(durations) {
  return durations.reduce((sum, d) => sum + d, 0);
}

export function toGlobal(durations, track, time) {
  let offset = 0;
  for (let i = 0; i < track && i < durations.length; i++) offset += durations[i];
  return offset + time;
}

export function fromGlobal(durations, seconds) {
  let remaining = Math.max(0, seconds);
  for (let i = 0; i < durations.length; i++) {
    if (remaining < durations[i]) return { track: i, time: remaining };
    remaining -= durations[i];
  }
  // Past the end: park at the very end of the last track.
  const last = durations.length - 1;
  return { track: Math.max(0, last), time: last >= 0 ? durations[last] : 0 };
}

export function formatTime(seconds) {
  const s = Math.max(0, Math.floor(seconds));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = String(s % 60).padStart(2, '0');
  return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${sec}` : `${m}:${sec}`;
}
