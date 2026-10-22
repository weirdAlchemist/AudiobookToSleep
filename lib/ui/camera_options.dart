// Which camera watches for a wave, and which light helps it in the dark.
// Used by Settings and by Test wake options.

import 'package:flutter/material.dart';

import '../session/app_settings.dart';

String cameraSetupHint(CameraLens lens, CameraLight light) => switch ((lens, light)) {
      (CameraLens.front, CameraLight.off) => 'Front camera, facing you. Needs some light in the room.',
      (CameraLens.front, CameraLight.flashlight) =>
        'Front camera with the flashlight on. The flashlight is on the back of the phone, so it lights '
            'the room indirectly: works best with a wall or headboard behind the phone.',
      (CameraLens.front, CameraLight.screen) =>
        'Front camera. The screen turns white at full brightness during check-ins to light you.',
      (CameraLens.back, CameraLight.screen) || (CameraLens.back, CameraLight.flashlight) =>
        'Back camera with its flashlight. Prop the phone with its back towards you.',
      (CameraLens.back, CameraLight.off) => 'Back camera: prop the phone with its back towards you.',
    };

class CameraOptions extends StatelessWidget {
  const CameraOptions({
    super.key,
    required this.lens,
    required this.light,
    required this.onChanged,
    this.enabled = true,
  });

  final CameraLens lens;
  final CameraLight light;
  final void Function(CameraLens lens, CameraLight light) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Camera'),
          const SizedBox(height: 6),
          SegmentedButton<CameraLens>(
            segments: const [
              ButtonSegment(value: CameraLens.front, label: Text('Front'), icon: Icon(Icons.camera_front)),
              ButtonSegment(value: CameraLens.back, label: Text('Back'), icon: Icon(Icons.camera_rear)),
            ],
            selected: {lens},
            onSelectionChanged: enabled
                ? (s) {
                    final next = s.single;
                    // The screen faces away from you with the back camera.
                    onChanged(next, next == CameraLens.back && light == CameraLight.screen ? CameraLight.flashlight : light);
                  }
                : null,
          ),
          const SizedBox(height: 12),
          const Text('Light during check-ins'),
          const SizedBox(height: 6),
          SegmentedButton<CameraLight>(
            segments: [
              const ButtonSegment(value: CameraLight.off, label: Text('Off')),
              const ButtonSegment(value: CameraLight.flashlight, label: Text('Flashlight'), icon: Icon(Icons.flashlight_on)),
              ButtonSegment(
                value: CameraLight.screen,
                label: const Text('Screen'),
                icon: const Icon(Icons.light_mode),
                enabled: lens == CameraLens.front,
              ),
            ],
            selected: {light},
            onSelectionChanged: enabled ? (s) => onChanged(lens, s.single) : null,
          ),
          const SizedBox(height: 8),
          Text(cameraSetupHint(lens, light), style: const TextStyle(color: Colors.white60, fontSize: 13)),
        ],
      );
}

/// White, full-screen "screen light" with dark content on top.
class ScreenLightPanel extends StatelessWidget {
  const ScreenLightPanel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.white,
        child: SafeArea(
          child: Center(
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              textAlign: TextAlign.center,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: children),
              ),
            ),
          ),
        ),
      );
}
