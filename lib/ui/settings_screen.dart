import 'package:flutter/material.dart';

import '../app_services.dart';
import '../session/app_settings.dart';
import 'voice_languages_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings s = AppServices.instance.settings;

  void _set(AppSettings next) {
    setState(() => s = next);
    AppServices.instance.updateSettings(next);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sleep settings')),
        body: ListView(
          children: [
            _Stepper('Check if I\'m awake every', s.checkInIntervalMin, 'min', 1, 60,
                (v) => _set(s.copyWith(checkInIntervalMin: v))),
            _Stepper('Wait for an answer for', s.responseWindowSec, 'sec', 10, 300,
                (v) => _set(s.copyWith(responseWindowSec: v)), step: 10),
            _Stepper('Always stop after', s.maxSessionMin, 'min', 10, 480,
                (v) => _set(s.copyWith(maxSessionMin: v)), step: 10),
            _Stepper('Rewind before the last awake moment by', s.rewindSec, 'sec', 0, 300,
                (v) => _set(s.copyWith(rewindSec: v)), step: 10),
            _Stepper('Fade out over', s.fadeOutSec, 'sec', 0, 120,
                (v) => _set(s.copyWith(fadeOutSec: v)), step: 5),
            const Divider(),
            SwitchListTile(
              title: const Text('Keep screen on (black) during sessions'),
              subtitle: const Text('Most reliable timing; needed for waving at the camera'),
              value: s.keepScreenOn,
              onChanged: (v) => _set(s.copyWith(keepScreenOn: v)),
            ),
            SwitchListTile(
              title: const Text('Answer by voice'),
              subtitle: const Text('Say "OK" or "I\'m awake", or "good night" to stop now. '
                  'The microphone is on only during check-ins.'),
              value: s.voiceEnabled,
              onChanged: (v) => _set(s.copyWith(voiceEnabled: v)),
            ),
            ListTile(
              enabled: s.voiceEnabled,
              title: const Text('Voice languages'),
              subtitle: Text(s.voiceLocales.isEmpty ? 'Follow phone language' : s.voiceLocales.join(', ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const VoiceLanguagesScreen()));
                setState(() => s = AppServices.instance.settings);
              },
            ),
            SwitchListTile(
              title: const Text('Answer by waving at the camera'),
              subtitle: const Text('Front camera, on only during check-ins. Needs some light.'),
              value: s.cameraEnabled,
              onChanged: (v) => _set(s.copyWith(cameraEnabled: v)),
            ),
            SwitchListTile(
              title: const Text('Flashlight for the camera'),
              subtitle: const Text('Lights the room during check-ins so a wave can be seen in the dark. '
                  'Uses the back camera: prop the phone with its back towards you.'),
              value: s.cameraTorch,
              onChanged: s.cameraEnabled ? (v) => _set(s.copyWith(cameraTorch: v)) : null,
            ),
          ],
        ),
      );
}

class _Stepper extends StatelessWidget {
  const _Stepper(this.label, this.value, this.unit, this.min, this.max, this.onChanged, {this.step = 1});

  final String label;
  final int value;
  final String unit;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: value > min ? () => onChanged((value - step).clamp(min, max)) : null,
            ),
            SizedBox(width: 64, child: Text('$value $unit', textAlign: TextAlign.center)),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: value < max ? () => onChanged((value + step).clamp(min, max)) : null,
            ),
          ],
        ),
      );
}
