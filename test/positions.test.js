import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fromGlobal, toGlobal, formatTime, totalDuration } from '../js/positions.js';

const durations = [100, 200, 50];

test('maps global seconds to track and back', () => {
  assert.deepEqual(fromGlobal(durations, 0), { track: 0, time: 0 });
  assert.deepEqual(fromGlobal(durations, 99), { track: 0, time: 99 });
  assert.deepEqual(fromGlobal(durations, 100), { track: 1, time: 0 });
  assert.deepEqual(fromGlobal(durations, 320), { track: 2, time: 20 });
  assert.equal(toGlobal(durations, 2, 20), 320);
  assert.equal(toGlobal(durations, 0, 5), 5);
});

test('clamps out-of-range positions', () => {
  assert.deepEqual(fromGlobal(durations, -5), { track: 0, time: 0 });
  assert.deepEqual(fromGlobal(durations, 9999), { track: 2, time: 50 });
  assert.deepEqual(fromGlobal([], 10), { track: 0, time: 0 });
  assert.equal(totalDuration(durations), 350);
});

test('formats times', () => {
  assert.equal(formatTime(0), '0:00');
  assert.equal(formatTime(65.9), '1:05');
  assert.equal(formatTime(3 * 3600 + 12 * 60 + 5), '3:12:05');
});
