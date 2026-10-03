import 'dart:convert';
import 'dart:io';

import 'package:alpaca_stage_talk/src/alpaca_link.dart';
import 'package:alpaca_stage_talk/src/envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('two peers exchange talk.message on loopback', () async {
    final booth = AlpacaLink();
    final stage = AlpacaLink();
    addTearDown(() async {
      await booth.close();
      await stage.close();
    });

    final boothStatus = await booth.start();
    final stageStatus = await stage.start();
    expect(boothStatus.ok, isTrue, reason: boothStatus.error);
    expect(stageStatus.ok, isTrue, reason: stageStatus.error);
    expect(stageStatus.multicast, isTrue);

    final atStage = <TalkEnvelope>[];
    final atBooth = <TalkEnvelope>[];
    final subStage = stage.incoming.listen(atStage.add);
    final subBooth = booth.incoming.listen(atBooth.add);
    addTearDown(() async {
      await subStage.cancel();
      await subBooth.cancel();
    });

    final standBy = TalkEnvelope.compose(
      name: 'Booth',
      text: 'Stand by',
      instance: 'booth',
    );
    expect(booth.send(standBy), greaterThan(0));
    await _waitFor(
      () => atStage.any((e) => e.id == standBy.id && e.text == 'Stand by'),
    );

    final hold = TalkEnvelope.compose(
      name: 'Stage',
      text: 'Hold',
      instance: 'stage',
    );
    expect(stage.send(hold), greaterThan(0));
    await _waitFor(
      () => atBooth.any((e) => e.id == hold.id && e.name == 'Stage'),
    );
  });

  test('a cue.fire datagram is a thread line and is not sent onward', () async {
    final stage = AlpacaLink();
    final sender = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      reuseAddress: true,
    );
    addTearDown(() async {
      sender.close();
      await stage.close();
    });

    final status = await stage.start();
    expect(status.ok, isTrue, reason: status.error);
    final heard = <TalkEnvelope>[];
    final sub = stage.incoming.listen(heard.add);
    addTearDown(sub.cancel);

    final bytes = utf8.encode(jsonEncode({
      'version': 1,
      'source': {'app': 'ls-mobile', 'instance': 'phone-1', 'name': 'LS Mobile'},
      'type': 'cue.fire',
      'name': 'Blackout',
      'payload': {},
      'timestamp': 1710000000000,
      'id': 'msg-1',
      'show': 'Main',
    }));
    sender.send(bytes, InternetAddress(AlpacaLink.multicastGroup), AlpacaLink.port);
    await _waitFor(() => heard.any((e) => e.text == 'Blackout went' && e.cue));

    final line = heard.firstWhere((e) => e.id == 'msg-1');
    final cueCount = heard.where((e) => e.cue).length;
    expect(stage.send(line), 0);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(heard.where((e) => e.cue), hasLength(cueCount));
  });
}

Future<void> _waitFor(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (DateTime.now().isBefore(deadline)) {
    if (ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
  fail('timed out waiting for a loopback note');
}
