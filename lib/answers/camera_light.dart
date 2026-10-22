// Turns a light on while the camera watches for a wave in the dark, and off
// again. Kept apart from the camera so the choices can be tested.

import 'package:flutter/foundation.dart';

import '../session/app_settings.dart';
import 'device_light.dart';

class CameraLightControl {
  CameraLightControl({required this.lens, required this.light, this.device = const DeviceLight()});

  final CameraLens lens;
  final CameraLight light;
  final DeviceLight device;

  /// True while the screen should be shown white (screen light).
  final ValueNotifier<bool> screenLit = ValueNotifier(false);

  bool _cameraTorch = false;
  bool _deviceTorch = false;

  /// [cameraTorch] switches the open camera's own flash; it throws if that
  /// camera has none. Returns a note for the user if no light could be lit.
  Future<String?> on(Future<void> Function(bool on) cameraTorch) async {
    switch (light) {
      case CameraLight.off:
        return null;
      case CameraLight.screen:
        await device.setScreenBrightness(1);
        screenLit.value = true;
        return null;
      case CameraLight.flashlight:
        // The back camera owns the flashlight while it's open, so ask it.
        if (lens == CameraLens.back) {
          try {
            await cameraTorch(true);
            _cameraTorch = true;
            return null;
          } catch (_) {}
        }
        // With the front camera open, the flashlight can still be switched on
        // by itself (and a front flash is used if the phone has one).
        if (await device.setTorch(true, preferFront: lens == CameraLens.front)) {
          _deviceTorch = true;
          return null;
        }
        return 'No flashlight available';
    }
  }

  Future<void> off(Future<void> Function(bool on) cameraTorch) async {
    if (_cameraTorch) {
      _cameraTorch = false;
      try {
        await cameraTorch(false);
      } catch (_) {}
    }
    if (_deviceTorch) {
      _deviceTorch = false;
      await device.setTorch(false);
    }
    if (screenLit.value) {
      screenLit.value = false;
      await device.setScreenBrightness(null);
    }
  }
}
