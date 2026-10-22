// Try every way of answering "still awake?" without starting a session:
// tap, voice, waving at the camera (optionally with the flashlight), and
// headphone / lock-screen buttons.

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../answers/camera_listener.dart';
import '../answers/voice_listener.dart';
import '../app_services.dart';
import '../audio/book_audio_handler.dart';
import '../core/voice_commands.dart';
import 'theme.dart';

class WakeTestScreen extends StatelessWidget {
  const WakeTestScreen({
    super.key,
    this.voiceFactory = _realVoice,
    this.cameraFactory = _realCamera,
    this.audio,
  });

  final VoiceListener Function() voiceFactory;
  final CameraListener Function({bool torch}) cameraFactory;

  /// The built-in player, for the headphone-button test. Null hides it.
  final BookAudioHandler? audio;

  static CameraListener _realCamera({bool torch = false}) => CameraListener(torch: torch);
  static VoiceListener _realVoice() =>
      VoiceListener(locales: AppServices.maybeInstance?.settings.voiceLocales ?? const []);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Test wake options')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Try each way of answering "still awake?". Nothing here starts a sleep session.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 16),
            const _TapTest(),
            const SizedBox(height: 12),
            _VoiceTest(factory: voiceFactory),
            const SizedBox(height: 12),
            _CameraTest(factory: cameraFactory),
            if (audio != null) ...[
              const SizedBox(height: 12),
              _ButtonTest(audio: audio!),
            ],
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.children});

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: accent),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ]),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
}

/// Shows "✓ <label>" briefly each time [count] goes up.
class _Result extends StatelessWidget {
  const _Result({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) => count == 0
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('✓ $label ($count)', style: const TextStyle(color: accent, fontWeight: FontWeight.w600)),
        );
}

class _TapTest extends StatefulWidget {
  const _TapTest();

  @override
  State<_TapTest> createState() => _TapTestState();
}

class _TapTestState extends State<_TapTest> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) => _Section(
        icon: Icons.touch_app,
        title: 'Tap the screen',
        children: [
          const Text('During a session, a tap anywhere on the black screen counts.'),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => setState(() => _taps++), child: const Text('Tap here')),
          _Result(count: _taps, label: 'Tap works'),
        ],
      );
}

class _VoiceTest extends StatefulWidget {
  const _VoiceTest({required this.factory});

  final VoiceListener Function() factory;

  @override
  State<_VoiceTest> createState() => _VoiceTestState();
}

class _VoiceTestState extends State<_VoiceTest> {
  late final VoiceListener _voice = widget.factory();
  StreamSubscription<(String, VoiceCommand?)>? _sub;
  bool _listening = false;
  bool _starting = false;
  String? _error;
  final List<(String, VoiceCommand?)> _heard = [];
  int _matches = 0;

  Future<void> _toggle() async {
    if (_listening) {
      await _voice.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() {
      _starting = true;
      _error = null;
    });
    if (!await _voice.prepare()) {
      setState(() {
        _starting = false;
        _error = 'Speech recognition is unavailable, or microphone access was denied.';
      });
      return;
    }
    _sub ??= _voice.heard.listen((h) => setState(() {
          _heard.insert(0, h);
          if (_heard.length > 4) _heard.removeLast();
          if (h.$2 != null) _matches++;
        }));
    await _voice.start();
    setState(() {
      _starting = false;
      _listening = true;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _voice.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Section(
        icon: Icons.mic,
        title: 'Say "OK"',
        children: [
          const Text('Or "I\'m awake", "still here", "keep going"; "good night" stops. Say it on its own: '
              'longer sentences are ignored so the narrator can\'t answer for you.'),
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: _starting ? null : _toggle,
            child: Text(_listening ? 'Stop listening' : (_starting ? 'Starting…' : 'Start listening')),
          ),
          if (_listening) ...[
            ValueListenableBuilder(
              valueListenable: _voice.hearing,
              builder: (_, words, _) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(words.isEmpty ? 'Listening…' : 'Hearing: "$words"'),
              ),
            ),
          ],
          if (_listening)
            for (final id in _voice.activeLocales)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('$id: ${examplePhrases(id) ?? '"OK"'}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ),
          ValueListenableBuilder(
            valueListenable: _voice.diagnostics,
            builder: (_, status, _) => status == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(status, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ),
          ),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          for (final (words, command) in _heard)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                command == null
                    ? 'Heard "$words": not a command'
                    : 'Heard "$words" → ${command == VoiceCommand.stop ? 'stop' : 'awake'}',
                style: TextStyle(color: command == null ? Colors.white60 : Colors.white),
              ),
            ),
          _Result(count: _matches, label: 'Voice works'),
        ],
      );
}

class _CameraTest extends StatefulWidget {
  const _CameraTest({required this.factory});

  final CameraListener Function({bool torch}) factory;

  @override
  State<_CameraTest> createState() => _CameraTestState();
}

class _CameraTestState extends State<_CameraTest> {
  late bool _torch = AppServices.maybeInstance?.settings.cameraTorch ?? false;
  CameraListener? _camera;
  StreamSubscription<Object?>? _sub;
  bool _starting = false;
  String? _error;
  int _waves = 0;

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    final camera = widget.factory(torch: _torch);
    if (!await camera.prepare()) {
      setState(() {
        _starting = false;
        _error = 'No camera available, or camera access was denied.';
      });
      return;
    }
    _sub = camera.answers.listen((_) => setState(() => _waves++));
    await camera.start();
    if (!mounted) {
      await camera.stop();
      return;
    }
    setState(() {
      _camera = camera;
      _starting = false;
    });
  }

  Future<void> _stop() async {
    final camera = _camera;
    unawaited(_sub?.cancel());
    _sub = null;
    setState(() => _camera = null);
    await camera?.stop();
  }

  Future<void> _setTorch(bool on) async {
    setState(() => _torch = on);
    final services = AppServices.maybeInstance;
    if (services != null) await services.updateSettings(services.settings.copyWith(cameraTorch: on));
    if (_camera != null) {
      await _stop();
      await _start();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _camera?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return _Section(
      icon: Icons.waving_hand,
      title: 'Wave at the phone',
      children: [
        Text(_torch
            ? 'Back camera with the flashlight on. Prop the phone with its back towards you and wave for about a second.'
            : 'Front camera. Wave for about a second; a single jolt (like turning over) is ignored.'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Flashlight'),
          subtitle: const Text('Lights the room so a wave can be seen in the dark'),
          value: _torch,
          onChanged: _starting ? null : _setTorch,
        ),
        FilledButton.tonal(
          onPressed: _starting ? null : (camera == null ? _start : _stop),
          child: Text(camera != null ? 'Stop camera' : (_starting ? 'Starting…' : 'Start camera')),
        ),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (camera != null) ...[
          const SizedBox(height: 12),
          Center(child: _Preview(camera)),
          ValueListenableBuilder(
            valueListenable: camera.note,
            builder: (_, note, _) =>
                note == null ? const SizedBox.shrink() : Center(child: Text(note, style: const TextStyle(color: Colors.white60))),
          ),
          const Center(
            child: Text('The border lights up when it sees movement.', style: TextStyle(color: Colors.white60, fontSize: 12)),
          ),
        ],
        _Result(count: _waves, label: 'Wave detected'),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview(this.camera);

  final CameraListener camera;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: camera.moving,
        builder: (_, moving, _) => Container(
          width: 192,
          height: 144,
          decoration: BoxDecoration(
            border: Border.all(color: moving ? accent : Colors.white24, width: 3),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: ValueListenableBuilder(
            valueListenable: camera.controller,
            builder: (_, controller, _) => controller == null || !controller.value.isInitialized
                ? const Center(child: Text('Camera off', style: TextStyle(color: Colors.white38)))
                : FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(width: 160, height: 120, child: CameraPreview(controller)),
                  ),
          ),
        ),
      );
}

class _ButtonTest extends StatefulWidget {
  const _ButtonTest({required this.audio});

  final BookAudioHandler audio;

  @override
  State<_ButtonTest> createState() => _ButtonTestState();
}

class _ButtonTestState extends State<_ButtonTest> {
  BookAudioHandler get audio => widget.audio;
  StreamSubscription<void>? _sub;
  bool _active = false;
  int _presses = 0;

  // Skip buttons reach the app only while its player is playing, so play the
  // current book quietly during the test.
  Future<void> _start() async {
    audio.skipsSignalAwake = true;
    _sub = audio.awakeSignals.listen((_) => setState(() => _presses++));
    await audio.setVolume(0.15);
    unawaited(audio.play());
    setState(() => _active = true);
  }

  Future<void> _stop() async {
    unawaited(_sub?.cancel());
    _sub = null;
    audio.skipsSignalAwake = false;
    await audio.pause();
    await audio.setVolume(1);
    if (mounted) setState(() => _active = false);
  }

  @override
  void dispose() {
    if (_active) _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Section(
        icon: Icons.headphones,
        title: 'Headphone or lock-screen buttons',
        children: [
          const Text('For books in the app (not other apps). Press skip forward or back on your '
              'headphones or the lock screen. The book plays quietly during this test.'),
          const SizedBox(height: 10),
          if (audio.book == null)
            const Text('Open a book first to test this.', style: TextStyle(color: Colors.white60))
          else
            FilledButton.tonal(
              onPressed: _active ? _stop : _start,
              child: Text(_active ? 'Stop' : 'Start (plays "${audio.book!.title}" quietly)'),
            ),
          _Result(count: _presses, label: 'Button press received'),
        ],
      );
}
