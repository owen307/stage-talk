import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Chime and display-wake side effects. Tests use [DeviceEffects] directly.
class DeviceEffects {
  Future<void> chime() async {}

  Future<void> setAwake(bool on) async {}
}

class LiveDeviceEffects extends DeviceEffects {
  AudioPlayer? _player;

  @override
  Future<void> chime() async {
    try {
      final player = _player ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(0.62);
      await player.stop();
      await player.play(AssetSource('chime.wav'));
    } catch (_) {}
  }

  @override
  Future<void> setAwake(bool on) async {
    try {
      if (on) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }
}
