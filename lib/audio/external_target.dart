import 'dart:async';

import '../session/playback_target.dart';
import 'external_media.dart';

/// Sleep sessions on another app's player (Spotify, Audible, ...). That app
/// keeps its own bookmark, so rewinding its player to the last awake moment
/// before pausing is all it takes for tomorrow night to start there.
class ExternalTarget extends PlaybackTarget {
  ExternalTarget(this.session);

  ExternalSession session;
  int? _baselineVolume;

  @override
  String get title => session.title.isEmpty ? session.appName : session.title;

  @override
  String get sourceId => 'app:${session.packageName}';

  String get _pkg => session.packageName;

  @override
  Future<PlaybackSnapshot> snapshot() async {
    final s = await ExternalMedia.session(_pkg);
    if (s == null) {
      // The app closed its session (stopped or killed): treat as paused.
      return PlaybackSnapshot(position: session.position, playing: false);
    }
    session = s;
    return PlaybackSnapshot(position: s.position, playing: s.playing);
  }

  @override
  Future<void> play() => ExternalMedia.control(_pkg, 'play');

  @override
  Future<void> pause() => ExternalMedia.control(_pkg, 'pause');

  @override
  Future<void> seekTo(Duration position) async {
    if (session.canSeek) {
      await ExternalMedia.control(_pkg, 'seekTo', position: position);
      return;
    }
    // No exact seek: press "rewind" until we're at or just before the target.
    // Skip sizes differ per app, so check the position after every press.
    var last = (await snapshot()).position;
    for (var i = 0; i < 60 && last > position + const Duration(seconds: 5); i++) {
      await ExternalMedia.control(_pkg, 'rewind');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final now = (await snapshot()).position;
      if (now >= last) break; // rewind does nothing here
      last = now;
    }
  }

  /// Fades the phone's media volume (other apps' volume can't be set directly),
  /// relative to the level when the session started.
  @override
  Future<void> setVolume(double level) async {
    final baseline = _baselineVolume ??= (await ExternalMedia.volume()).$1;
    await ExternalMedia.setVolume((baseline * level).round());
  }
}
