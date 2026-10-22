enum EndReason { noResponse, maxSession, bookEnd, ended, interrupted }

extension EndReasonX on EndReason {
  /// The listener may have been asleep, so the bookmark falls back to the
  /// last moment they were known to be awake.
  bool get mayHaveSlept =>
      this == EndReason.noResponse || this == EndReason.maxSession || this == EndReason.bookEnd;
}

class NightRecord {
  const NightRecord({
    required this.sourceId,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    required this.lastAwakeAt,
    required this.startPosition,
    required this.endPosition,
    required this.resumePosition,
    required this.reason,
  });

  final String sourceId;
  final String title;
  final DateTime startedAt;
  final DateTime endedAt;
  final DateTime lastAwakeAt;
  final Duration startPosition;

  /// Where the audio actually stopped.
  final Duration endPosition;

  /// Where the bookmark was put.
  final Duration resumePosition;
  final EndReason reason;

  Duration get listened => endedAt.difference(startedAt);

  Map<String, Object?> toJson() => {
        'sourceId': sourceId,
        'title': title,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'endedAt': endedAt.millisecondsSinceEpoch,
        'lastAwakeAt': lastAwakeAt.millisecondsSinceEpoch,
        'startPosition': startPosition.inMilliseconds,
        'endPosition': endPosition.inMilliseconds,
        'resumePosition': resumePosition.inMilliseconds,
        'reason': reason.name,
      };

  factory NightRecord.fromJson(Map<String, Object?> j) => NightRecord(
        sourceId: j['sourceId']! as String,
        title: j['title']! as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(j['startedAt']! as int),
        endedAt: DateTime.fromMillisecondsSinceEpoch(j['endedAt']! as int),
        lastAwakeAt: DateTime.fromMillisecondsSinceEpoch(j['lastAwakeAt']! as int),
        startPosition: Duration(milliseconds: j['startPosition']! as int),
        endPosition: Duration(milliseconds: j['endPosition']! as int),
        resumePosition: Duration(milliseconds: j['resumePosition']! as int),
        reason: EndReason.values.byName(j['reason']! as String),
      );
}
