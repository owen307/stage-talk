import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// One line on the Stage Talk thread, carried on Alpaca Link.
///
/// JSON multicast `239.255.42.77:44771`, TTL 1. A note this app sends uses
/// field order:
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
/// For `talk.message`, `source.name` and `name` are both the operator.
/// `payload.text` is the note. `source.app` must be `stage-talk`.
///
/// A `cue.fire` from another app is the same envelope with the cue name in
/// `name`, the speaker in `source.name`, and `payload` a JSON object. It
/// becomes a thread line such as `Blackout went`. This app does not send
/// `cue.fire`, so receiving one cannot fire lighting.
class TalkEnvelope {
  const TalkEnvelope({
    required this.name,
    required this.text,
    required this.id,
    required this.timestamp,
    required this.instance,
    required this.show,
    this.cue = false,
  });

  static const int version = 1;
  static const String appId = 'stage-talk';
  static const String messageType = 'talk.message';
  static const String cueType = 'cue.fire';
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

  /// True when this line was a `cue.fire` from another app.
  /// Sending never sets this. A cue line is display only.
  final bool cue;

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

  /// A `talk.message` from `stage-talk`, or a `cue.fire` from any app.
  /// Other types, including the older `{v, from}` envelope, return null.
  static TalkEnvelope? tryParse(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxDatagram) return null;
    final decoded = _decodeMap(bytes);
    if (decoded == null) return null;
    if (decoded['version'] != version) return null;
    final type = decoded['type'];
    if (type == messageType) return _parseTalk(decoded, bytes);
    if (type == cueType) return _parseCue(decoded, bytes);
    return null;
  }

  static TalkEnvelope? _parseTalk(Map<dynamic, dynamic> decoded, List<int> bytes) {
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

    final show = _showOf(decoded['show']);
    if (show == null) return null;

    return TalkEnvelope(
      name: who,
      text: text,
      id: _idOf(decoded['id'], bytes),
      timestamp: _timestampOf(decoded['timestamp']),
      instance: instance.trim(),
      show: show,
    );
  }

  /// Display-only. The cue name is `name`. `source.name` is who fired it.
  /// `payload` is ignored except that it must be an object, which is what
  /// LS Mobile sends (`{}`). Nothing here is transmitted.
  static TalkEnvelope? _parseCue(Map<dynamic, dynamic> decoded, List<int> bytes) {
    final source = decoded['source'];
    if (source is! Map) return null;
    final app = source['app'];
    final instance = source['instance'];
    final sourceName = source['name'];
    if (app is! String || app.trim().isEmpty) return null;
    if (instance is! String || instance.trim().isEmpty) return null;
    if (sourceName is! String) return null;

    final rawCue = decoded['name'];
    if (rawCue is! String) return null;
    var cueName = rawCue.trim();
    if (cueName.isEmpty) return null;
    if (cueName.length > maxText) {
      cueName = cueName.substring(0, maxText);
    }

    final payload = decoded['payload'];
    if (payload is! Map) return null;

    var who = sourceName.trim();
    if (who.isEmpty) who = app.trim();
    if (who.length > 32) who = who.substring(0, 32);

    final show = _showOf(decoded['show']);
    if (show == null) return null;

    return TalkEnvelope(
      name: who,
      text: '$cueName went',
      id: _idOf(decoded['id'], bytes),
      timestamp: _timestampOf(decoded['timestamp']),
      instance: instance.trim(),
      show: show,
      cue: true,
    );
  }

  static Map<dynamic, dynamic>? _decodeMap(List<int> bytes) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    return decoded;
  }

  static String? _showOf(Object? rawShow) {
    final show = rawShow is String && rawShow.trim().isNotEmpty
        ? rawShow.trim()
        : defaultShow;
    if (show.length > maxShow) return null;
    return show;
  }

  static String _idOf(Object? rawId, List<int> bytes) {
    if (rawId is String &&
        rawId.isNotEmpty &&
        rawId.length <= 64 &&
        _safeId.hasMatch(rawId)) {
      return rawId;
    }
    return fnv1aHex(bytes);
  }

  /// Unix milliseconds, a numeric string, or an ISO-8601 instant.
  /// Peers send either the integer (LS Mobile) or an ISO string (Stage Presets).
  static int _timestampOf(Object? rawTs) {
    if (rawTs is int) return rawTs;
    if (rawTs is num) return rawTs.toInt();
    if (rawTs is String) {
      final trimmed = rawTs.trim();
      final asInt = int.tryParse(trimmed);
      if (asInt != null) return asInt;
      try {
        return DateTime.parse(trimmed).millisecondsSinceEpoch;
      } catch (_) {}
    }
    return DateTime.now().millisecondsSinceEpoch;
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
