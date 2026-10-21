// Wave at the phone to answer "still awake?". Like voice, the camera only runs
// during a check-in and the fade-out; frames are analysed on the device and
// never stored or sent anywhere.

import { MotionDetector } from './motion-detector.js';

const WIDTH = 48;
const HEIGHT = 36;
const SAMPLE_MS = 100;

export const cameraSupported = Boolean(navigator.mediaDevices?.getUserMedia);

const CONSTRAINTS = {
  audio: false,
  video: { facingMode: 'user', width: { ideal: 320 }, height: { ideal: 240 }, frameRate: { ideal: 15 } },
};

// Ask while the user is looking at the screen (see requestMicPermission).
export async function requestCameraPermission() {
  if (!cameraSupported) return false;
  try {
    const stream = await navigator.mediaDevices.getUserMedia(CONSTRAINTS);
    stream.getTracks().forEach((t) => t.stop());
    return true;
  } catch {
    return false;
  }
}

export class CameraWatcher {
  // video: a <video> element used both for capture and as a small preview.
  constructor(video, { onWave, onError = () => {}, onStatus = () => {} }) {
    this.video = video;
    this.onWave = onWave;
    this.onError = onError;
    this.onStatus = onStatus; // ({ tooDark, moving }) about 10x a second
    this.detector = new MotionDetector();
    this.canvas = document.createElement('canvas');
    this.canvas.width = WIDTH;
    this.canvas.height = HEIGHT;
    this.ctx = this.canvas.getContext('2d', { willReadFrequently: true });
    this.stream = null;
    this.timer = null;
    this.wanted = false;
  }

  async start() {
    if (this.wanted) return;
    this.wanted = true;
    this.detector.reset();
    let stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia(CONSTRAINTS);
    } catch (err) {
      this.wanted = false;
      this.onError(err.name || err.message);
      return;
    }
    if (!this.wanted) { // stopped while the camera was opening
      stream.getTracks().forEach((t) => t.stop());
      return;
    }
    this.stream = stream;
    this.video.srcObject = stream;
    this.video.play().catch(() => {});
    this.timer = setInterval(() => this.#sample(), SAMPLE_MS);
  }

  stop() {
    this.wanted = false;
    clearInterval(this.timer);
    this.timer = null;
    this.stream?.getTracks().forEach((t) => t.stop());
    this.stream = null;
    this.video.srcObject = null;
  }

  #sample() {
    if (this.video.readyState < 2) return;
    this.ctx.drawImage(this.video, 0, 0, WIDTH, HEIGHT);
    const { data } = this.ctx.getImageData(0, 0, WIDTH, HEIGHT);
    const gray = new Uint8Array(WIDTH * HEIGHT);
    for (let i = 0, p = 0; i < gray.length; i++, p += 4) {
      gray[i] = (data[p] * 77 + data[p + 1] * 150 + data[p + 2] * 29) >> 8;
    }
    const waved = this.detector.push(gray, performance.now());
    this.onStatus({
      tooDark: this.detector.tooDark,
      moving: this.detector.lastChangedFraction >= this.detector.options.minChangedFraction,
    });
    if (waved) this.onWave();
  }
}
