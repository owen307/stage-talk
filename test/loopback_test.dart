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
}

Future<void> _waitFor(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (DateTime.now().isBefore(deadline)) {
    if (ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
  fail('timed out waiting for a loopback note');
}
