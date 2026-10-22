// Full-screen black while a sleep session runs. Tap anywhere = "I'm awake".

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../answers/camera_listener.dart';
import '../core/positions.dart';
import '../session/night_record.dart';
import '../session/session_controller.dart';
import 'theme.dart';

class NightScreen extends StatefulWidget {
  const NightScreen({
    super.key,
    required this.controller,
    required this.started,
    this.camera,
    this.keepScreenOn = true,
  });

  final SessionController controller;
  final Future<void> started;
  final CameraListener? camera;
  final bool keepScreenOn;

  @override
  State<NightScreen> createState() => _NightScreenState();
}

class _NightScreenState extends State<NightScreen> {
  SessionController get c => widget.controller;
  bool _sawActive = false;

  @override
  void initState() {
    super.initState();
    // Phones throttle timers and block the camera with the screen off.
    if (widget.keepScreenOn) WakelockPlus.enable();
    c.addListener(_onChange);
    widget.started.catchError((Object e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start: $e')));
    });
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    if (widget.keepScreenOn) WakelockPlus.disable();
    super.dispose();
  }

  void _onChange() {
    if (c.active) _sawActive = true;
    if (_sawActive && !c.active && mounted) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {});
  }

  String get _status => switch (c.phase) {
        SessionPhase.idle || SessionPhase.listening => 'Listening…',
        SessionPhase.checking => c.usable.isEmpty
            ? 'Still awake? Tap!'
            : 'Still awake? ${_capitalize(c.usable.first.hint)}!',
        SessionPhase.fadingOut => 'Good night 🌙',
      };

  String get _hint {
    final ways = [for (final l in c.usable) l.hint, 'tap the screen'];
    final answer = ways.length == 1 ? ways.single : '${ways.sublist(0, ways.length - 1).join(', ')} or ${ways.last}';
    final voice = c.usable.any((l) => l.wantsQuietCheckIn);
    return 'When the volume dips, $answer. '
        '${voice ? 'Say "good night" to stop now. ' : ''}'
        'Otherwise it fades out and keeps your place.';
  }

  @override
  Widget build(BuildContext context) {
    final checking = c.phase == SessionPhase.checking;
    final muted = Colors.white.withValues(alpha: 0.5);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) c.end(EndReason.ended);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: c.signOfLife,
          child: SafeArea(
            child: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 600),
                opacity: checking ? 1 : 0.55,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.target.title, style: TextStyle(color: muted), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(_status,
                          style: TextStyle(fontSize: 26, color: checking ? accent : Colors.white),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(c.untilNext == null ? '' : formatDuration(c.untilNext! + const Duration(milliseconds: 999)),
                          style: TextStyle(fontSize: 48, color: muted, fontFeatures: const [FontFeature.tabularFigures()])),
                      if (widget.camera != null) _CameraPreview(widget.camera!),
                      for (final l in c.usable)
                        ValueListenableBuilder(
                          valueListenable: l.note,
                          builder: (_, note, _) => note == null
                              ? const SizedBox.shrink()
                              : Text(note, style: TextStyle(color: muted)),
                        ),
                      const SizedBox(height: 16),
                      Text(_hint, style: TextStyle(color: muted, fontSize: 13), textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: () => c.end(EndReason.ended),
                        child: const Text('End session'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small dim preview while the camera watches for a wave, so you can aim it.
class _CameraPreview extends StatelessWidget {
  const _CameraPreview(this.camera);

  final CameraListener camera;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: camera.controller,
        builder: (_, controller, _) {
          if (controller == null || !controller.value.isInitialized) return const SizedBox.shrink();
          return ValueListenableBuilder(
            valueListenable: camera.moving,
            builder: (_, moving, _) => Container(
              width: 96,
              height: 72,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border.all(color: moving ? accent : Colors.transparent, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: Opacity(
                opacity: 0.5,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(width: 160, height: 120, child: CameraPreview(controller)),
                ),
              ),
            ),
          );
        },
      );
}

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
