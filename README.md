# Audiobook to Sleep

Plays your audiobook until you fall asleep, then stops and remembers where you dozed off,
so tomorrow night you pick up from the last part you actually heard.

## How it decides you're asleep

Phones can't see whether you're asleep, so the app asks gently:

1. Start a **sleep session**. The book plays, and the screen goes black.
2. Every *N* minutes (default 10) the volume **dips**. That's the "still awake?" check.
3. If you're awake, **tap the screen** or press **skip** on your headphones or lock screen.
   The volume comes back and the clock restarts. Tapping at any time also counts.
4. If nobody answers within the response window (default 60 s), the book **fades out and stops**.
   Tap during the fade if you're still awake, and it carries on.
5. The bookmark goes to **the last moment you were known to be awake**, minus a short rewind,
   not to where the audio happened to stop. You slept through the rest.

A hard time limit (default 120 min) stops the book even if you keep answering. If the book
ends during a session, the bookmark also falls back to your last awake moment.
The morning card shows what happened and has an **"I remember more"** button that jumps
to where the audio actually stopped.

Pausing manually, from the lock screen, or by unplugging headphones ends the session at
your exact position, because you were clearly awake.

All timings are in ⚙︎ Settings.

## Features

- Import one file or a multi-part book (`.mp3`, `.m4a`, `.m4b`, `.wav`, …). Parts are sorted
  naturally (`Part 2` before `Part 10`) and play as one timeline.
- Books and bookmarks are kept on the device in IndexedDB, so you choose the files only once.
- Lock-screen and headphone controls through the Media Session API.
- Installable PWA that works offline after the first load.
- Keeps a log of the last 30 nights for each book.

## Run it

```sh
npm start        # serves on http://localhost:8080
npm test         # unit tests for the sleep logic and multi-part positions
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
| `js/library.js` | Stores books, audio blobs and bookmarks in IndexedDB. |
| `js/app.js` | UI, sleep sessions, Media Session and wake lock. |

## Ideas for later

- Use motion from the phone or a watch as an extra awake/asleep signal.
- A native shell (Capacitor or Flutter) for guaranteed background timers on iOS.
  The sleep logic is a small DOM-free module that ports easily.
- Recap: play the 30 seconds before the bookmark at the start of the next session.
