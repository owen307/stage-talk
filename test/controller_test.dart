import 'dart:async';
import 'dart:convert';

import 'package:alpaca_stage_talk/src/alpaca_link.dart';
import 'package:alpaca_stage_talk/src/device_effects.dart';
import 'package:alpaca_stage_talk/src/envelope.dart';
import 'package:alpaca_stage_talk/src/talk_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTransport transport;
  late TalkController controller;
  late _Effects effects;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    transport = FakeTransport();
    effects = _Effects();
    controller = TalkController(
      transport: transport,
      prefs: await SharedPreferences.getInstance(),
      effects: effects,
    );
    await controller.start();
  });

  test('presets send once and a bounce does not double-fire', () {
    expect(controller.sendText('Hold'), isTrue);
    expect(controller.sendText('Hold'), isFalse);
    expect(controller.notes.map((note) => note.text), ['Hold']);
    expect(transport.sent.single.text, 'Hold');
    expect(transport.sent.single.name, 'Booth');
    expect(transport.sent.single.show, 'Main');
    expect(transport.sent.single.toJson()['source'], {
      'app': 'stage-talk',
      'instance': controller.instanceId,
      'name': 'Booth',
    });
    expect(effects.chimes, 0);
  });

  test('a remote note is kept once and can chime', () async {
    controller.setChime(true);
    final envelope = TalkEnvelope.compose(
      name: 'Stage',
      text: 'Mic 2',
      instance: 'stage-1',
      show: 'Main',
    );
    transport.emit(envelope);
    transport.emit(envelope);
    await Future<void>.delayed(Duration.zero);
    expect(controller.notes.map((note) => note.text), ['Mic 2']);
    expect(controller.notes.single.mine, isFalse);
    expect(controller.heard, {'Stage'});
    expect(effects.chimes, 1);
  });

  test('own echo is not a second note and does not chime', () async {
    controller.setChime(true);
    controller.sendText('Stand by');
    final sent = transport.sent.single;
    transport.emit(sent);
    await Future<void>.delayed(Duration.zero);
    expect(controller.notes, hasLength(1));
    expect(effects.chimes, 0);
  });

  test('another show stays off this log', () async {
    transport.emit(TalkEnvelope.compose(
      name: 'Stage',
      text: 'Hold',
      instance: 'stage-1',
      show: 'Matinee',
    ));
    await Future<void>.delayed(Duration.zero);
    expect(controller.notes, isEmpty);
  });

  test('a cue.fire is a thread line and is not transmitted', () async {
    controller.setChime(true);
    final before = transport.sent.length;
    final fire = TalkEnvelope.tryParse(utf8.encode(jsonEncode({
      'version': 1,
      'source': {'app': 'ls-mobile', 'instance': 'phone-1', 'name': 'LS Mobile'},
      'type': 'cue.fire',
      'name': 'Blackout',
      'payload': {},
      'timestamp': 1710000000000,
      'id': 'msg-1',
      'show': 'Main',
    })));
    transport.emit(fire!);
    transport.emit(fire);
    await Future<void>.delayed(Duration.zero);
    expect(controller.notes.map((note) => note.text), ['Blackout went']);
    expect(controller.notes.single.cue, isTrue);
    expect(controller.notes.single.mine, isFalse);
    expect(controller.notes.single.name, 'LS Mobile');
    expect(controller.heard, {'LS Mobile'});
    expect(transport.sent, hasLength(before));
    expect(effects.chimes, 1);
  });

  test('a cue.fire for another show stays off this thread', () async {
    final fire = TalkEnvelope.tryParse(utf8.encode(jsonEncode({
      'version': 1,
      'source': {'app': 'ls-mobile', 'instance': 'phone-1', 'name': 'LS Mobile'},
      'type': 'cue.fire',
      'name': 'Blackout',
      'payload': {},
      'timestamp': 1,
      'id': 'msg-9',
      'show': 'Tour',
    })));
    transport.emit(fire!);
    await Future<void>.delayed(Duration.zero);
    expect(controller.notes, isEmpty);
    expect(transport.sent, isEmpty);
  });

  test('a typed message is a normal talk.message in the thread', () {
    expect(controller.sendText('House to half'), isTrue);
    expect(controller.notes.single.text, 'House to half');
    expect(controller.notes.single.cue, isFalse);
    expect(transport.sent.single.toJson()['type'], 'talk.message');
    expect(transport.sent.single.toJson()['payload'], {'text': 'House to half'});
    expect(controller.sendText('x' * 161), isFalse);
  });
}

class _Effects extends DeviceEffects {
  int chimes = 0;
  int awakeCalls = 0;

  @override
  Future<void> chime() async {
    chimes += 1;
  }

  @override
  Future<void> setAwake(bool on) async {
    awakeCalls += 1;
  }
}

class FakeTransport implements TalkTransport {
  final sent = <TalkEnvelope>[];
  final _incoming = StreamController<TalkEnvelope>.broadcast();

  @override
  Stream<TalkEnvelope> get incoming => _incoming.stream;

  @override
  Future<LinkStatus> start() async {
    return const LinkStatus(ok: true, ips: ['10.0.0.8'], multicast: true);
  }

  @override
  int send(TalkEnvelope envelope) {
    sent.add(envelope);
    return 40;
  }

  void emit(TalkEnvelope envelope) => _incoming.add(envelope);

  @override
  Future<void> close() async {}
}
