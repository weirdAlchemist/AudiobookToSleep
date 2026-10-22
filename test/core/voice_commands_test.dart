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

  group('other languages', () {
    test('awake phrases', () {
      for (final said in [
        'Ich bin wach', 'noch da', 'Weiter!', // de
        'Je suis réveillée.', "D'accord", // fr
        'Estoy despierto', 'Sigo aquí', // es
        'Sono sveglio', // it
        'Ik ben wakker', // nl
        'Estou acordada', // pt
        'Jag är vaken', // sv
        'Nie śpię', // pl
        '起きてる', 'まだ起きてるよ', 'オーケー', // ja
        '我醒着', // zh
        '깨어 있어', '오케이', // ko
      ]) {
        expect(matchVoiceCommand(said), VoiceCommand.awake, reason: said);
      }
    });

    test('stop phrases', () {
      for (final said in ['Gute Nacht', 'Bonne nuit', 'Buenas noches', 'Buonanotte', 'Welterusten',
          'Boa noite', 'God natt', 'Dobranoc', 'おやすみなさい', '晚安', '잘 자']) {
        expect(matchVoiceCommand(said), VoiceCommand.stop, reason: said);
      }
    });

    test('narration stays too long to count, also without spaces', () {
      expect(matchVoiceCommand('Er lag noch lange wach und hörte dem Regen zu'), isNull);
      expect(matchVoiceCommand('彼は夜遅くまで起きていて雨の音を聞いていた'), isNull);
    });

    test('example phrases for display', () {
      expect(examplePhrases('de_DE'), 'OK, "ich bin wach", "bin wach" · stop: "gute nacht"');
      expect(examplePhrases('tr_TR'), isNull);
    });

    test('language code from a locale id', () {
      expect(languageOf('de_DE'), 'de');
      expect(languageOf('ja-JP'), 'ja');
      expect(languageOf('en'), 'en');
    });
  });
}
