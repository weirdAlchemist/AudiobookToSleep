// Decides when the listener has fallen asleep.
//
// The detector never measures sleep directly. Instead it periodically asks
// "still awake?" (the app dips the volume and shows a prompt). Any sign of
// life — a tap, a media button press — resets the clock. If a check-in goes
// unanswered, we assume the listener drifted off somewhere after the last
// moment we *knew* they were awake, so that is where the bookmark goes.
//
// Time and position are injected so the logic is deterministic and testable.

export const DEFAULT_SETTINGS = Object.freeze({
  checkInIntervalMin: 10, // minutes between "still awake?" checks
  responseWindowSec: 60,  // how long a check-in waits for an answer
  maxSessionMin: 120,     // hard stop, even if the listener keeps answering
  rewindSec: 30,          // extra rewind before the last awake position
});

export class SleepDetector {
  constructor(settings = {}) {
    this.settings = { ...DEFAULT_SETTINGS, ...settings };
    this.state = 'idle'; // idle | listening | checking | asleep
    this.startedAt = null;
    this.lastAwakeAt = null;
    this.lastAwakePosition = null;
    this.checkInStartedAt = null;
  }

  get active() {
    return this.state === 'listening' || this.state === 'checking';
  }

  start(now, position) {
    this.state = 'listening';
    this.startedAt = now;
    this.lastAwakeAt = now;
    this.lastAwakePosition = position;
    this.checkInStartedAt = null;
  }

  // Any sign the listener is awake. Returns an event if it answered a check-in.
  markAwake(now, position) {
    if (!this.active) return null;
    const answeredCheckIn = this.state === 'checking';
    this.state = 'listening';
    this.lastAwakeAt = now;
    this.lastAwakePosition = position;
    this.checkInStartedAt = null;
    return answeredCheckIn ? { type: 'awake-confirmed' } : null;
  }

  // Call often (timers get throttled in the background, so ticks may be late;
  // all decisions are based on elapsed wall-clock time, not tick counts).
  tick(now) {
    const s = this.settings;
    if (this.state === 'listening') {
      if (now - this.startedAt >= s.maxSessionMin * 60_000) {
        return this.#fallAsleep('max-session');
      }
      if (now - this.lastAwakeAt >= s.checkInIntervalMin * 60_000) {
        this.state = 'checking';
        this.checkInStartedAt = now;
        return { type: 'check-in' };
      }
    } else if (this.state === 'checking') {
      if (now - this.checkInStartedAt >= s.responseWindowSec * 1000) {
        return this.#fallAsleep('no-response');
      }
    }
    return null;
  }

  // Where to resume next time if the session ended right now.
  get resumePosition() {
    if (this.lastAwakePosition == null) return null;
    return Math.max(0, this.lastAwakePosition - this.settings.rewindSec);
  }

  // Milliseconds until the next state change, for countdown displays.
  msUntilNext(now) {
    const s = this.settings;
    if (this.state === 'listening') {
      const checkIn = this.lastAwakeAt + s.checkInIntervalMin * 60_000;
      const max = this.startedAt + s.maxSessionMin * 60_000;
      return Math.max(0, Math.min(checkIn, max) - now);
    }
    if (this.state === 'checking') {
      return Math.max(0, this.checkInStartedAt + s.responseWindowSec * 1000 - now);
    }
    return null;
  }

  // The listener stirred while the book was fading out after an unanswered
  // check-in: go back to listening without restarting the session clock.
  wake(now, position) {
    if (this.state !== 'asleep') return false;
    this.state = 'listening';
    this.lastAwakeAt = now;
    this.lastAwakePosition = position;
    this.checkInStartedAt = null;
    return true;
  }

  stop() {
    this.state = 'idle';
    this.checkInStartedAt = null;
  }

  #fallAsleep(reason) {
    this.state = 'asleep';
    return {
      type: 'asleep',
      reason,
      fellAsleepAfter: this.lastAwakeAt,
      resumePosition: this.resumePosition,
    };
  }
}
