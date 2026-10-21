import { test } from 'node:test';
import assert from 'node:assert/strict';
import { MotionDetector } from '../js/motion-detector.js';

const W = 48;
const H = 36;

// A flat background with an optional bright block (the "arm") at column x.
function frame({ base = 60, armX = null, noise = 0, seed = 1 } = {}) {
  const f = new Uint8Array(W * H);
  let s = seed;
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      const n = noise ? ((s % (2 * noise + 1)) - noise) : 0;
      const arm = armX != null && x >= armX && x < armX + 10 && y > 6 && y < 30;
      f[y * W + x] = Math.max(0, Math.min(255, (arm ? base + 90 : base) + n));
    }
  }
  return f;
}

// Feed frames every 100 ms; returns the times at which a wave was reported.
function run(detector, frames, start = 0) {
  const waves = [];
  frames.forEach((f, i) => {
    const t = start + i * 100;
    if (detector.push(f, t)) waves.push(t);
  });
  return waves;
}

const still = (n, opts) => Array.from({ length: n }, (_, i) => frame({ ...opts, seed: i + 1 }));
const waving = (n, opts) => Array.from({ length: n }, (_, i) =>
  frame({ ...opts, armX: [4, 18, 32, 18][i % 4], seed: i + 100 }));

test('a sustained wave is detected', () => {
  const d = new MotionDetector();
  const waves = run(d, [...still(20), ...waving(15)]);
  assert.equal(waves.length, 1);
  assert.ok(waves[0] >= 2000 && waves[0] <= 2800, `detected at ${waves[0]}`);
});

test('a still scene with sensor noise is not a wave', () => {
  const d = new MotionDetector();
  assert.deepEqual(run(d, still(60, { noise: 8 })), []);
});

test('global brightness changes (auto-exposure, screen glow) are ignored', () => {
  const d = new MotionDetector();
  const frames = Array.from({ length: 40 }, (_, i) => frame({ base: 40 + (i % 2) * 50 }));
  assert.deepEqual(run(d, frames), []);
});

test('a brief jolt, like turning over in sleep, is not a wave', () => {
  const d = new MotionDetector();
  const frames = [...still(20), ...waving(3), ...still(20, { armX: 30 })];
  assert.deepEqual(run(d, frames), []);
});

test('motion during camera warm-up is ignored', () => {
  const d = new MotionDetector();
  assert.deepEqual(run(d, [...waving(14), ...still(20)]), []);
});

test('keeps waving does not report twice within the cooldown', () => {
  const d = new MotionDetector();
  const waves = run(d, [...still(16), ...waving(40)]);
  assert.equal(waves.length, 2);
  assert.ok(waves[1] - waves[0] >= 3000);
});

test('reports when it is too dark to see', () => {
  const d = new MotionDetector();
  d.push(frame({ base: 3 }), 0);
  assert.equal(d.tooDark, true);
  d.push(frame({ base: 80 }), 100);
  assert.equal(d.tooDark, false);
});
