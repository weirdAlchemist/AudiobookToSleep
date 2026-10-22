// Answer "still awake?" by voice: "I'm awake", or "good night" to stop now.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/voice_commands.dart';
import '../session/answer_listener.dart';

class VoiceListener extends AnswerListener {
  /// [locales]: recognizer languages to listen in, taking turns when there
  /// are several (Android listens in one language at a time). Empty: the
  /// phone's language.
  VoiceListener({this.locales = const []});

  final List<String> locales;
  final SpeechToText _speech = SpeechToText();
  final _answers = StreamController<Answer>.broadcast();
  final _heard = StreamController<(String, VoiceCommand?)>.broadcast();

  /// Words recognized so far in the current utterance (shown, never acted on).
  final ValueNotifier<String> hearing = ValueNotifier('');

  /// The recognizer's latest status or error, for the test screen.
  final ValueNotifier<String?> diagnostics = ValueNotifier(null);

  /// The languages actually used, resolved in [prepare].
  List<String> activeLocales = const [];
  int _turn = 0;
  String? _currentLocale;
  bool _ready = false;
  bool _wanted = false;
  Timer? _restart;

  @override
  String get hint => 'say "OK"';

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
      _ready = await _speech.initialize(onStatus: _onStatus, onError: _onError);
      if (!_ready) {
        diagnostics.value = 'Speech recognition is not available on this phone';
      } else {
        activeLocales = locales.isNotEmpty
            ? locales
            : [(await _speech.systemLocale())?.localeId ?? 'en_US'];
      }
    } catch (e) {
      _ready = false;
      diagnostics.value = 'Speech recognition failed to start: $e';
    }
    return _ready;
  }

  @override
  Future<void> start() async {
    if (!_ready || _wanted) return;
    _wanted = true;
    // SpeechToText is one shared instance and initialize() only registers
    // callbacks the first time, so another VoiceListener (or the language
    // list) may own them. Claim them, or restarts after a pause never happen.
    _speech
      ..statusListener = _onStatus
      ..errorListener = _onError;
    await _listen();
  }

  @override
  Future<void> stop() async {
    _wanted = false;
    _restart?.cancel();
    hearing.value = '';
    if (_speech.isListening) await _speech.cancel();
  }

  Future<void> _listen() async {
    if (!_wanted || _speech.isListening) return;
    final several = activeLocales.length > 1;
    final locale = _currentLocale = activeLocales[_turn++ % activeLocales.length];
    await _speech.listen(
      onResult: (result) {
        hearing.value = result.recognizedWords;
        // Act on final results only: interim snippets of narration look like
        // commands.
        if (!result.finalResult) return;
        hearing.value = '';
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
        partialResults: true,
        cancelOnError: false,
        localeId: locale,
        // With several languages, short turns so each gets a chance soon.
        listenFor: several ? const Duration(seconds: 8) : const Duration(minutes: 2),
        pauseFor: several ? const Duration(seconds: 4) : const Duration(seconds: 8),
        contextualPhrases: const ['OK', "I'm awake", 'still here', 'keep going', 'good night'],
      ),
    );
  }

  void _onError(SpeechRecognitionError e) {
    diagnostics.value = 'Recognizer error: ${e.errorMsg}';
    _scheduleRestart();
  }

  // Recognition stops by itself after silence; keep it going while wanted.
  void _onStatus(String status) {
    if (status == SpeechToText.listeningStatus) diagnostics.value = 'Listening in $_currentLocale';
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

/// The languages the phone's speech recognizer offers, and the phone's own.
/// Initializing asks for microphone permission the first time.
Future<(List<LocaleName>, LocaleName?)> recognizerLanguages() async {
  final speech = SpeechToText();
  if (!await speech.initialize()) return (const <LocaleName>[], null);
  final all = await speech.locales();
  all.sort((a, b) => a.name.compareTo(b.name));
  return (all, await speech.systemLocale());
}
