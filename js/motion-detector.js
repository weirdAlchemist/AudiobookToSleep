// Spots a deliberate wave in a stream of small grayscale camera frames.
//
// Frames are compared pairwise. A pixel counts as changed when it differs
// from the previous frame by more than a threshold *after* removing each
// frame's mean brightness, so auto-exposure and the phone screen changing
// brightness don't look like motion. A wave is sustained motion: most of the
// samples within a ~1.2 s window must be moving. A sleeper turning over gives
// a short burst instead and is ignored.
//
// Pure logic (no DOM) so it can be tested with synthetic frames.

export const MOTION_DEFAULTS = Object.freeze({
  pixelThreshold: 22,    // grey levels (0-255) a pixel must change by
  minChangedFraction: 0.04, // share of pixels that must change for a "moving" sample
  windowMs: 1200,        // how far back to look for sustained motion
  minMovingShare: 0.6,   // share of samples in the window that must be moving
  minSamples: 6,         // at least this many samples in the window
  warmupMs: 1500,        // ignore frames while the camera settles exposure
  cooldownMs: 3000,      // after a wave, wait before reporting another
  darkLevel: 12,         // mean brightness below this is "too dark to see"
});

export class MotionDetector {
  constructor(options = {}) {
    this.options = { ...MOTION_DEFAULTS, ...options };
    this.reset();
  }

  reset() {
    this.previous = null;
    this.previousMean = 0;
    this.startedAt = null;
    this.samples = []; // { t, moving }
    this.lastWaveAt = -Infinity;
    this.brightness = null;
    this.lastChangedFraction = 0;
  }

  get tooDark() {
    return this.brightness != null && this.brightness < this.options.darkLevel;
  }

  // frame: grayscale pixel values (Uint8Array/Uint8ClampedArray), same size each time.
  // Returns true when this frame completes a wave.
  push(frame, t) {
    const o = this.options;
    this.startedAt ??= t;
    const mean = average(frame);
    this.brightness = mean;

    const previous = this.previous;
    const previousMean = this.previousMean;
    this.previous = Uint8Array.from(frame);
    this.previousMean = mean;
    if (!previous || t - this.startedAt < o.warmupMs) return false;

    let changed = 0;
    for (let i = 0; i < frame.length; i++) {
      if (Math.abs((frame[i] - mean) - (previous[i] - previousMean)) > o.pixelThreshold) changed++;
    }
    this.lastChangedFraction = changed / frame.length;
    this.samples.push({ t, moving: this.lastChangedFraction >= o.minChangedFraction });
    while (this.samples.length && this.samples[0].t < t - o.windowMs) this.samples.shift();

    if (t - this.lastWaveAt < o.cooldownMs) return false;
    const moving = this.samples.filter((s) => s.moving).length;
    if (this.samples.length >= o.minSamples && moving / this.samples.length >= o.minMovingShare) {
      this.lastWaveAt = t;
      this.samples = [];
      return true;
    }
    return false;
  }
}

function average(frame) {
  let sum = 0;
  for (let i = 0; i < frame.length; i++) sum += frame[i];
  return frame.length ? sum / frame.length : 0;
}
