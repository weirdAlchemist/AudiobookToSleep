// Answer "still awake?" by voice: "I'm awake", or "good night" to stop now.

import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

import '../core/voice_commands.dart';
import '../session/answer_listener.dart';

class VoiceListener extends AnswerListener {
  final SpeechToText _speech = SpeechToText();
  final _answers = StreamController<Answer>.broadcast();
  final _heard = StreamController<(String, VoiceCommand?)>.broadcast();
  bool _ready = false;
  bool _wanted = false;
  Timer? _restart;

  @override
  String get hint => 'say "I\'m awake"';

  @override
  bool get wantsQuietCheckIn => true;

  @override
  Stream<Answer> get answers => _answers.stream;

  /// Everything recognized, with the command it matched (if any). For the
  /// wake-options test screen.
  Stream<(String, VoiceCommand?)> get heard => _heard.stream;

  @override
  Future<bool> prepare() async {
    if (_ready) return true;
    try {
      // Asks for microphone permission the first time.
      _ready = await _speech.initialize(onStatus: _onStatus, onError: (_) => _scheduleRestart());
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  @override
  Future<void> start() async {
    if (!_ready || _wanted) return;
    _wanted = true;
    await _listen();
  }

  @override
  Future<void> stop() async {
    _wanted = false;
    _restart?.cancel();
    if (_speech.isListening) await _speech.cancel();
  }

  Future<void> _listen() async {
    if (!_wanted || _speech.isListening) return;
    await _speech.listen(
      onResult: (result) {
        // Final results only: interim snippets of narration look like commands.
        if (!result.finalResult) return;
        for (final alt in result.alternates) {
          final command = matchVoiceCommand(alt.recognizedWords);
          if (command != null) {
            _heard.add((alt.recognizedWords, command));
            _answers.add(command == VoiceCommand.stop ? Answer.stop : Answer.awake);
            return;
          }
        }
        _heard.add((result.recognizedWords, null));
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: false,
        cancelOnError: false,
        localeId: 'en_US',
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 8),
        contextualPhrases: const ["I'm awake", 'still here', 'keep going', 'good night'],
      ),
    );
  }

  // Recognition stops by itself after silence; keep it going while wanted.
  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) {
      _scheduleRestart();
    }
  }

  void _scheduleRestart() {
    if (!_wanted) return;
    _restart?.cancel();
    _restart = Timer(const Duration(milliseconds: 300), _listen);
  }
}
