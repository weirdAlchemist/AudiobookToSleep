import { SleepDetector, DEFAULT_SETTINGS } from './sleep-detector.js';
import { BookPlayer } from './player.js';
import { formatTime } from './positions.js';
import * as library from './library.js';
import { VoiceListener, voiceSupported, requestMicPermission } from './voice.js';
import { CameraWatcher, cameraSupported, requestCameraPermission } from './camera.js';

const $ = (id) => document.getElementById(id);
const SKIP_SEC = 30;
const CHECK_IN_VOLUME = 0.35;
const VOICE_CHECK_IN_VOLUME = 0.2; // quieter, so the mic hears you over the book
const SAVE_EVERY_MS = 15_000;

// ---------- Settings ----------

const SETTINGS_KEY = 'ats-settings';
const APP_DEFAULTS = { ...DEFAULT_SETTINGS, fadeOutSec: 30, keepScreenOn: true, voiceEnabled: true,
  cameraEnabled: false };

function loadSettings() {
  try {
    return { ...APP_DEFAULTS, ...JSON.parse(localStorage.getItem(SETTINGS_KEY) ?? '{}') };
  } catch {
    return { ...APP_DEFAULTS };
  }
}

function storeSettings(settings) {
  try { localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings)); } catch { /* private mode */ }
}

let settings = loadSettings();

// ---------- State ----------

const player = new BookPlayer($('audio'));
let book = null;
let detector = null;   // non-null while a sleep session exists
let session = null;    // { startedAt, startPosition }
let fadingOut = null;  // pending "asleep" event while the book fades out
let tickTimer = null;
let lastSavedAt = 0;
let wakeLock = null;
let voiceOn = false;   // voice answers usable in this session (supported + mic allowed)
let cameraOn = false;  // wave answers usable in this session (supported + camera allowed)

// ---------- Helpers ----------

function toast(message, ms = 3500) {
  const el = $('toast');
  el.textContent = message;
  el.hidden = false;
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => { el.hidden = true; }, ms);
}

const clock = (ts) => new Date(ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

function showView(name) {
  $('library-view').hidden = name !== 'library';
  $('player-view').hidden = name !== 'player';
}

async function saveBookmark(position) {
  if (!book) return;
  book.position = position;
  book.lastPlayedAt = Date.now();
  lastSavedAt = Date.now();
  await library.saveBook(book);
}

// While a session runs, the safe bookmark is the last moment we knew the
// listener was awake. If the app is killed overnight, that is what survives.
function currentBookmark() {
  return detector?.active ? detector.resumePosition : player.position;
}

// ---------- Library view ----------

async function renderLibrary() {
  const books = await library.listBooks();
  const list = $('book-list');
  list.replaceChildren(...books.map((b) => {
    const total = b.tracks.reduce((s, t) => s + t.duration, 0);
    const pct = total ? Math.min(100, (b.position / total) * 100) : 0;
    const li = document.createElement('li');
    li.className = 'book';
    li.innerHTML = `
      <div class="book-main">
        <p class="book-title"></p>
        <div class="progress"><span style="width:${pct.toFixed(1)}%"></span></div>
        <p class="book-meta"></p>
      </div>
      <button class="icon-btn" aria-label="Delete book">✕</button>`;
    li.querySelector('.book-title').textContent = b.title;
    const parts = b.tracks.length > 1 ? ` · ${b.tracks.length} parts` : '';
    li.querySelector('.book-meta').textContent =
      `${formatTime(b.position)} of ${formatTime(total)}${parts}`;
    li.addEventListener('click', () => openBook(b.id));
    li.querySelector('button').addEventListener('click', async (e) => {
      e.stopPropagation();
      if (!confirm(`Delete "${b.title}" from this device?`)) return;
      await library.deleteBook(b);
      renderLibrary();
    });
    return li;
  }));
  $('empty-library').hidden = books.length > 0;
}

$('file-input').addEventListener('change', async (e) => {
  const files = e.target.files;
  if (!files?.length) return;
  toast('Importing…', 60_000);
  try {
    const added = await library.addBook(files);
    toast(`Added "${added.title}"`);
    await renderLibrary();
  } catch (err) {
    toast(`Could not import: ${err.message}`);
  } finally {
    e.target.value = '';
  }
});

// ---------- Player view ----------

async function openBook(id) {
  book = await library.getBook(id);
  await player.load(book);
  $('book-title').textContent = book.title;
  $('scrubber').max = Math.floor(player.duration);
  $('total-time').textContent = formatTime(player.duration);
  renderPosition();
  renderTrack();
  renderPlayState();
  renderLastNight();
  updateMediaSession();
  showView('player');
}

function renderPosition() {
  const pos = player.position;
  $('pos-time').textContent = formatTime(pos);
  if (!$('scrubber').matches(':active')) $('scrubber').value = Math.floor(pos);
  if ('mediaSession' in navigator && player.duration > 0) {
    try {
      navigator.mediaSession.setPositionState({
        duration: player.duration, position: Math.min(pos, player.duration), playbackRate: 1,
      });
    } catch { /* unsupported */ }
  }
}

function renderTrack() {
  if (!book) return;
  $('track-name').textContent = book.tracks.length > 1
    ? `Part ${player.trackIndex + 1} of ${book.tracks.length} · ${book.tracks[player.trackIndex].name}`
    : book.tracks[0].name;
}

function renderPlayState() {
  $('play-pause').textContent = player.playing ? '❚❚' : '▶';
  $('play-pause').setAttribute('aria-label', player.playing ? 'Pause' : 'Play');
}

function renderLastNight() {
  const card = $('last-night');
  const night = book?.nights?.at(-1);
  if (!night) { card.hidden = true; return; }
  const minutes = Math.round((night.endedAt - night.startedAt) / 60_000);
  card.hidden = false;
  if (night.reason === 'ended' || night.reason === 'interrupted') {
    card.innerHTML = `<h2>Last session · ${clock(night.startedAt)}</h2><p></p>`;
    card.querySelector('p').textContent =
      `You stopped it yourself after ${minutes} min, at ${formatTime(night.endPosition)}.`;
    return;
  }
  card.innerHTML = `
    <h2>Last night · ${clock(night.startedAt)}</h2>
    <p class="l1"></p><p class="l2"></p>
    <button class="ghost-btn">I remember more, resume at ${formatTime(night.endPosition)}</button>`;
  card.querySelector('.l1').textContent = {
    'max-session': 'Stopped at your session time limit.',
    'book-end': `The book finished during the session. You were last awake around ${clock(night.lastAwakeAt)}.`,
  }[night.reason] ?? `You were last awake around ${clock(night.lastAwakeAt)}; the book stopped at ${clock(night.endedAt)}.`;
  card.querySelector('.l2').textContent =
    `Bookmark set to ${formatTime(night.resumePosition)} (listened ${minutes} min).`;
  card.querySelector('button').addEventListener('click', async () => {
    await player.seek(night.endPosition);
    await saveBookmark(night.endPosition);
    renderPosition();
    toast(`Bookmark moved to ${formatTime(night.endPosition)}`);
  });
}

$('back').addEventListener('click', async () => {
  if (player.playing) { player.pause(); await saveBookmark(player.position); }
  showView('library');
  renderLibrary();
});

$('play-pause').addEventListener('click', async () => {
  if (player.playing) {
    player.pause();
    await saveBookmark(player.position);
  } else {
    await player.play();
  }
});

async function skip(delta) {
  await player.seek(player.position + delta);
  renderPosition();
  if (!player.playing) saveBookmark(player.position);
}
$('rewind').addEventListener('click', () => skip(-SKIP_SEC));
$('forward').addEventListener('click', () => skip(SKIP_SEC));

$('scrubber').addEventListener('change', async (e) => {
  await player.seek(Number(e.target.value));
  renderPosition();
  if (!player.playing) saveBookmark(player.position);
});

const audio = $('audio');
audio.addEventListener('play', renderPlayState);
audio.addEventListener('pause', () => {
  renderPlayState();
  // Paused by the OS, headphones unplugged, or the lock screen: the listener
  // is clearly awake, so keep their exact place and end the session.
  if (detector?.active && !fadingOut) endSession('interrupted');
});
audio.addEventListener('timeupdate', () => {
  renderPosition();
  tick(); // timeupdate keeps firing with the screen locked, unlike timers
  if (player.playing && Date.now() - lastSavedAt > SAVE_EVERY_MS) saveBookmark(currentBookmark());
});
player.addEventListener('trackchange', () => { renderTrack(); updateMediaSession(); });
player.addEventListener('bookend', async () => {
  // Mid-session we can't tell if they heard the ending, so keep the
  // last-awake bookmark; the morning card offers to jump to the end.
  if (detector) await endSession('book-end');
  else await saveBookmark(player.duration);
  toast('The end. 📕');
});

// ---------- Sleep session ----------

$('start-sleep').addEventListener('click', startSession);

async function startSession() {
  if (!book) return;
  detector = new SleepDetector(settings);
  const now = Date.now();
  detector.start(now, player.position);
  session = { startedAt: now, startPosition: player.position };
  player.audio.volume = 1;
  try {
    await player.play();
  } catch (err) {
    detector = null;
    session = null;
    toast(`Could not start playback: ${err.message}`);
    return;
  }
  $('night-title').textContent = book.title;
  $('night-view').hidden = false;
  $('night-view').classList.remove('checking');
  $('night-status').textContent = 'Listening…';
  if (settings.keepScreenOn) requestWakeLock();
  clearInterval(tickTimer);
  tickTimer = setInterval(tick, 1000);
  tick();
  voiceOn = settings.voiceEnabled && voiceSupported && await requestMicPermission();
  if (settings.voiceEnabled && voiceSupported && !voiceOn) toast('Microphone blocked: tap to answer instead.');
  cameraOn = settings.cameraEnabled && cameraSupported && await requestCameraPermission();
  if (settings.cameraEnabled && cameraSupported && !cameraOn) toast('Camera blocked: tap to answer instead.');
  renderNightHint();
}

function renderNightHint() {
  const ways = [
    voiceOn && 'say "I\'m awake"',
    cameraOn && 'wave at the phone',
    'tap the screen',
    'press skip on your headphones',
  ].filter(Boolean);
  const answer = `${ways.slice(0, -1).join(', ')} or ${ways.at(-1)}`;
  $('night-hint').textContent = `When the volume dips, ${answer}. `
    + (voiceOn ? 'Say "good night" to stop now. ' : '')
    + 'Otherwise the book fades out and keeps your place.';
}

function checkInPrompt() {
  if (voiceOn) return 'Still awake? Say "I\'m awake"';
  if (cameraOn) return 'Still awake? Wave!';
  return 'Still awake? Tap!';
}

// Mic and camera only run while waiting for an answer: the rest of the night
// the mic would mostly hear the book, and the camera would watch you sleep.
function startAnswerListeners() {
  if (voiceOn) voice.start();
  if (cameraOn) {
    $('camera-preview').hidden = false;
    camera.start();
  }
}

function stopAnswerListeners() {
  voice.stop();
  camera.stop();
  $('camera-preview').hidden = true;
  $('camera-status').textContent = '';
}

const camera = new CameraWatcher($('camera-preview'), {
  onWave: () => signOfLife(),
  onStatus: ({ tooDark, moving }) => {
    $('camera-preview').classList.toggle('moving', moving);
    $('camera-status').textContent = tooDark ? 'Too dark for the camera to see you' : '';
  },
  onError: () => {
    cameraOn = false;
    stopAnswerListeners();
    renderNightHint();
    toast('Camera unavailable: tap to answer instead.');
  },
});

// Only listen while waiting for an answer: the rest of the night the mic would
// mostly hear the book.
const voice = new VoiceListener(
  (command) => (command === 'stop' ? endSession('ended') : signOfLife()),
  () => {
    voiceOn = false;
    renderNightHint();
    toast('Microphone unavailable: tap to answer instead.');
  },
);

function tick() {
  if (!detector) return;
  const now = Date.now();
  const event = detector.tick(now);
  if (event?.type === 'check-in') onCheckIn();
  if (event?.type === 'asleep') onAsleep(event);
  renderCountdown(now);
}

function renderCountdown(now) {
  const ms = detector?.msUntilNext(now);
  if (fadingOut) {
    $('night-countdown').textContent = '';
    return;
  }
  $('night-countdown').textContent = ms == null ? '' : formatTime(Math.ceil(ms / 1000));
}

function onCheckIn() {
  player.fadeTo(voiceOn ? VOICE_CHECK_IN_VOLUME : CHECK_IN_VOLUME, 2000);
  $('night-view').classList.add('checking');
  $('night-status').textContent = checkInPrompt();
  startAnswerListeners();
}

function signOfLife() {
  if (!detector) return;
  const now = Date.now();
  if (fadingOut) {
    // Caught it during the fade: carry on listening.
    if (fadingOut.reason === 'no-response' && detector.wake(now, player.position)) {
      fadingOut = null;
      stopAnswerListeners();
      player.fadeTo(1, 1500);
      $('night-status').textContent = 'Listening…';
      $('night-view').classList.remove('checking');
      toast('Welcome back. Still listening.');
    }
    return;
  }
  const event = detector.markAwake(now, player.position);
  if (event?.type === 'awake-confirmed') {
    stopAnswerListeners();
    player.fadeTo(1, 1500);
    $('night-view').classList.remove('checking');
    $('night-status').textContent = 'Listening…';
  }
  renderCountdown(now);
}

$('night-view').addEventListener('click', (e) => {
  if (e.target.id === 'end-sleep') return;
  signOfLife();
});

$('end-sleep').addEventListener('click', () => endSession('ended'));

async function onAsleep(event) {
  fadingOut = event;
  // Keep listening through the fade so "I'm awake" or a wave can still rescue it.
  if (event.reason !== 'no-response') stopAnswerListeners();
  $('night-view').classList.remove('checking');
  $('night-status').textContent = event.reason === 'max-session' ? 'Time limit reached' : 'Good night 🌙';
  const finished = await player.fadeTo(0, settings.fadeOutSec * 1000);
  // If the fade was interrupted (the listener tapped), signOfLife took over.
  if (!finished || fadingOut !== event) return;
  await endSession(event.reason);
}

async function endSession(reason) {
  if (!detector) return;
  const now = Date.now();
  const asleep = reason === 'no-response' || reason === 'max-session' || reason === 'book-end';
  const endPosition = player.position;
  const resumePosition = asleep ? detector.resumePosition : endPosition;
  const lastAwakeAt = detector.lastAwakeAt;

  detector.stop();
  stopAnswerListeners();
  fadingOut = null;
  player.pause();
  player.audio.volume = 1;

  await player.seek(resumePosition);
  book.nights = [...(book.nights ?? []), {
    startedAt: session.startedAt,
    endedAt: now,
    lastAwakeAt,
    startPosition: session.startPosition,
    endPosition,
    resumePosition,
    reason,
  }].slice(-30);
  await saveBookmark(resumePosition);

  detector = null;
  session = null;
  clearInterval(tickTimer);
  releaseWakeLock();
  $('night-view').hidden = true;
  renderPosition();
  renderLastNight();
}

// ---------- Wake lock ----------

async function requestWakeLock() {
  try {
    wakeLock = await navigator.wakeLock?.request('screen');
  } catch { /* denied or unsupported; the lock screen path still works */ }
}

function releaseWakeLock() {
  wakeLock?.release().catch(() => {});
  wakeLock = null;
}

document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') {
    if (detector && settings.keepScreenOn) requestWakeLock();
    tick();
  } else if (book) {
    saveBookmark(currentBookmark());
  }
});

// ---------- Media Session (lock screen & headphone buttons) ----------

function updateMediaSession() {
  if (!('mediaSession' in navigator) || !book) return;
  navigator.mediaSession.metadata = new MediaMetadata({
    title: book.title,
    artist: book.tracks.length > 1 ? `Part ${player.trackIndex + 1}` : 'Audiobook to Sleep',
    artwork: [{ src: 'icons/icon.svg', sizes: 'any', type: 'image/svg+xml' }],
  });
}

// During a session, skip buttons mean "I'm awake" rather than seeking, so the
// listener can answer a check-in without looking at the screen.
function skipOrSignal(delta) {
  return () => (detector ? signOfLife() : skip(delta));
}

if ('mediaSession' in navigator) {
  const handlers = {
    play: () => player.play(),
    pause: () => player.pause(), // the 'pause' listener ends any session
    seekbackward: skipOrSignal(-SKIP_SEC),
    seekforward: skipOrSignal(SKIP_SEC),
    previoustrack: skipOrSignal(-SKIP_SEC),
    nexttrack: skipOrSignal(SKIP_SEC),
  };
  for (const [action, handler] of Object.entries(handlers)) {
    try { navigator.mediaSession.setActionHandler(action, handler); } catch { /* unsupported */ }
  }
}

// ---------- Settings dialog ----------

const form = document.querySelector('.settings-form');

$('open-settings').addEventListener('click', () => {
  for (const [key, value] of Object.entries(settings)) {
    const input = form.elements[key];
    if (!input) continue;
    if (input.type === 'checkbox') input.checked = value;
    else input.value = value;
  }
  form.elements.voiceEnabled.closest('label').hidden = !voiceSupported;
  form.elements.cameraEnabled.closest('label').hidden = !cameraSupported;
  $('settings').showModal();
});

$('settings').addEventListener('close', () => {
  if ($('settings').returnValue !== 'save') return;
  const next = { ...settings };
  for (const key of Object.keys(APP_DEFAULTS)) {
    const input = form.elements[key];
    if (!input) continue;
    next[key] = input.type === 'checkbox' ? input.checked : Number(input.value);
  }
  settings = next;
  storeSettings(settings);
  toast('Settings saved');
});

// ---------- Boot ----------

window.addEventListener('pagehide', () => { if (book) saveBookmark(currentBookmark()); });

if ('serviceWorker' in navigator && location.protocol !== 'file:') {
  navigator.serviceWorker.register('sw.js').catch(() => {});
}

renderLibrary();
