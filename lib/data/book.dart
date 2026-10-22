class BookTrack {
  const BookTrack({required this.fileName, required this.duration});

  final String fileName;
  final Duration duration;

  Map<String, Object> toJson() => {'fileName': fileName, 'durationMs': duration.inMilliseconds};

  factory BookTrack.fromJson(Map<String, Object?> j) => BookTrack(
        fileName: j['fileName']! as String,
        duration: Duration(milliseconds: j['durationMs']! as int),
      );
}

class Book {
  Book({
    required this.id,
    required this.title,
    required this.tracks,
    this.position = Duration.zero,
    required this.addedAt,
    this.lastPlayedAt,
  });

  final String id;
  final String title;
  final List<BookTrack> tracks;
  Duration position;
  final DateTime addedAt;
  DateTime? lastPlayedAt;

  String get sourceId => 'book:$id';
  List<Duration> get durations => [for (final t in tracks) t.duration];
  Duration get length => durations.fold(Duration.zero, (a, b) => a + b);

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'tracks': [for (final t in tracks) t.toJson()],
        'positionMs': position.inMilliseconds,
        'addedAt': addedAt.millisecondsSinceEpoch,
        'lastPlayedAt': lastPlayedAt?.millisecondsSinceEpoch,
      };

  factory Book.fromJson(Map<String, Object?> j) => Book(
        id: j['id']! as String,
        title: j['title']! as String,
        tracks: [for (final t in j['tracks']! as List) BookTrack.fromJson((t as Map).cast())],
        position: Duration(milliseconds: j['positionMs'] as int? ?? 0),
        addedAt: DateTime.fromMillisecondsSinceEpoch(j['addedAt']! as int),
        lastPlayedAt: j['lastPlayedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(j['lastPlayedAt']! as int),
      );
}

/// "Book - 01.mp3" + "Book - 02.mp3" -> "Book".
String guessTitle(List<String> fileNames) {
  final name = fileNames.first.replaceFirst(RegExp(r'\.[^.]+$'), '');
  if (fileNames.length == 1) return name;
  final stripped = name.replaceFirst(
      RegExp(r'[\s_\-.]*(part|chapter|track|cd|disc)?[\s_\-.]*\d+$', caseSensitive: false), '');
  return stripped.isEmpty ? name : stripped;
}

/// Sorts "Part 2" before "Part 10".
int naturalCompare(String a, String b) {
  final re = RegExp(r'(\d+)|(\D+)');
  final pa = re.allMatches(a.toLowerCase()).toList();
  final pb = re.allMatches(b.toLowerCase()).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final x = pa[i], y = pb[i];
    final c = (x.group(1) != null && y.group(1) != null)
        ? int.parse(x.group(1)!).compareTo(int.parse(y.group(1)!))
        : x.group(0)!.compareTo(y.group(0)!);
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}
