import 'dart:async';
import 'dart:io';

import 'package:alpaca_stage_talk/src/alpaca_link.dart';
import 'package:alpaca_stage_talk/src/envelope.dart';

/// Two Alpaca Link peers on this machine. Booth sends "Stand by", Stage
/// answers "Hold". Exits 0 when both directions arrive on loopback.
Future<void> main() async {
  final booth = AlpacaLink();
  final stage = AlpacaLink();
  try {
    final boothStatus = await booth.start();
    final stageStatus = await stage.start();
    if (!boothStatus.ok || !stageStatus.ok) {
      stderr.writeln(
        'bind failed: booth=${boothStatus.error} stage=${stageStatus.error}',
      );
      exitCode = 1;
      return;
    }
    stdout.writeln(
      'listening UDP ${AlpacaLink.port}  multicast ${AlpacaLink.multicastGroup}',
    );

    final atStage = boothTo(stage, 'Stand by');
    final standBy = TalkEnvelope.compose(
      name: 'Booth',
      text: 'Stand by',
      instance: 'booth',
    );
    final wrote = booth.send(standBy);
    stdout.writeln('Booth sent $wrote bytes');
    final heard = await atStage.timeout(const Duration(seconds: 2));
    stdout.writeln('Stage heard ${heard.name}: ${heard.text}');

    final atBooth = boothTo(booth, 'Hold');
    stage.send(TalkEnvelope.compose(
      name: 'Stage',
      text: 'Hold',
      instance: 'stage',
    ));
    final reply = await atBooth.timeout(const Duration(seconds: 2));
    stdout.writeln('Booth heard ${reply.name}: ${reply.text}');
    stdout.writeln('loopback ok');
  } on TimeoutException {
    stderr.writeln('timed out waiting for the other peer');
    exitCode = 1;
  } finally {
    await booth.close();
    await stage.close();
  }
}

Future<TalkEnvelope> boothTo(AlpacaLink peer, String text) {
  final done = Completer<TalkEnvelope>();
  late final StreamSubscription<TalkEnvelope> sub;
  sub = peer.incoming.listen((envelope) {
    if (envelope.text != text || done.isCompleted) return;
    done.complete(envelope);
    unawaited(sub.cancel());
  });
  return done.future;
}
