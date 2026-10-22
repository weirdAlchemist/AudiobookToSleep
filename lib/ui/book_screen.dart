import 'dart:async';

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../audio/book_target.dart';
import '../core/positions.dart';
import '../data/book.dart';
import 'sleep_session_launcher.dart';
import 'widgets.dart';

class BookScreen extends StatefulWidget {
  const BookScreen({super.key, required this.book});

  final Book book;

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  final _services = AppServices.instance;
  late final _audio = _services.audio;
  Book get book => widget.book;
  bool _loaded = false;
  double? _dragging;
  Timer? _saver;

  @override
  void initState() {
    super.initState();
    _load();
    // Outside sleep sessions, remember the exact position as it plays.
    _saver = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_audio.isPlaying && !_audio.skipsSignalAwake) _savePosition();
    });
  }

  Future<void> _load() async {
    if (_audio.book?.id != book.id) {
      await _audio.loadBook(book, _services.library.trackPath);
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _saver?.cancel();
    if (_audio.isPlaying) _savePosition();
    super.dispose();
  }

  Future<void> _savePosition() async {
    book
      ..position = _audio.globalPosition
      ..lastPlayedAt = DateTime.now();
    await _services.library.save();
  }

  Future<void> _seek(Duration to) async {
    await _audio.seekGlobal(to);
    if (!_audio.isPlaying) await _savePosition();
    if (mounted) setState(() {});
  }

  Future<void> _togglePlay() async {
    if (_audio.isPlaying) {
      await _audio.pause();
      await _savePosition();
    } else {
      unawaited(_audio.play());
    }
  }

  Future<void> _startSleep() async {
    await runSleepSession(context, BookTarget(_audio, book));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final night = _services.nights.latestFor(book.sourceId);
    final length = book.length;
    return Scaffold(
      appBar: AppBar(title: Text(book.title, overflow: TextOverflow.ellipsis)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: StreamBuilder<Duration>(
                      stream: _audio.globalPositionStream,
                      builder: (context, _) {
                        final pos = _audio.globalPosition;
                        final max = length.inMilliseconds.toDouble();
                        return Column(
                          children: [
                            if (book.tracks.length > 1)
                              Text('Part ${_audio.trackIndex + 1} of ${book.tracks.length}',
                                  style: const TextStyle(color: Colors.white60)),
                            Slider(
                              max: max <= 0 ? 1 : max,
                              value: (_dragging ?? pos.inMilliseconds.toDouble()).clamp(0, max <= 0 ? 1 : max),
                              onChanged: (v) => setState(() => _dragging = v),
                              onChangeEnd: (v) {
                                _dragging = null;
                                _seek(Duration(milliseconds: v.round()));
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(formatDuration(pos), style: const TextStyle(color: Colors.white60)),
                                Text(formatDuration(length), style: const TextStyle(color: Colors.white60)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            StreamBuilder<bool>(
                              stream: _audio.playingStream,
                              builder: (context, _) => Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton.filledTonal(
                                    iconSize: 28,
                                    icon: const Icon(Icons.replay_30),
                                    onPressed: () => _seek(pos - const Duration(seconds: 30)),
                                  ),
                                  const SizedBox(width: 20),
                                  IconButton.filled(
                                    iconSize: 44,
                                    icon: Icon(_audio.isPlaying ? Icons.pause : Icons.play_arrow),
                                    onPressed: _togglePlay,
                                  ),
                                  const SizedBox(width: 20),
                                  IconButton.filledTonal(
                                    iconSize: 28,
                                    icon: const Icon(Icons.forward_30),
                                    onPressed: () => _seek(pos + const Duration(seconds: 30)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _startSleep,
                  icon: const Icon(Icons.bedtime),
                  label: const Text('Start sleep session'),
                ),
                if (night != null) ...[
                  const SizedBox(height: 20),
                  LastNightCard(
                    night: night,
                    onResumeAtEnd: () async {
                      await _seek(night.endPosition);
                      await _savePosition();
                    },
                  ),
                ],
              ],
            ),
    );
  }
}
