import 'dart:async';
import 'dart:io';

import 'envelope.dart';

class LinkStatus {
  const LinkStatus({
    required this.ok,
    this.error,
    this.ips = const [],
    this.multicast = false,
  });

  final bool ok;
  final String? error;
  final List<String> ips;
  final bool multicast;
}

/// Sends and receives Alpaca Link `talk.message` datagrams on the LAN.
///
/// JSON goes only to multicast [multicastGroup]:[port] with TTL [ttl].
/// Two sockets may bind [port] on one machine (`SO_REUSEPORT`). Multicast
/// loopback stays on, so a second window on this host hears the note.
abstract class TalkTransport {
  Future<LinkStatus> start();
  int send(TalkEnvelope envelope);
  Stream<TalkEnvelope> get incoming;
  Future<void> close();
}

class AlpacaLink implements TalkTransport {
  AlpacaLink({this.onListening, this.onStopped});

  /// Android acquires a Wi-Fi multicast lock here. Desktop leaves it null.
  final Future<void> Function()? onListening;
  final Future<void> Function()? onStopped;

  static const int port = 44771;
  static const String multicastGroup = '239.255.42.77';
  static const int ttl = 1;

  final StreamController<TalkEnvelope> _incoming =
      StreamController<TalkEnvelope>.broadcast();
  RawDatagramSocket? _socket;
  LinkStatus _status = const LinkStatus(ok: false);

  @override
  Stream<TalkEnvelope> get incoming => _incoming.stream;

  @override
  Future<LinkStatus> start() async {
    if (_socket != null) return _status;
    RawDatagramSocket? socket;
    try {
      socket = await _bind();
      try {
        socket.multicastLoopback = true;
      } catch (_) {}
      try {
        socket.multicastHops = ttl;
      } catch (_) {}
      final multicast = await _joinMulticast(socket);
      _socket = socket;
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final bound = _socket;
        if (bound == null) return;
        Datagram? dg;
        while ((dg = bound.receive()) != null) {
          final env = TalkEnvelope.tryParse(dg!.data);
          if (env != null && !_incoming.isClosed) {
            _incoming.add(env);
          }
        }
      }, onError: (_) {});
      final listening = onListening;
      if (listening != null) unawaited(listening());
      _status = LinkStatus(
        ok: true,
        ips: await _localIps(),
        multicast: multicast,
      );
      return _status;
    } catch (error) {
      socket?.close();
      _socket = null;
      _status = LinkStatus(ok: false, error: humanBindError(error));
      return _status;
    }
  }

  @override
  int send(TalkEnvelope envelope) {
    final socket = _socket;
    if (socket == null) return 0;
    try {
      socket.multicastHops = ttl;
    } catch (_) {}
    try {
      return socket.send(envelope.encode(), InternetAddress(multicastGroup), port);
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> close() async {
    final socket = _socket;
    _socket = null;
    socket?.close();
    _status = const LinkStatus(ok: false, error: 'Link closed');
    final stopped = onStopped;
    if (stopped != null) {
      try {
        await stopped();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await close();
    if (!_incoming.isClosed) await _incoming.close();
  }

  Future<RawDatagramSocket> _bind() async {
    try {
      return await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
        reusePort: true,
      );
    } catch (_) {
      return RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
      );
    }
  }

  Future<bool> _joinMulticast(RawDatagramSocket socket) async {
    final group = InternetAddress(multicastGroup);
    try {
      socket.joinMulticast(group);
      return true;
    } catch (_) {}
    var joined = false;
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: true,
      );
      for (final iface in ifaces) {
        try {
          socket.joinMulticast(group, iface);
          joined = true;
        } catch (_) {}
      }
    } catch (_) {}
    return joined;
  }

  Future<List<String>> _localIps() async {
    final ips = <String>[];
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: true,
      );
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          if (!addr.isMulticast && !ips.contains(addr.address)) {
            ips.add(addr.address);
          }
        }
      }
    } catch (_) {}
    return ips;
  }

}

String humanBindError(Object error) {
  final raw = error.toString().toLowerCase();
  if (raw.contains('address already in use') ||
      raw.contains('eaddrinuse') ||
      raw.contains('errno = 98')) {
    return 'UDP ${AlpacaLink.port} is already open on this device.';
  }
  return 'Could not open UDP ${AlpacaLink.port}.';
}
