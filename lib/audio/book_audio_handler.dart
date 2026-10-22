// Plays a multi-file book as one timeline, in the background, with lock-screen
// and headphone controls (via audio_service).

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../core/positions.dart';
import '../data/book.dart';

class BookAudioHandler extends BaseAudioHandler with SeekHandler {
  BookAudioHandler() {
    unawaited(_handleInterruptions());
    _player.playbackEventStream.listen((_) => _broadcast());
    _player.playingStream.listen((_) => _broadcast());
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) unawaited(_nextTrack());
    });
  }

  static const skipInterval = Duration(seconds: 30);

  // Interruptions (calls, other apps, the speech recognizer) are handled
  // below instead of by just_audio, so check-ins can ignore the recognizer.
  final AudioPlayer _player = AudioPlayer(handleInterruptions: false);
  bool _pausedByInterruption = false;

  /// Set while the app's own speech recognizer is listening during a check-in:
  /// it takes audio focus, but the book should keep playing (quietly).
  bool ignoreFocusLoss = false;
  final _awake = StreamController<void>.broadcast();
  Book? book;
  String Function(Book, int)? _pathFor;
  int trackIndex = 0;

  /// True once the last track has played to the end.
  bool finished = false;

  /// When set (during a sleep session), skip buttons mean "I'm awake" instead
  /// of seeking, so the listener can answer without looking at the screen.
  bool skipsSignalAwake = false;

  Stream<void> get awakeSignals => _awake.stream;
  bool get isPlaying => _player.playing && !finished;
  Stream<bool> get playingStream => _player.playingStream;

  Duration get globalPosition =>
      book == null ? Duration.zero : toGlobal(book!.durations, trackIndex, _player.position);

  Stream<Duration> get globalPositionStream =>
      _player.positionStream.map((_) => globalPosition);

  Future<void> loadBook(Book b, String Function(Book, int) pathFor) async {
    await _player.pause();
    book = b;
    _pathFor = pathFor;
    finished = false;
    await seekGlobal(b.position, force: true);
  }

  Future<void> seekGlobal(Duration position, {bool force = false}) async {
    final b = book;
    if (b == null) return;
    final length = b.length;
    final clamped = position < Duration.zero ? Duration.zero : (position > length ? length : position);
    final target = fromGlobal(b.durations, clamped);
    finished = false;
    if (force || target.track != trackIndex || _player.audioSource == null) {
      await _loadTrack(target.track, target.offset);
    } else {
      await _player.seek(target.offset);
    }
    _broadcast();
  }

  Future<void> setVolume(double v) => _player.setVolume(v.clamp(0, 1));

  // ---- AudioHandler (lock screen, notification, headphones) ----

  @override
  Future<void> play() async {
    if (finished) return;
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.pause();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => seekGlobal(position);

  @override
  Future<void> rewind() => _skip(-skipInterval);

  @override
  Future<void> fastForward() => _skip(skipInterval);

  @override
  Future<void> skipToPrevious() => _skip(-skipInterval);

  @override
  Future<void> skipToNext() => _skip(skipInterval);

  Future<void> _skip(Duration delta) async {
    if (skipsSignalAwake) {
      _awake.add(null);
      return;
    }
    await seekGlobal(globalPosition + delta);
  }

  Future<void> _handleInterruptions() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    // Headphones unplugged: always pause.
    session.becomingNoisyEventStream.listen((_) => _player.pause());
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (event.type == AudioInterruptionType.duck || ignoreFocusLoss) return;
        if (_player.playing) {
          _pausedByInterruption = true;
          _player.pause();
        }
      } else {
        if (event.type == AudioInterruptionType.pause && _pausedByInterruption) _player.play();
        _pausedByInterruption = false;
      }
    });
  }

  Future<void> _loadTrack(int index, Duration offset) async {
    final b = book!;
    trackIndex = index;
    await _player.setFilePath(_pathFor!(b, index), initialPosition: offset);
    mediaItem.add(MediaItem(
      id: '${b.id}/$index',
      title: b.title,
      artist: b.tracks.length > 1 ? 'Part ${index + 1} of ${b.tracks.length}' : 'Audiobook to Sleep',
      duration: b.length,
    ));
  }

  Future<void> _nextTrack() async {
    final b = book;
    if (b == null) return;
    if (trackIndex + 1 >= b.tracks.length) {
      finished = true;
      await _player.pause();
      _broadcast();
      return;
    }
    await _loadTrack(trackIndex + 1, Duration.zero);
    await _player.play();
  }

  void _broadcast() {
    final playing = isPlaying;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.rewind,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
      ],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (_player.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: playing,
      updatePosition: globalPosition,
      bufferedPosition: globalPosition,
      speed: _player.speed,
    ));
  }
}
