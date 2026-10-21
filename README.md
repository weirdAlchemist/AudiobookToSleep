# Audiobook to Sleep

Plays your audiobook until you fall asleep, then stops and remembers where you dozed off,
so tomorrow night you pick up from the last part you actually heard.

## How it decides you're asleep

Phones can't see whether you're asleep, so the app asks gently:

1. Start a **sleep session**. The book plays, and the screen goes black.
2. Every *N* minutes (default 10) the volume **dips**. That's the "still awake?" check.
3. If you're awake, **say "I'm awake"**, **wave at the phone**, **tap the screen**, or press **skip**
   on your headphones or lock screen. The volume comes back and the clock restarts. Tapping at any time also counts.
4. If nobody answers within the response window (default 60 s), the book **fades out and stops**.
   Tap, wave or say "I'm awake" during the fade, and it carries on.
5. The bookmark goes to **the last moment you were known to be awake**, minus a short rewind,
   not to where the audio happened to stop. You slept through the rest.

A hard time limit (default 120 min) stops the book even if you keep answering. If the book
ends during a session, the bookmark also falls back to your last awake moment.
The morning card shows what happened and has an **"I remember more"** button that jumps
to where the audio actually stopped.

Pausing manually, from the lock screen, or by unplugging headphones ends the session at
your exact position, because you were clearly awake.

All timings are in ⚙︎ Settings.

## Voice answers

Useful when the phone is out of reach on the nightstand. The phone asks for microphone access
when a session starts, so the prompt appears while you're still looking at the screen.

| Say | Effect |
| --- | --- |
| "I'm awake", "still here", "keep going", "continue" | Same as tapping: keep listening |
| "Good night", "stop playing" | Stop now and keep your exact place |

- The microphone is **on only during a check-in and the fade-out**, not all night. During a
  check-in the book drops to 20% volume so your voice is heard over it.
- Only short utterances of four words or fewer count. Narration comes through as long sentences,
  so a character saying "awake" doesn't answer for you. Single words like "yes" or "stop" are not
  commands, because they turn up in books all the time.
- Recognition uses the browser's speech service (Chrome sends the audio to Google's servers,
  Safari uses Apple's). Commands are English only for now.
- Some Android phones play a short beep when the microphone starts listening. Turn voice off in
  Settings if that bothers you.

## Waving at the camera

Turn this on in Settings. During a check-in the front camera turns on, a small dim preview
appears, and about a second of waving counts as "I'm awake".

- The camera is **on only during a check-in and the fade-out**. Frames are shrunk to 48×36 grey
  pixels and analysed on the phone. Nothing is recorded or sent anywhere.
- It looks for **sustained** movement. A single jolt, like turning over in your sleep, is ignored.
- Changes in overall brightness (auto-exposure, the screen lighting up) don't count as movement,
  and the first 1.5 s after the camera starts are ignored while it adjusts.
- **It needs some light.** A night light, a street lamp or a bright screen is enough. In a fully dark
  room the camera sees nothing, and the night screen says "Too dark for the camera to see you".
  Use voice in that case.
- Prop the phone so the front camera faces the bed. Phones block the camera when the screen is
  off, so keep "Keep screen on" enabled.
- It's off by default, since it needs the camera permission.

## Features

- Import one file or a multi-part book (`.mp3`, `.m4a`, `.m4b`, `.wav`, …). Parts are sorted
  naturally (`Part 2` before `Part 10`) and play as one timeline.
- Books and bookmarks are kept on the device in IndexedDB, so you choose the files only once.
- Lock-screen and headphone controls through the Media Session API.
- Optional voice and camera (wave) answers to check-ins.
- Installable PWA that works offline after the first load.
- Keeps a log of the last 30 nights for each book.

## Run it

```sh
npm start        # serves on http://localhost:8080
npm test         # unit tests for the sleep logic, positions, voice commands and wave detection
```

No build step and no dependencies. Use HTTPS (or `localhost`) for install, wake lock and
service-worker support. Any static host works, such as GitHub Pages or Netlify.

## Platform notes

- **Keep screen on (default):** the app holds a screen wake lock and shows a black screen.
  This is the most reliable option, because browsers throttle timers when the screen is off.
- **Screen off:** on Android Chrome, playback and check-ins keep working, since checks also
  run on the audio's progress events. iOS Safari is stricter with background web pages,
  so leaving the screen on is recommended there.

## Layout

| File | What it does |
| --- | --- |
| `js/sleep-detector.js` | Pure state machine for check-ins, sleep detection and the resume point. No DOM. |
| `js/positions.js` | Converts positions between "whole book" seconds and (part, time). |
| `js/player.js` | Plays several files on one `<audio>` element as a single book, with fades. |
| `js/voice.js` | Speech recognition during check-ins and voice command matching. |
| `js/motion-detector.js` | Pure wave detection on small grey frames (frame differencing). |
| `js/camera.js` | Front camera during check-ins; feeds frames to the motion detector. |
| `js/library.js` | Stores books, audio blobs and bookmarks in IndexedDB. |
| `js/app.js` | UI, sleep sessions, voice, camera, Media Session and wake lock. |

## Ideas for later

- Use motion from the phone or a watch as an extra awake/asleep signal.
- A native shell (Capacitor or Flutter) for guaranteed background timers on iOS.
  The sleep logic is a small DOM-free module that ports easily.
- Recap: play the 30 seconds before the bookmark at the start of the next session.
