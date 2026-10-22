import 'package:audiobook_to_sleep/core/voice_commands.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes short awake phrases', () {
    for (final said in ["I'm awake", 'awake', 'still here', 'Keep going.', 'I’m listening', 'im awake']) {
      expect(matchVoiceCommand(said), VoiceCommand.awake, reason: said);
    }
  });

  test('OK is a trigger word, on its own or in a very short phrase', () {
    for (final said in ['OK', 'ok.', 'Okay', 'okay okay', 'OK I\'m here']) {
      expect(matchVoiceCommand(said), VoiceCommand.awake, reason: said);
    }
    expect(matchVoiceCommand('OK good night'), VoiceCommand.stop, reason: 'stop still wins');
    expect(matchVoiceCommand('"Okay," he said, and walked out into the night'), isNull,
        reason: 'narration is too long to count');
    expect(matchVoiceCommand('broken'), isNull, reason: 'not a whole word');
  });

  test('recognizes stop phrases, and stop wins over awake', () {
    expect(matchVoiceCommand('Good night'), VoiceCommand.stop);
    expect(matchVoiceCommand('goodnight'), VoiceCommand.stop);
    expect(matchVoiceCommand('stop playing'), VoiceCommand.stop);
    expect(matchVoiceCommand("I'm awake good night"), VoiceCommand.stop);
  });

  test('ignores narration and look-alike words', () {
    expect(matchVoiceCommand('She lay awake for hours listening to the rain on the roof'), isNull);
    expect(matchVoiceCommand('"Yes," she said.'), isNull);
    expect(matchVoiceCommand('Stop!'), isNull);
    expect(matchVoiceCommand('awakened'), isNull);
    expect(matchVoiceCommand(''), isNull);
  });
}
