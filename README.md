# Audiobook to Sleep

A Flutter app (Android and iOS) that plays your audiobook until you fall asleep, then stops and
remembers where you dozed off, so tomorrow night you pick up from the last part you actually heard.

It plays books from its own library, and **on Android it can also control Spotify, Audible or
any other app** that's playing on the phone.

## How it decides you're asleep

Phones can't see whether you're asleep, so the app asks gently:

1. Start a **sleep session**. The audio plays, and the screen goes black.
2. Every *N* minutes (default 10) the volume **dips**. That's the "still awake?" check.
3. If you're awake, **tap the screen**, **say "I'm awake"**, **wave at the phone**, or press
   **skip** on your headphones (built-in player only). The volume comes back and the clock restarts.
4. If nobody answers within the response window (default 60 s), the audio **fades out and stops**.
   An answer during the fade rescues it.
5. The bookmark goes to **the last moment you were known to be awake**, minus a short rewind,
   not to where the audio happened to stop. You slept through the rest.

A time limit (default 120 min) stops it even if you keep answering. If the book ends during a
session, the bookmark also falls back to your last awake moment. The morning card shows what
happened and has an **"I remember more"** button that jumps to where the audio actually stopped.

Pausing manually, from the lock screen or in the other app, or unplugging headphones, ends the
session at your exact position, because you were clearly awake.

## Controlling Spotify, Audible and other apps (Android)

**Home → Control another app.** Start your audiobook in the other app, come back, pick it, and
start a sleep session. The app:

- reads that app's title and position, and pauses and plays it
- dips and fades using the phone's **media volume**, then puts the volume back afterwards
- when you fall asleep, **moves that app's player back** to your last awake moment and pauses it.
  That app keeps its own bookmark, so tomorrow you just press play there.

Moving back uses the app's exact seek when it supports it. Otherwise the app presses that app's
rewind (or "back 30 s") button until the position is right, checking the position after each press.

**One-time permission:** Android only allows this for apps with *notification access*, the same
switch other sleep-timer and media-control apps use. The app links straight to the switch. It never
reads notifications. If the switch is greyed out (Android 13+ restricts it for apps not installed from
Play), open App info → ⋮ → **Allow restricted settings**, then try again.

iOS doesn't allow one app to control another app's player, so on iPhone the app only plays its own
library.

## Answering without touching the phone

Both options are in Settings and only run **during a check-in and the fade-out**, never all night.

**Voice** (on by default): say *"I'm awake"*, *"still here"* or *"keep going"*, or *"good night"* to
stop now and keep your exact place. The audio drops to 20% during voice check-ins so you can be heard.
Only short utterances (four words or fewer) with distinctive phrases count, so a narrator saying
"awake" doesn't answer for you. Uses the phone's speech recognizer (Google or Apple). English only. Some
Android phones beep when the recognizer starts listening; turn voice off if that bothers you.

**Wave at the camera** (off by default): the front camera looks for about a second of continued
movement. A single jolt, like turning over in your sleep, is ignored. Frames are shrunk to 48×36 grey
pixels and analysed on the phone; nothing is stored or sent. It needs some light (a night light is
enough) and the screen on. In a dark room it shows "Too dark for the camera to see you".

## Building

```sh
flutter pub get
flutter test          # 47 tests: sleep logic, wave detection, voice matching, session flow, UI
flutter analyze
flutter run           # on a connected phone
flutter build apk     # Android
```

Release builds shrink code with R8, which can break plugins that Dart calls over JNI
(`shared_preferences_android`, and the `jni` runtime itself). The keep rules in
`android/app/proguard-rules.pro` cover them. After upgrading plugins, check a release APK with
`tool/check_jni_runtime.py` and `tool/check_jni_bindings.py`; both fail if a looked-up name is missing.

The app was written with Flutter 3.47 / Dart 3.13. Minimum Android version is Flutter's default.

## Layout

| Path | What it does |
| --- | --- |
| `lib/core/` | Pure logic, no Flutter: sleep detector, wave (motion) detector, voice command matching, multi-part positions. |
| `lib/session/` | `SessionController` runs a night against a `PlaybackTarget` and optional `AnswerListener`s. |
| `lib/audio/` | Targets: the built-in player (`just_audio` + `audio_service` for background/lock screen) and other apps (`ExternalTarget`). |
| `lib/answers/` | Voice (`speech_to_text`) and camera (`camera`) answer listeners. |
| `lib/data/` | Library (audio copied into app storage), night log, settings. |
| `lib/ui/` | Screens: home, book, other app, night (black screen), settings. |
| `android/.../MediaBridge.kt` | Lists and controls other apps' media sessions; media volume. |
| `android/.../MediaListenerService.kt` | Empty notification listener that holds the access Android requires. |

## Ideas for later

- Show the "still awake?" check in a notification, so the screen can stay off.
- Spotify on iOS through Spotify's own SDK (the only iOS route to control another player).
- Play a 30-second recap before the bookmark at the start of the next session.
