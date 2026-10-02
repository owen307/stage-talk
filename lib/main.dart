import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/alpaca_link.dart';
import 'src/android_multicast.dart';
import 'src/device_effects.dart';
import 'src/stage_talk_page.dart';
import 'src/talk_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final controller = TalkController(
    transport: AlpacaLink(
      onListening: acquireMulticastLock,
      onStopped: releaseMulticastLock,
    ),
    prefs: prefs,
    effects: LiveDeviceEffects(),
  );
  await controller.start();
  runApp(StageTalkApp(controller: controller));
}
