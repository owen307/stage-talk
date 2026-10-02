import 'package:flutter/services.dart';

const MethodChannel _net = MethodChannel('alpaca_stage_talk/net');

/// Holds a Wi-Fi multicast lock so Android delivers the link group.
Future<void> acquireMulticastLock() async {
  try {
    await _net.invokeMethod<void>('acquireMulticast');
  } catch (_) {}
}

Future<void> releaseMulticastLock() async {
  try {
    await _net.invokeMethod<void>('releaseMulticast');
  } catch (_) {}
}
