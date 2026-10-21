// Voice answers to "still awake?", for when the phone is out of reach.
//
// The microphone also hears the audiobook, so we only listen while a check-in
// (or the fade-out) is in progress, and only accept short utterances that
// contain a known phrase. Narration arrives as long sentences and is ignored.

// Distinctive phrases only: single words like "yes" or "stop" are everywhere in
// narration, and a false "awake" would keep the book playing.
const AWAKE_PHRASES = [
  "i'm awake", 'im awake', 'awake', 'still here', "i'm here", "i'm listening",
  'keep going', 'keep playing', 'continue',
];
const STOP_PHRASES = ['good night', 'goodnight', 'stop playing', 'stop the book'];
const MAX_WORDS = 4;

export function matchCommand(transcript) {
  const text = transcript.toLowerCase().replace(/[’]/g, "'").replace(/[^a-z' ]/g, ' ')
    .replace(/\s+/g, ' ').trim();
  if (!text || text.split(' ').length > MAX_WORDS) return null;
  const has = (phrase) => ` ${text} `.includes(` ${phrase} `);
  // Stop wins: "I'm awake... good night" means stop now.
  if (STOP_PHRASES.some(has)) return 'stop';
  if (AWAKE_PHRASES.some(has)) return 'awake';
  return null;
}

const Recognition = globalThis.SpeechRecognition ?? globalThis.webkitSpeechRecognition;

export const voiceSupported = Boolean(Recognition);

// Ask for the microphone while the user is looking at the screen, so the
// permission prompt doesn't appear in the dark later.
export async function requestMicPermission() {
  if (!navigator.mediaDevices?.getUserMedia) return true;
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    stream.getTracks().forEach((t) => t.stop());
    return true;
  } catch {
    return false;
  }
}

export class VoiceListener {
  constructor(onCommand, onError = () => {}) {
    this.onCommand = onCommand;
    this.onError = onError;
    this.recognition = null;
    this.wanted = false;
    this.restartTimer = null;
  }

  get listening() {
    return this.wanted;
  }

  start() {
    if (!Recognition || this.wanted) return;
    this.wanted = true;
    this.#spawn();
  }

  stop() {
    this.wanted = false;
    clearTimeout(this.restartTimer);
    const r = this.recognition;
    this.recognition = null;
    try { r?.abort(); } catch { /* already stopped */ }
  }

  #spawn() {
    const r = new Recognition();
    r.lang = 'en-US';
    r.continuous = true;
    r.interimResults = false; // interim snippets of narration look like short commands
    r.maxAlternatives = 3;
    r.onresult = (event) => {
      for (let i = event.resultIndex; i < event.results.length; i++) {
        if (!event.results[i].isFinal) continue;
        for (const alt of event.results[i]) {
          const command = matchCommand(alt.transcript);
          if (command) { this.onCommand(command, alt.transcript); return; }
        }
      }
    };
    r.onerror = (event) => {
      if (event.error === 'not-allowed' || event.error === 'service-not-allowed') {
        this.stop();
        this.onError(event.error);
      }
    };
    // Recognition ends on its own after silence; keep it going while wanted.
    r.onend = () => {
      if (this.recognition !== r || !this.wanted) return;
      this.restartTimer = setTimeout(() => { if (this.wanted) this.#spawn(); }, 250);
    };
    this.recognition = r;
    try { r.start(); } catch (err) { this.onError(err.message); }
  }
}
