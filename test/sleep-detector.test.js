import { test } from 'node:test';
import assert from 'node:assert/strict';
import { SleepDetector } from '../js/sleep-detector.js';

const MIN = 60_000;
const SEC = 1000;
const settings = { checkInIntervalMin: 10, responseWindowSec: 60, maxSessionMin: 120, rewindSec: 30 };

test('checks in after the interval and falls asleep if unanswered', () => {
  const d = new SleepDetector(settings);
  d.start(0, 1000);
  assert.equal(d.tick(9 * MIN), null);
  assert.deepEqual(d.tick(10 * MIN), { type: 'check-in' });
  assert.equal(d.state, 'checking');
  assert.equal(d.tick(10 * MIN + 59 * SEC), null);
  const event = d.tick(11 * MIN);
  assert.equal(event.type, 'asleep');
  assert.equal(event.reason, 'no-response');
  // Bookmark goes to where we last knew they were awake, minus the rewind.
  assert.equal(event.resumePosition, 970);
});

test('answering a check-in moves the awake mark and restarts the interval', () => {
  const d = new SleepDetector(settings);
  d.start(0, 0);
  d.tick(10 * MIN);
  assert.deepEqual(d.markAwake(10 * MIN + 5 * SEC, 605), { type: 'awake-confirmed' });
  assert.equal(d.state, 'listening');
  assert.equal(d.tick(19 * MIN), null);
  assert.deepEqual(d.tick(20 * MIN + 5 * SEC), { type: 'check-in' });
  const event = d.tick(21 * MIN + 5 * SEC);
  assert.equal(event.resumePosition, 575);
});

test('activity between check-ins postpones the next one', () => {
  const d = new SleepDetector(settings);
  d.start(0, 0);
  assert.equal(d.markAwake(8 * MIN, 480), null);
  assert.equal(d.tick(10 * MIN), null);
  assert.deepEqual(d.tick(18 * MIN), { type: 'check-in' });
});

test('stops at the max session length even if the listener keeps answering', () => {
  const d = new SleepDetector({ ...settings, maxSessionMin: 25 });
  d.start(0, 0);
  d.markAwake(9 * MIN, 540);
  d.markAwake(18 * MIN, 1080);
  const event = d.tick(25 * MIN);
  assert.equal(event.reason, 'max-session');
  assert.equal(event.resumePosition, 1050);
});

test('late ticks (throttled background timers) still give a full response window', () => {
  const d = new SleepDetector(settings);
  d.start(0, 0);
  // First tick arrives 30 minutes late: we ask now rather than declaring sleep.
  assert.deepEqual(d.tick(40 * MIN), { type: 'check-in' });
  assert.equal(d.tick(40 * MIN + 30 * SEC), null);
  assert.equal(d.tick(41 * MIN).type, 'asleep');
});

test('resume position never goes below zero', () => {
  const d = new SleepDetector(settings);
  d.start(0, 10);
  d.tick(10 * MIN);
  assert.equal(d.tick(11 * MIN).resumePosition, 0);
});

test('wake() during the fade-out resumes listening without resetting the session clock', () => {
  const d = new SleepDetector({ ...settings, maxSessionMin: 30 });
  d.start(0, 0);
  d.tick(10 * MIN);
  d.tick(11 * MIN);
  assert.equal(d.state, 'asleep');
  assert.equal(d.markAwake(11 * MIN + 5 * SEC, 665), null, 'markAwake is ignored once asleep');
  assert.equal(d.wake(11 * MIN + 5 * SEC, 665), true);
  assert.equal(d.state, 'listening');
  assert.equal(d.tick(30 * MIN).reason, 'max-session');
});

test('msUntilNext counts down to whichever comes first', () => {
  const d = new SleepDetector({ ...settings, maxSessionMin: 15 });
  d.start(0, 0);
  assert.equal(d.msUntilNext(2 * MIN), 8 * MIN);
  d.markAwake(9 * MIN, 0);
  assert.equal(d.msUntilNext(9 * MIN), 6 * MIN, 'max session is sooner than next check-in');
  d.stop();
  assert.equal(d.msUntilNext(9 * MIN), null);
});
