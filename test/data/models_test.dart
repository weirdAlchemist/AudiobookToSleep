import 'package:audiobook_to_sleep/data/book.dart';
import 'package:audiobook_to_sleep/session/app_settings.dart';
import 'package:audiobook_to_sleep/session/night_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guesses a book title from file names', () {
    expect(guessTitle(['Dune.m4b']), 'Dune');
    expect(guessTitle(['Dune - 01.mp3', 'Dune - 02.mp3']), 'Dune');
    expect(guessTitle(['Dune_Part1.mp3', 'Dune_Part2.mp3']), 'Dune');
    expect(guessTitle(['01.mp3', '02.mp3']), '01');
  });

  test('sorts parts naturally', () {
    final names = ['Part 10.mp3', 'Part 2.mp3', 'Part 1.mp3'];
    names.sort(naturalCompare);
    expect(names, ['Part 1.mp3', 'Part 2.mp3', 'Part 10.mp3']);
  });

  test('book survives a JSON round trip', () {
    final book = Book(
      id: 'abc',
      title: 'Dune',
      tracks: const [BookTrack(fileName: '000_a.mp3', duration: Duration(minutes: 30))],
      position: const Duration(minutes: 12),
      addedAt: DateTime(2026, 10, 1),
    );
    final copy = Book.fromJson(book.toJson());
    expect(copy.title, 'Dune');
    expect(copy.position, const Duration(minutes: 12));
    expect(copy.length, const Duration(minutes: 30));
    expect(copy.sourceId, 'book:abc');
  });

  test('night record survives a JSON round trip', () {
    final night = NightRecord(
      sourceId: 'app:com.spotify.music',
      title: 'Book',
      startedAt: DateTime(2026, 10, 21, 23),
      endedAt: DateTime(2026, 10, 21, 23, 40),
      lastAwakeAt: DateTime(2026, 10, 21, 23, 20),
      startPosition: const Duration(minutes: 5),
      endPosition: const Duration(minutes: 45),
      resumePosition: const Duration(minutes: 24, seconds: 30),
      reason: EndReason.noResponse,
    );
    final copy = NightRecord.fromJson(night.toJson());
    expect(copy.reason, EndReason.noResponse);
    expect(copy.resumePosition, night.resumePosition);
    expect(copy.listened, const Duration(minutes: 40));
  });

  test('settings fill in defaults for missing keys', () {
    final s = AppSettings.fromJson({'checkInIntervalMin': 5});
    expect(s.checkInIntervalMin, 5);
    expect(s.voiceEnabled, isTrue);
    expect(s.cameraEnabled, isFalse);
    expect(s.cameraTorch, isFalse);
    expect(AppSettings.fromJson(s.copyWith(cameraTorch: true).toJson()).cameraTorch, isTrue);
    expect(AppSettings.fromJson(s.toJson()).sleep.checkInInterval, const Duration(minutes: 5));
  });
}
