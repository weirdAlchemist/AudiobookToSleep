// Matches what the speech recognizer heard against "still awake?" answers.
//
// The microphone also hears the audiobook, so only short utterances count:
// narration arrives as long sentences. Single words like "yes" or "stop" are
// everywhere in books, so only distinctive phrases are accepted.

enum VoiceCommand { awake, stop }

const _awakePhrases = [
  "i'm awake", 'im awake', 'awake', 'still here', "i'm here", "i'm listening",
  'keep going', 'keep playing', 'continue',
  // Short and easy to recognize. Only counts when said on its own or in a very
  // short phrase (see _maxWords), so an "okay" inside narration is ignored.
  'ok', 'okay',
];
const _stopPhrases = ['good night', 'goodnight', 'stop playing', 'stop the book'];
const _maxWords = 4;

VoiceCommand? matchVoiceCommand(String transcript) {
  final text = transcript
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r"[^a-z' ]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.isEmpty || text.split(' ').length > _maxWords) return null;
  bool has(String phrase) => ' $text '.contains(' $phrase ');
  // Stop wins: "I'm awake... good night" means stop now.
  if (_stopPhrases.any(has)) return VoiceCommand.stop;
  if (_awakePhrases.any(has)) return VoiceCommand.awake;
  return null;
}
