// Sleep sessions on whatever another app is playing (Spotify, Audible, ...).

import 'dart:async';

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../audio/external_media.dart';
import '../audio/external_target.dart';
import '../core/positions.dart';
import 'sleep_session_launcher.dart';
import 'widgets.dart';

class ExternalScreen extends StatefulWidget {
  const ExternalScreen({super.key});

  @override
  State<ExternalScreen> createState() => _ExternalScreenState();
}

class _ExternalScreenState extends State<ExternalScreen> with WidgetsBindingObserver {
  bool? _hasAccess;
  List<ExternalSession> _sessions = const [];
  String? _selected;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  // Coming back from the system settings screen after granting access.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final access = await ExternalMedia.hasAccess();
    var sessions = const <ExternalSession>[];
    if (access) {
      try {
        sessions = await ExternalMedia.sessions();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _hasAccess = access;
      _sessions = sessions;
      if (_selected == null || !sessions.any((s) => s.packageName == _selected)) {
        // Default to whatever is playing, else the most recent.
        _selected = (sessions.where((s) => s.playing).firstOrNull ?? sessions.firstOrNull)?.packageName;
      }
    });
  }

  ExternalSession? get _current => _sessions.where((s) => s.packageName == _selected).firstOrNull;

  Future<void> _startSleep(ExternalSession session) async {
    _poll?.cancel();
    await runSleepSession(context, ExternalTarget(session));
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Control another app')),
        body: switch (_hasAccess) {
          null => const Center(child: CircularProgressIndicator()),
          false => _AccessExplainer(onGrant: ExternalMedia.openAccessSettings),
          true => _sessionsView(context),
        },
      );

  Widget _sessionsView(BuildContext context) {
    final current = _current;
    final night = current == null
        ? null
        : AppServices.instance.nights.latestFor('app:${current.packageName}');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'Nothing is playing. Start your audiobook in Spotify, Audible or another app, '
              'then come back here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
          ),
        if (_sessions.length > 1) ...[
          RadioGroup<String>(
            groupValue: _selected,
            onChanged: (v) => setState(() => _selected = v),
            child: Column(
              children: [
                for (final s in _sessions)
                  RadioListTile<String>(
                    value: s.packageName,
                    title: Text(s.appName),
                    subtitle: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    secondary: Icon(s.playing ? Icons.graphic_eq : Icons.pause),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (current != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(current.appName, style: const TextStyle(color: Colors.white60)),
                  const SizedBox(height: 4),
                  Text(current.title.isEmpty ? 'Unknown title' : current.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  if (current.subtitle.isNotEmpty)
                    Text(current.subtitle, style: const TextStyle(color: Colors.white60)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        current.duration == null
                            ? formatDuration(current.position)
                            : '${formatDuration(current.position)} / ${formatDuration(current.duration!)}',
                        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                      const Spacer(),
                      IconButton.filledTonal(
                        icon: Icon(current.playing ? Icons.pause : Icons.play_arrow),
                        onPressed: () => ExternalMedia.control(
                            current.packageName, current.playing ? 'pause' : 'play'),
                      ),
                    ],
                  ),
                  if (!current.canSeek)
                    const Text(
                      'This app only supports skipping, so the bookmark is set by pressing its '
                      'rewind button until it reaches the right spot.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _startSleep(current),
            icon: const Icon(Icons.bedtime),
            label: const Text('Start sleep session'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Fades use the phone\'s media volume. It\'s put back when the session ends.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
        if (night != null && current != null) ...[
          const SizedBox(height: 20),
          LastNightCard(
            night: night,
            onResumeAtEnd: () => ExternalMedia.control(current.packageName, 'seekTo', position: night.endPosition),
          ),
        ],
      ],
    );
  }
}

class _AccessExplainer extends StatelessWidget {
  const _AccessExplainer({required this.onGrant});

  final Future<void> Function() onGrant;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.lock_open, size: 48),
          const SizedBox(height: 16),
          Text('One-time permission', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text(
            'To pause and rewind Spotify, Audible or other players, Android requires "notification '
            'access". Android uses that one switch for all media control, so that\'s the one to turn on. '
            'This app never reads your notifications.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'If the switch is greyed out (common for apps not installed from Play): open App info for '
            'Audiobook to Sleep, tap ⋮, choose "Allow restricted settings", then try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onGrant, child: const Text('Open settings')),
        ],
      );
}
