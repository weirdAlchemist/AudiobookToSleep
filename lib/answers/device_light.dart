// The phone's flashlight (independent of which camera is open) and screen
// brightness, via DeviceBridge.kt. Calls fail softly where unsupported (iOS).

import 'package:flutter/services.dart';

class DeviceLight {
  const DeviceLight();

  static const _channel = MethodChannel('audiobook_to_sleep/device');

  /// Returns false if there's no flashlight or it can't be switched.
  /// [preferFront] picks a front-facing flash if the phone has one.
  Future<bool> setTorch(bool on, {bool preferFront = false}) async {
    try {
      return await _channel.invokeMethod<bool>('setTorch', {
            'on': on,
            'prefer': preferFront ? 'front' : 'back',
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// 0..1, or null for the system setting.
  Future<void> setScreenBrightness(double? value) async {
    try {
      await _channel.invokeMethod('setScreenBrightness', {'value': value});
    } catch (_) {}
  }
}
