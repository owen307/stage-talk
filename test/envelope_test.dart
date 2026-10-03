import 'dart:convert';

import 'package:alpaca_stage_talk/src/alpaca_link.dart';
import 'package:alpaca_stage_talk/src/envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encode matches the Alpaca Link envelope', () {
    final envelope = TalkEnvelope.compose(
      name: 'Booth',
      text: 'Stand by',
      instance: 'inst1',
      show: 'Main',
      id: 'abc123',
      at: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );
    final json = envelope.toJson();
    expect(json.keys.toList(), [
      'version',
      'source',
      'type',
      'name',
      'payload',
      'timestamp',
      'id',
      'show',
    ]);
    expect(json['version'], 1);
    expect(json['source'], {
      'app': 'stage-talk',
      'instance': 'inst1',
      'name': 'Booth',
    });
    expect(json['type'], 'talk.message');
    expect(json['name'], 'Booth');
    expect(json['payload'], {'text': 'Stand by'});
    expect(json['timestamp'], 1700000000000);
    expect(json['id'], 'abc123');
    expect(json['show'], 'Main');
    expect(AlpacaLink.port, 44771);
    expect(AlpacaLink.multicastGroup, '239.255.42.77');
    expect(AlpacaLink.ttl, 1);

    final parsed = TalkEnvelope.tryParse(envelope.encode());
    expect(parsed, isNotNull);
    expect(parsed!.text, 'Stand by');
    expect(parsed.name, 'Booth');
    expect(parsed.id, 'abc123');
    expect(parsed.show, 'Main');
    expect(parsed.instance, 'inst1');
  });

  test('the previous v/from envelope is not a talk message', () {
    final raw = utf8.encode(jsonEncode({
      'v': 1,
      'from': 'stage-talk',
      'type': 'talk.message',
      'name': 'Booth',
      'payload': {'text': 'Stand by'},
    }));
    expect(TalkEnvelope.tryParse(raw), isNull);
  });

  test('parse drops other apps, other types, and junk', () {
    TalkEnvelope? parse(Object body) {
      return TalkEnvelope.tryParse(utf8.encode(jsonEncode(body)));
    }

    Map<String, Object?> note({String app = 'stage-talk', String type = 'talk.message'}) {
      return {
        'version': 1,
        'source': {'app': app, 'instance': 'i', 'name': 'A'},
        'type': type,
        'name': 'A',
        'payload': {'text': 'x'},
        'timestamp': 1,
        'id': 'id1',
        'show': 'Main',
      };
    }

    expect(parse(note(app: 'other')), isNull);
    expect(parse(note(type: 'talk.other')), isNull);
    expect(TalkEnvelope.tryParse(utf8.encode('not json')), isNull);
    expect(TalkEnvelope.tryParse(const []), isNull);
    final blank = note();
    (blank['payload'] as Map)['text'] = '   ';
    expect(parse(blank), isNull);
  });

  test('cue.fire from another app becomes a thread line and is not a note to send', () {
    final raw = utf8.encode(jsonEncode({
      'version': 1,
      'source': {'app': 'ls-mobile', 'instance': 'phone-1', 'name': 'LS Mobile'},
      'type': 'cue.fire',
      'name': 'Blackout',
      'payload': {},
      'timestamp': 1710000000000,
      'id': 'msg-1',
      'show': 'Main',
    }));
    final parsed = TalkEnvelope.tryParse(raw);
    expect(parsed, isNotNull);
    expect(parsed!.cue, isTrue);
    expect(parsed.text, 'Blackout went');
    expect(parsed.name, 'LS Mobile');
    expect(parsed.instance, 'phone-1');
    expect(parsed.id, 'msg-1');
    expect(parsed.show, 'Main');
    expect(parsed.timestamp, 1710000000000);
    expect(parsed.toJson()['type'], 'talk.message');
  });

  test('cue.fire accepts an ISO timestamp, an empty show, and a trimmed name', () {
    final parsed = TalkEnvelope.tryParse(utf8.encode(
      '{"version":1,"source":{"app":"stage-presets","instance":"node-1","name":"Side phone"},"type":"cue.fire","name":" Opening ","payload":{},"timestamp":"2026-10-02T22:04:00.000Z","id":"msg-2","show":""}',
    ));
    expect(parsed, isNotNull);
    expect(parsed!.text, 'Opening went');
    expect(parsed.name, 'Side phone');
    expect(parsed.show, 'Main');
    expect(
      parsed.timestamp,
      DateTime.parse('2026-10-02T22:04:00.000Z').millisecondsSinceEpoch,
    );
  });

  test('cue.fire on another show keeps that show, and junk cues are dropped', () {
    TalkEnvelope? parse(Object body) {
      return TalkEnvelope.tryParse(utf8.encode(jsonEncode(body)));
    }

    Map<String, Object?> fire({
      String name = 'Wash',
      String show = 'Tour',
      Object payload = const {},
      String app = 'ls-mobile',
    }) {
      return {
        'version': 1,
        'source': {'app': app, 'instance': 'phone-1', 'name': 'LS Mobile'},
        'type': 'cue.fire',
        'name': name,
        'payload': payload,
        'timestamp': 1,
        'id': 'msg-3',
        'show': show,
      };
    }

    expect(parse(fire())!.show, 'Tour');
    expect(parse(fire(name: '   ')), isNull);
    expect(parse(fire(payload: [])), isNull);
    expect(parse(fire(app: '')), isNull);
    expect(
      TalkEnvelope.tryParse(utf8.encode(
        '{"v":1,"from":"booth","type":"cue.fire","name":"Wash","payload":{}}',
      )),
      isNull,
    );
  });
}
