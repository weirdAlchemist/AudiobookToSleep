// Matches what the speech recognizer heard against "still awake?" answers,
// in several languages.
//
// The microphone also hears the audiobook, so only short utterances count:
// narration arrives as long sentences. Single words like "yes" or "stop" are
// everywhere in books, so only distinctive phrases are accepted.

enum VoiceCommand { awake, stop }

class VoicePhrases {
  const VoicePhrases({required this.awake, required this.stop});

  final List<String> awake;
  final List<String> stop;
}

/// Built-in phrases by language code. Lowercase; matched as whole words
/// (or as a substring for Chinese/Japanese, which don't use spaces).
/// "OK" is understood in every language.
const voicePhrases = <String, VoicePhrases>{
  'en': VoicePhrases(
    awake: ['ok', 'okay', "i'm awake", 'im awake', 'awake', 'still here', "i'm here", "i'm listening",
        'keep going', 'keep playing', 'continue'],
    stop: ['good night', 'goodnight', 'stop playing', 'stop the book'],
  ),
  'de': VoicePhrases(
    awake: ['ich bin wach', 'bin wach', 'wach', 'noch da', 'bin noch da', 'ich höre zu', 'weiter',
        'weitermachen', 'weiterspielen'],
    stop: ['gute nacht'],
  ),
  'fr': VoicePhrases(
    awake: ["d'accord", 'je suis réveillé', 'je suis réveillée', 'réveillé', 'réveillée', 'toujours là',
        'je suis là', 'continue', 'continuer'],
    stop: ['bonne nuit'],
  ),
  'es': VoicePhrases(
    awake: ['vale', 'estoy despierto', 'estoy despierta', 'despierto', 'despierta', 'sigo aquí',
        'aquí estoy', 'sigue', 'continúa'],
    stop: ['buenas noches'],
  ),
  'it': VoicePhrases(
    awake: ['va bene', 'sono sveglio', 'sono sveglia', 'sveglio', 'ci sono', 'continua'],
    stop: ['buonanotte', 'buona notte'],
  ),
  'nl': VoicePhrases(
    awake: ['ik ben wakker', 'wakker', 'nog hier', 'ik ben er', 'ga door', 'doorgaan'],
    stop: ['welterusten', 'goedenacht', 'goede nacht'],
  ),
  'pt': VoicePhrases(
    awake: ['estou acordado', 'estou acordada', 'acordado', 'acordada', 'ainda aqui', 'continua',
        'continuar'],
    stop: ['boa noite'],
  ),
  'sv': VoicePhrases(
    awake: ['jag är vaken', 'vaken', 'fortfarande här', 'fortsätt'],
    stop: ['god natt', 'godnatt'],
  ),
  'pl': VoicePhrases(
    awake: ['nie śpię', 'jestem tu', 'wciąż tu', 'dalej', 'kontynuuj'],
    stop: ['dobranoc'],
  ),
  'ja': VoicePhrases(
    awake: ['起きてる', '続けて', '起きてます', '起きています', 'まだ起きてる', 'オーケー', 'オッケー', 'おっけー'],
    stop: ['おやすみ'],
  ),
  'zh': VoicePhrases(
    awake: ['我醒着', '继续', '醒着', '还醒着', '好的'],
    stop: ['晚安'],
  ),
  'ko': VoicePhrases(
    awake: ['깨어 있어', '계속', '깨어있어', '안 자', '오케이'],
    stop: ['잘 자', '잘자', '굿나잇'],
  ),
};

/// "de_DE" / "de-DE" -> "de".
String languageOf(String localeId) => localeId.split(RegExp('[-_]')).first.toLowerCase();

const _maxWords = 4;
const _maxCjkChars = 12;
final _cjk = RegExp(r'[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}]', unicode: true);
final _notWordChar = RegExp(r"[^\p{L}\p{N}' ]", unicode: true);

VoiceCommand? matchVoiceCommand(String transcript) {
  final text = transcript
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(_notWordChar, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.isEmpty) return null;

  final cjk = _cjk.hasMatch(text);
  if (cjk ? text.replaceAll(' ', '').length > _maxCjkChars : text.split(' ').length > _maxWords) {
    return null;
  }
  bool has(String phrase) =>
      _cjk.hasMatch(phrase) ? text.replaceAll(' ', '').contains(phrase) : ' $text '.contains(' $phrase ');

  // All languages at once: the recognizer may hear "OK" while set to German.
  // Stop wins: "OK... good night" means stop now.
  if (voicePhrases.values.any((p) => p.stop.any(has))) return VoiceCommand.stop;
  if (voicePhrases.values.any((p) => p.awake.any(has))) return VoiceCommand.awake;
  return null;
}

/// A few phrases to show for a language, e.g. for "de_DE":
/// `OK, "ich bin wach", "weiter" · stop: "gute nacht"`. Null if the language
/// has no built-in phrases (only "OK" and other languages' phrases work).
String? examplePhrases(String localeId) {
  final p = voicePhrases[languageOf(localeId)];
  if (p == null) return null;
  final awake = ['OK', ...p.awake.where((w) => w != 'ok' && w != 'okay').take(2).map((w) => '"$w"')];
  return '${awake.join(', ')} · stop: "${p.stop.first}"';
}
