import '../session/playback_target.dart';
import '../data/book.dart';
import 'book_audio_handler.dart';

/// Sleep sessions on a book from the app's own library.
class BookTarget extends PlaybackTarget {
  BookTarget(this.handler, this.book);

  final BookAudioHandler handler;
  final Book book;

  @override
  String get title => book.title;

  @override
  String get sourceId => book.sourceId;

  @override
  Future<PlaybackSnapshot> snapshot() async => PlaybackSnapshot(
        position: handler.globalPosition,
        playing: handler.isPlaying,
        completed: handler.finished,
      );

  @override
  Future<void> play() => handler.play();

  @override
  Future<void> pause() => handler.pause();

  @override
  Future<void> seekTo(Duration position) => handler.seekGlobal(position);

  @override
  Future<void> setVolume(double level) => handler.setVolume(level);

  @override
  Stream<void> get awakeSignals => handler.awakeSignals;
}
