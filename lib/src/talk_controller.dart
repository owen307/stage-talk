import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alpaca_link.dart';
import 'device_effects.dart';
import 'envelope.dart';

class TalkNote {
  const TalkNote({
    required this.id,
    required this.name,
    required this.text,
    required this.at,
    required this.mine,
    required this.sent,
    this.cue = false,
  });

  final String id;
  final String name;
  final String text;
  final DateTime at;
  final bool mine;
  final bool sent;

  /// A cue fire from another app, shown in the same thread as notes.
  final bool cue;
}

enum NoteTone { ready, hold, plain }

NoteTone toneFor(String text) {
  switch (text.trim().toLowerCase()) {
    case 'stand by':
      return NoteTone.ready;
    case 'hold':
      return NoteTone.hold;
    default:
      return NoteTone.plain;
  }
}

class TalkController extends ChangeNotifier {
  TalkController({
    required this.transport,
    required this.prefs,
    DeviceEffects? effects,
  }) : effects = effects ?? DeviceEffects();

  final TalkTransport transport;
  final SharedPreferences prefs;
  final DeviceEffects effects;

  static const quickNames = ['Booth', 'Stage', 'SM', 'A2'];
  static const presets = ['Stand by', 'Mic 2', 'Hold'];
  static const _noteLimit = 200;

  final notes = <TalkNote>[];
  final heard = <String>{};
  final _seen = <String>{};
  final _mine = <String>{};

  String name = 'Booth';
  String showName = TalkEnvelope.defaultShow;
  String instanceId = '';
  bool chime = false;
  bool stageType = false;
  bool keepAwake = false;
  bool linkOk = false;
  bool multicast = false;
  bool pulse = false;
  bool clearArmed = false;
  String? linkError;
  List<String> ips = const [];

  StreamSubscription<TalkEnvelope>? _sub;
  Timer? _pulseTimer;
  Timer? _clearTimer;
  DateTime? _lastSendAt;
  String? _lastSendText;

  String get ipLabel {
    final usable = ips.where((ip) => !ip.startsWith('127.')).toList();
    if (usable.isEmpty) return 'LOOPBACK';
    return usable.first;
  }

  String get linkLabel {
    if (!linkOk) return 'LINK DOWN';
    return 'LIVE  ·  $ipLabel  ·  UDP ${AlpacaLink.port}  ·  $showName';
  }

  Future<void> start() async {
    name = _clipName(prefs.getString('name') ?? 'Booth');
    if (name.trim().isEmpty) name = 'Booth';
    instanceId = prefs.getString('instance') ?? '';
    if (instanceId.isEmpty) {
      instanceId = newTalkId();
      unawaited(prefs.setString('instance', instanceId));
    }
    showName = _clipShow(prefs.getString('show') ?? TalkEnvelope.defaultShow);
    chime = prefs.getBool('chime') ?? false;
    stageType = prefs.getBool('stageType') ?? false;
    keepAwake = prefs.getBool('keepAwake') ?? false;
    _loadNotes();
    _sub ??= transport.incoming.listen(_onRemote, onError: (_) {});
    _apply(await transport.start());
    if (keepAwake) unawaited(effects.setAwake(true));
    notifyListeners();
  }

  Future<void> retry() async {
    await transport.close();
    _apply(await transport.start());
    notifyListeners();
  }

  void setName(String raw) {
    final next = _clipName(raw);
    if (next == name) return;
    name = next;
    unawaited(prefs.setString('name', name.trim().isEmpty ? 'Booth' : name.trim()));
    notifyListeners();
  }

  void setShow(String raw) {
    final next = _clipShow(raw);
    if (next == showName) return;
    showName = next;
    unawaited(prefs.setString('show', showName));
    notifyListeners();
  }

  void setChime(bool on) {
    if (chime == on) return;
    chime = on;
    unawaited(prefs.setBool('chime', on));
    notifyListeners();
  }

  void setStageType(bool on) {
    if (stageType == on) return;
    stageType = on;
    unawaited(prefs.setBool('stageType', on));
    notifyListeners();
  }

  void setKeepAwake(bool on) {
    if (keepAwake == on) return;
    keepAwake = on;
    unawaited(prefs.setBool('keepAwake', on));
    unawaited(effects.setAwake(on));
    notifyListeners();
  }

  /// Sends [raw] when it is a non-empty short note. A second tap of the same
  /// text inside 400ms is ignored so a bounce does not double-fire a cue.
  bool sendText(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text.length > TalkEnvelope.maxText) return false;
    final now = DateTime.now();
    if (_lastSendText == text &&
        _lastSendAt != null &&
        now.difference(_lastSendAt!) < const Duration(milliseconds: 400)) {
      return false;
    }
    final who = name.trim().isEmpty ? 'Booth' : name.trim();
    if (who.length > TalkEnvelope.maxName) return false;
    final envelope = TalkEnvelope.compose(
      name: who,
      text: text,
      instance: instanceId,
      show: showName,
    );
    _lastSendText = text;
    _lastSendAt = now;
    _mine.add(envelope.id);
    _seen.add(envelope.id);
    final wrote = transport.send(envelope);
    notes.add(TalkNote(
      id: envelope.id,
      name: who,
      text: text,
      at: envelope.at,
      mine: true,
      sent: wrote > 0,
    ));
    _trim();
    _pulseOn();
    _persist();
    notifyListeners();
    return true;
  }

  void armOrClear() {
    if (!clearArmed) {
      clearArmed = true;
      _clearTimer?.cancel();
      _clearTimer = Timer(const Duration(seconds: 2), () {
        clearArmed = false;
        notifyListeners();
      });
      notifyListeners();
      return;
    }
    _clearTimer?.cancel();
    clearArmed = false;
    notes.clear();
    heard.clear();
    _persist();
    notifyListeners();
  }

  Future<void> disposeTransport() async {
    _pulseTimer?.cancel();
    _clearTimer?.cancel();
    await _sub?.cancel();
    _sub = null;
    await transport.close();
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _clearTimer?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _onRemote(TalkEnvelope envelope) {
    if (envelope.show != showName) return;
    if (!_seen.add(envelope.id)) return;
    if (_mine.contains(envelope.id)) return;
    notes.add(TalkNote(
      id: envelope.id,
      name: envelope.name,
      text: envelope.text,
      at: envelope.at,
      mine: false,
      sent: true,
      cue: envelope.cue,
    ));
    heard.add(envelope.name);
    _trim();
    if (chime) unawaited(effects.chime());
    _pulseOn();
    _persist();
    notifyListeners();
  }

  void _apply(LinkStatus status) {
    linkOk = status.ok;
    linkError = status.error;
    ips = status.ips;
    multicast = status.multicast;
  }

  void _pulseOn() {
    pulse = true;
    _pulseTimer?.cancel();
    _pulseTimer = Timer(const Duration(milliseconds: 700), () {
      pulse = false;
      notifyListeners();
    });
  }

  void _trim() {
    if (notes.length <= _noteLimit) return;
    notes.removeRange(0, notes.length - _noteLimit);
  }

  void _loadNotes() {
    final raw = prefs.getString('notes');
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw);
      if (list is! List) return;
      for (final item in list) {
        if (item is! Map) continue;
        final id = item['id'];
        final who = item['name'];
        final text = item['text'];
        final at = item['at'];
        if (id is! String || who is! String || text is! String || at is! int) {
          continue;
        }
        notes.add(TalkNote(
          id: id,
          name: who,
          text: text,
          at: DateTime.fromMillisecondsSinceEpoch(at),
          mine: item['mine'] == true,
          sent: item['sent'] != false,
          cue: item['cue'] == true,
        ));
        _seen.add(id);
        if (item['mine'] == true) {
          _mine.add(id);
        } else {
          heard.add(who);
        }
      }
      _trim();
    } catch (_) {
      notes.clear();
      heard.clear();
    }
  }

  void _persist() {
    final payload = notes
        .map((note) => {
              'id': note.id,
              'name': note.name,
              'text': note.text,
              'at': note.at.millisecondsSinceEpoch,
              'mine': note.mine,
              'sent': note.sent,
              'cue': note.cue,
            })
        .toList();
    unawaited(prefs.setString('notes', jsonEncode(payload)));
  }

  String _clipName(String raw) {
    if (raw.length <= TalkEnvelope.maxName) return raw;
    return raw.substring(0, TalkEnvelope.maxName);
  }

  String _clipShow(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return TalkEnvelope.defaultShow;
    if (trimmed.length <= TalkEnvelope.maxShow) return trimmed;
    return trimmed.substring(0, TalkEnvelope.maxShow);
  }
}

String formatClock(DateTime time) {
  final local = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}
