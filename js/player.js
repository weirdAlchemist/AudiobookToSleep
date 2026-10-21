// Wraps a single <audio> element and plays a multi-file book as one timeline.

import { fromGlobal, toGlobal, totalDuration } from './positions.js';
import { getTrackBlob } from './library.js';

export class BookPlayer extends EventTarget {
  constructor(audio) {
    super();
    this.audio = audio;
    this.book = null;
    this.trackIndex = 0;
    this.url = null;
    this.fadeTimer = null;
    this.fadeResolve = null;
    audio.addEventListener('ended', () => this.#nextTrack());
  }

  get durations() {
    return this.book ? this.book.tracks.map((t) => t.duration) : [];
  }

  get duration() {
    return totalDuration(this.durations);
  }

  get position() {
    if (!this.book) return 0;
    return toGlobal(this.durations, this.trackIndex, this.audio.currentTime || 0);
  }

  get playing() {
    return !this.audio.paused;
  }

  async load(book) {
    this.pause();
    this.book = book;
    await this.seek(book.position ?? 0, { force: true });
  }

  async seek(seconds, { force = false } = {}) {
    const clamped = Math.min(Math.max(0, seconds), this.duration);
    const { track, time } = fromGlobal(this.durations, clamped);
    if (force || track !== this.trackIndex || !this.url) await this.#loadTrack(track);
    await this.#whenReady();
    this.audio.currentTime = time;
  }

  async play() {
    await this.audio.play();
  }

  pause() {
    this.audio.pause();
  }

  // Ramp volume linearly. Resolves true when finished, or false if another
  // fade replaced this one before it completed.
  fadeTo(target, ms) {
    clearInterval(this.fadeTimer);
    this.fadeResolve?.(false);
    const start = this.audio.volume;
    const startedAt = performance.now();
    return new Promise((resolve) => {
      this.fadeResolve = resolve;
      const finish = () => {
        clearInterval(this.fadeTimer);
        this.audio.volume = target;
        this.fadeResolve = null;
        resolve(true);
      };
      if (ms <= 0) { finish(); return; }
      this.fadeTimer = setInterval(() => {
        const t = Math.min(1, (performance.now() - startedAt) / ms);
        if (t >= 1) finish();
        else this.audio.volume = start + (target - start) * t;
      }, 100);
    });
  }

  async #loadTrack(index) {
    const blob = await getTrackBlob(this.book.id, index);
    if (!blob) throw new Error(`Missing audio for track ${index + 1}`);
    if (this.url) URL.revokeObjectURL(this.url);
    this.trackIndex = index;
    this.url = URL.createObjectURL(blob);
    this.audio.src = this.url;
    this.dispatchEvent(new Event('trackchange'));
  }

  #whenReady() {
    if (this.audio.readyState >= 1) return Promise.resolve();
    return new Promise((resolve, reject) => {
      const ok = () => { cleanup(); resolve(); };
      const fail = () => { cleanup(); reject(this.audio.error); };
      const cleanup = () => {
        this.audio.removeEventListener('loadedmetadata', ok);
        this.audio.removeEventListener('error', fail);
      };
      this.audio.addEventListener('loadedmetadata', ok);
      this.audio.addEventListener('error', fail);
    });
  }

  async #nextTrack() {
    if (this.trackIndex + 1 >= this.book.tracks.length) {
      this.dispatchEvent(new Event('bookend'));
      return;
    }
    await this.#loadTrack(this.trackIndex + 1);
    await this.#whenReady();
    await this.audio.play();
  }
}
