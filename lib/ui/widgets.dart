import 'package:flutter/material.dart';

import '../core/positions.dart';
import '../session/night_record.dart';

String clockTime(BuildContext context, DateTime t) =>
    TimeOfDay.fromDateTime(t).format(context);

/// What happened last night, with a way to undo the rewind.
class LastNightCard extends StatelessWidget {
  const LastNightCard({super.key, required this.night, required this.onResumeAtEnd});

  final NightRecord night;
  final VoidCallback onResumeAtEnd;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white60);
    final minutes = night.listened.inMinutes;
    final manual = !night.reason.mayHaveSlept;
    final lines = <String>[
      if (manual)
        'You stopped it yourself after $minutes min, at ${formatDuration(night.endPosition)}.'
      else ...[
        switch (night.reason) {
          EndReason.maxSession => 'Stopped at your session time limit.',
          EndReason.bookEnd => 'The book finished during the session. You were last awake around '
              '${clockTime(context, night.lastAwakeAt)}.',
          _ => 'You were last awake around ${clockTime(context, night.lastAwakeAt)}; '
              'the audio stopped at ${clockTime(context, night.endedAt)}.',
        },
        'Bookmark set to ${formatDuration(night.resumePosition)} (listened $minutes min).',
      ],
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${manual ? 'Last session' : 'Last night'} · ${clockTime(context, night.startedAt)}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            for (final l in lines) Padding(padding: const EdgeInsets.only(top: 4), child: Text(l, style: muted)),
            if (!manual && night.endPosition > night.resumePosition) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: onResumeAtEnd,
                child: Text('I remember more, resume at ${formatDuration(night.endPosition)}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
