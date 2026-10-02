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
}
