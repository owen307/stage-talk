import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// One booth-to-stage note on Alpaca Link.
///
/// JSON multicast `239.255.42.77:44771`, TTL 1. Field order is fixed:
///
/// ```json
/// {
///   "version": 1,
///   "source": {"app": "stage-talk", "instance": "…", "name": "Booth"},
///   "type": "talk.message",
///   "name": "Booth",
///   "payload": {"text": "Stand by"},
///   "timestamp": 0,
///   "id": "…",
///   "show": "Main"
/// }
/// ```
///
/// `source.name` and `name` are both the operator. `payload.text` is the note.
class TalkEnvelope {
  const TalkEnvelope({
    required this.name,
    required this.text,
    required this.id,
    required this.timestamp,
    required this.instance,
    required this.show,
  });

  static const int version = 1;
  static const String appId = 'stage-talk';
  static const String messageType = 'talk.message';
  static const String defaultShow = 'Main';
  static const int maxText = 160;
  static const int maxName = 24;
  static const int maxShow = 32;
  static const int maxDatagram = 1200;

  /// Operator name. Written to both `source.name` and `name`.
  final String name;
  final String text;
  final String id;
  final int timestamp;
  final String instance;
  final String show;

  DateTime get at => DateTime.fromMillisecondsSinceEpoch(timestamp);

  factory TalkEnvelope.compose({
    required String name,
    required String text,
    required String instance,
    String show = defaultShow,
    String? id,
    DateTime? at,
  }) {
    final who = name.trim();
    final body = text.trim();
    final room = show.trim().isEmpty ? defaultShow : show.trim();
    final whoId = instance.trim();
    if (who.isEmpty || who.length > maxName) {
      throw ArgumentError.value(name, 'name', 'Use 1–$maxName characters');
    }
    if (body.isEmpty || body.length > maxText) {
      throw ArgumentError.value(text, 'text', 'Use 1–$maxText characters');
    }
    if (whoId.isEmpty || whoId.length > 64) {
      throw ArgumentError.value(instance, 'instance', 'Need an instance id');
    }
    if (room.length > maxShow) {
      throw ArgumentError.value(show, 'show', 'Use at most $maxShow characters');
    }
    return TalkEnvelope(
      name: who,
      text: body,
      id: id ?? newTalkId(),
      timestamp: (at ?? DateTime.now()).millisecondsSinceEpoch,
      instance: whoId,
      show: room,
    );
  }

  Map<String, Object?> toJson() => {
        'version': version,
        'source': {
          'app': appId,
          'instance': instance,
          'name': name,
        },
        'type': messageType,
        'name': name,
        'payload': {'text': text},
        'timestamp': timestamp,
        'id': id,
        'show': show,
      };

  Uint8List encode() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  /// Returns null when [bytes] is not a `talk.message` from `stage-talk`.
  static TalkEnvelope? tryParse(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxDatagram) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    if (decoded['version'] != version) return null;
    if (decoded['type'] != messageType) return null;

    final source = decoded['source'];
    if (source is! Map) return null;
    if (source['app'] != appId) return null;
    final instance = source['instance'];
    final sourceName = source['name'];
    if (instance is! String || instance.trim().isEmpty) return null;
    if (sourceName is! String) return null;

    final topName = decoded['name'];
    final who = sourceName.trim().isNotEmpty
        ? sourceName.trim()
        : topName is String
            ? topName.trim()
            : '';
    if (who.isEmpty || who.length > 32) return null;

    final payload = decoded['payload'];
    if (payload is! Map) return null;
    final rawText = payload['text'];
    if (rawText is! String) return null;
    final text = rawText.trim();
    if (text.isEmpty || text.length > maxText) return null;

    final rawId = decoded['id'];
    final id = rawId is String &&
            rawId.isNotEmpty &&
            rawId.length <= 64 &&
            _safeId.hasMatch(rawId)
        ? rawId
        : fnv1aHex(bytes);

    final rawTs = decoded['timestamp'];
    final timestamp = rawTs is int
        ? rawTs
        : rawTs is num
            ? rawTs.toInt()
            : DateTime.now().millisecondsSinceEpoch;

    final rawShow = decoded['show'];
    final show = rawShow is String && rawShow.trim().isNotEmpty
        ? rawShow.trim()
        : defaultShow;
    if (show.length > maxShow) return null;

    return TalkEnvelope(
      name: who,
      text: text,
      id: id,
      timestamp: timestamp,
      instance: instance.trim(),
      show: show,
    );
  }
}

final RegExp _safeId = RegExp(r'^[A-Za-z0-9_-]+$');

String newTalkId() {
  final rand = Random.secure();
  return List<String>.generate(
    16,
    (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// 64-bit FNV-1a, so two identical datagrams without an id collapse to one note.
String fnv1aHex(List<int> bytes) {
  var hash = 0xcbf29ce484222325;
  for (final b in bytes) {
    hash ^= b;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
