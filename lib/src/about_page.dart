import 'package:flutter/material.dart';

import 'talk_controller.dart';
import 'theme.dart';

/// Product about screen. The name on this screen is Stage Talk.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key, required this.controller});

  final TalkController controller;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late final TextEditingController _show;

  @override
  void initState() {
    super.initState();
    _show = TextEditingController(text: widget.controller.showName);
  }

  @override
  void dispose() {
    _show.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.controller;
    return Scaffold(
      backgroundColor: Dsn.bg,
      appBar: AppBar(
        backgroundColor: Dsn.bg,
        foregroundColor: Dsn.text,
        elevation: 0,
        toolbarHeight: 64,
        title: const Text(
          'Stage Talk',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                'assets/brand/stage-talk.png',
                width: 112,
                height: 112,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Stage Talk',
            key: Key('about-title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Dsn.text,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Private booth-to-stage notes on this network. No account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Dsn.textDim, fontSize: 16, height: 1.35),
          ),
          const SizedBox(height: 22),
          const _Block(
            label: 'ON THE LINK',
            body:
                'Name this device, then send a short message, up to 160 characters. Every other Stage Talk on the same LAN and the same show hears it. Stand by, Mic 2, and Hold send immediately. The thread keeps the notes, and Stage type enlarges the last line. When another app on this show fires a cue, that fire shows up in the thread. This app does not fire lighting and does not send audio. Chime plays a tone for someone else’s line. Awake keeps the display on.',
          ),
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Dsn.panel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Dsn.hairline),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SHOW',
                    style: TextStyle(
                      color: Dsn.textFaint,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('show-field'),
                    controller: _show,
                    maxLength: 32,
                    style: const TextStyle(color: Dsn.text, fontSize: 18),
                    decoration: const InputDecoration(
                      hintText: 'Main',
                      counterText: '',
                      filled: true,
                      fillColor: Dsn.panelRaised,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: link.setShow,
                    onSubmitted: link.setShow,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _Block(
            label: 'PROTOCOL',
            body:
                'Alpaca Link. Notes are type talk.message from stage-talk. JSON multicast 239.255.42.77:44771, TTL 1.\n'
                'version, source.app, source.instance, source.name, type, name, payload, timestamp, id, show.\n'
                'A cue.fire from another app on the same show is appended as a line, for example the cue name and that it went. It is not sent onward.',
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Dsn.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Dsn.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Dsn.textFaint,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                color: Dsn.text,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
