import 'package:audiobook_to_sleep/answers/camera_light.dart';
import 'package:audiobook_to_sleep/answers/device_light.dart';
import 'package:audiobook_to_sleep/session/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDevice extends DeviceLight {
  FakeDevice({this.hasTorch = true});

  final bool hasTorch;
  final calls = <String>[];

  @override
  Future<bool> setTorch(bool on, {bool preferFront = false}) async {
    calls.add('torch $on${on && preferFront ? ' front' : ''}');
    return hasTorch;
  }

  @override
  Future<void> setScreenBrightness(double? value) async => calls.add('brightness $value');
}

void main() {
  late List<bool> cameraTorch;
  Future<void> working(bool on) async => cameraTorch.add(on);
  Future<void> noFlash(bool on) async => throw Exception('no flash unit');

  setUp(() => cameraTorch = []);

  test('front camera + flashlight: switches the flashlight on by itself', () async {
    final device = FakeDevice();
    final c = CameraLightControl(lens: CameraLens.front, light: CameraLight.flashlight, device: device);
    expect(await c.on(working), isNull);
    expect(cameraTorch, isEmpty, reason: "doesn't ask the front camera for a flash");
    await c.off(working);
    expect(device.calls, ['torch true front', 'torch false']);
  });

  test("back camera + flashlight: uses the camera's own torch", () async {
    final device = FakeDevice();
    final c = CameraLightControl(lens: CameraLens.back, light: CameraLight.flashlight, device: device);
    expect(await c.on(working), isNull);
    await c.off(working);
    expect(cameraTorch, [true, false]);
    expect(device.calls, isEmpty);
  });

  test('back camera without a flash falls back to the device flashlight', () async {
    final device = FakeDevice();
    final c = CameraLightControl(lens: CameraLens.back, light: CameraLight.flashlight, device: device);
    expect(await c.on(noFlash), isNull);
    await c.off(noFlash);
    expect(device.calls, ['torch true', 'torch false']);
  });

  test('no flashlight anywhere: says so', () async {
    final device = FakeDevice(hasTorch: false);
    final c = CameraLightControl(lens: CameraLens.front, light: CameraLight.flashlight, device: device);
    expect(await c.on(working), 'No flashlight available');
    await c.off(working);
    expect(device.calls, ['torch true front'], reason: 'nothing to switch off');
  });

  test('screen light: full brightness and white screen, then back to normal', () async {
    final device = FakeDevice();
    final c = CameraLightControl(lens: CameraLens.front, light: CameraLight.screen, device: device);
    expect(await c.on(working), isNull);
    expect(c.screenLit.value, isTrue);
    await c.off(working);
    expect(c.screenLit.value, isFalse);
    expect(device.calls, ['brightness 1.0', 'brightness null']);
  });

  test('light off does nothing', () async {
    final device = FakeDevice();
    final c = CameraLightControl(lens: CameraLens.front, light: CameraLight.off, device: device);
    expect(await c.on(working), isNull);
    await c.off(working);
    expect(device.calls, isEmpty);
    expect(cameraTorch, isEmpty);
  });
}
