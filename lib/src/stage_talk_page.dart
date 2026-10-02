import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'about_page.dart';
import 'alpaca_link.dart';
import 'envelope.dart';
import 'talk_controller.dart';
import 'theme.dart';

class StageTalkApp extends StatelessWidget {
  const StageTalkApp({super.key, required this.controller});

  final TalkController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stage Talk',
      debugShowCheckedModeBanner: false,
      theme: buildStageTheme(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = media.textScaler.scale(1).clamp(1.0, 1.2);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: StageTalkPage(controller: controller),
    );
  }
}

class StageTalkPage extends StatefulWidget {
  const StageTalkPage({super.key, required this.controller});

  final TalkController controller;

  @override
  State<StageTalkPage> createState() => _StageTalkPageState();
}

class _StageTalkPageState extends State<StageTalkPage> {
  final _note = TextEditingController();
  final _name = TextEditingController();
  final _noteFocus = FocusNode();
  final _nameFocus = FocusNode();

  TalkController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _name.text = controller.name;
    _note.addListener(() => setState(() {}));
    _nameFocus.addListener(() => setState(() {}));
    controller.addListener(_onController);
  }

  void _onController() {
    if (!_nameFocus.hasFocus && _name.text != controller.name) {
      _name.value = TextEditingValue(
        text: controller.name,
        selection: TextSelection.collapsed(offset: controller.name.length),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_onController);
    _note.dispose();
    _name.dispose();
    _noteFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _sendField() {
    final text = _note.text;
    if (!controller.sendText(text)) return;
    _note.clear();
    _noteFocus.requestFocus();
    HapticFeedback.mediumImpact();
  }

  void _sendPreset(String text) {
    if (!controller.sendText(text)) return;
    HapticFeedback.mediumImpact();
  }

  void _pickName(String value) {
    _nameFocus.unfocus();
    _name.text = value;
    controller.setName(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Dsn.bgTop, Dsn.bg],
            stops: [0, 0.32],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final dock = _Dock(
                controller: controller,
                name: _name,
                nameFocus: _nameFocus,
                note: _note,
                noteFocus: _noteFocus,
                short: constraints.maxHeight < 560,
                onPickName: _pickName,
                onSendField: _sendField,
                onPreset: _sendPreset,
                onAbout: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AboutPage(controller: controller),
                    ),
                  );
                },
              );
              final thread = _Thread(
                controller: controller,
                stageType: controller.stageType,
              );
              if (!wide) {
                return Column(
                  children: [
                    _Header(controller: controller),
                    if (controller.stageType)
                      SizedBox(
                        height: (constraints.maxHeight * 0.36).clamp(180, 340),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: _StageGlass(controller: controller),
                        ),
                      ),
                    Expanded(child: thread),
                    dock,
                  ],
                );
              }
              return Column(
                children: [
                  _Header(controller: controller),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            children: [
                              Expanded(child: thread),
                              dock,
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                            child: _StageGlass(controller: controller),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final TalkController controller;

  @override
  Widget build(BuildContext context) {
    final live = controller.linkOk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/brand/stage-talk.png',
              width: 40,
              height: 40,
              filterQuality: FilterQuality.medium,
              semanticLabel: 'Stage Talk',
            ),
          ),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(left: 10, right: 10, top: 2),
            decoration: BoxDecoration(
              color: live ? Dsn.teal : Dsn.copper,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (live ? Dsn.teal : Dsn.copper).withValues(alpha: 0.65),
                  blurRadius: live ? 8 : 0,
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stage Talk',
                  key: Key('product-title'),
                  style: TextStyle(
                    color: Dsn.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 2),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    controller.linkLabel,
                    key: const Key('link-label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: live ? Dsn.textDim : Dsn.copper,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _HeaderToggle(
            key: const Key('chime'),
            label: 'CHIME',
            tooltip: 'Play a cue tone when a note arrives',
            on: controller.chime,
            icon: controller.chime
                ? Icons.notifications_active
                : Icons.notifications_off_outlined,
            onTap: () => controller.setChime(!controller.chime),
          ),
          const SizedBox(width: 8),
          _HeaderToggle(
            key: const Key('awake'),
            label: 'AWAKE',
            tooltip: 'Keep the display on',
            on: controller.keepAwake,
            icon: controller.keepAwake
                ? Icons.wb_sunny_outlined
                : Icons.bedtime_outlined,
            onTap: () => controller.setKeepAwake(!controller.keepAwake),
          ),
        ],
      ),
    );
  }
}

class _HeaderToggle extends StatelessWidget {
  const _HeaderToggle({
    super.key,
    required this.label,
    required this.tooltip,
    required this.on,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool on;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: on ? Dsn.teal.withValues(alpha: 0.16) : Dsn.panelRaised,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Ink(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: on ? Dsn.teal : Dsn.hairline),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: on ? Dsn.teal : Dsn.textDim),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: on ? Dsn.teal : Dsn.textFaint,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thread extends StatelessWidget {
  const _Thread({required this.controller, required this.stageType});

  final TalkController controller;
  final bool stageType;

  @override
  Widget build(BuildContext context) {
    final hearing = controller.heard.toList()..sort();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Dsn.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: controller.pulse ? Dsn.teal : Dsn.hairline,
            width: controller.pulse ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  const Text(
                    'LOG',
                    style: TextStyle(
                      color: Dsn.textFaint,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hearing.isEmpty
                          ? 'HEARING  —'
                          : 'HEARING  ${hearing.join('  ·  ')}',
                      key: const Key('hearing'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Dsn.textDim,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('clear-log'),
                    onPressed: controller.notes.isEmpty
                        ? null
                        : controller.armOrClear,
                    child: Text(
                      controller.clearArmed ? 'CONFIRM' : 'CLEAR',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Dsn.hairline),
            Expanded(
              child: controller.notes.isEmpty
                  ? const _EmptyLog()
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      itemCount: controller.notes.length,
                      itemBuilder: (context, index) {
                        final note = controller
                            .notes[controller.notes.length - 1 - index];
                        final cue = controller.notes.length - index;
                        return _NoteRow(
                          key: ValueKey(note.id),
                          note: note,
                          cue: cue,
                          large: stageType,
                        );
                      },
                    ),
            ),
            if (!controller.linkOk)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _LinkDown(controller: controller),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLog extends StatelessWidget {
  const _EmptyLog();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Channel clear',
            style: TextStyle(
              color: Dsn.text,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Stand by, Mic 2, and Hold reach every Stage Talk on this network. Typed notes do too.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Dsn.textDim, fontSize: 14, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _LinkDown extends StatelessWidget {
  const _LinkDown({required this.controller});

  final TalkController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Dsn.copper.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Dsn.copper.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              controller.linkError ??
                  'Could not open UDP ${AlpacaLink.port}.',
              style: const TextStyle(color: Dsn.text, fontSize: 14, height: 1.3),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 52,
            child: FilledButton(
              key: const Key('link-retry'),
              style: FilledButton.styleFrom(
                backgroundColor: Dsn.copper,
                foregroundColor: Dsn.bg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: controller.retry,
              child: const Text(
                'RETRY',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    super.key,
    required this.note,
    required this.cue,
    required this.large,
  });

  final TalkNote note;
  final int cue;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final tone = toneFor(note.text);
    final color = toneColor(tone);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Dsn.panelRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Dsn.hairline),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: note.mine ? Dsn.textFaint : color,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            cue.toString().padLeft(2, '0'),
                            style: const TextStyle(
                              color: Dsn.textFaint,
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            formatClock(note.at),
                            style: const TextStyle(
                              color: Dsn.textFaint,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const Spacer(),
                          Text(
                            note.name.toUpperCase(),
                            style: TextStyle(
                              color: note.mine ? Dsn.textDim : color,
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          if (!note.sent) ...[
                            const SizedBox(width: 8),
                            const Text(
                              'NOT SENT',
                              style: TextStyle(
                                color: Dsn.copper,
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        note.text,
                        style: TextStyle(
                          color: Dsn.text,
                          fontSize: large ? 32 : 22,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageGlass extends StatelessWidget {
  const _StageGlass({required this.controller});

  final TalkController controller;

  @override
  Widget build(BuildContext context) {
    final note = controller.notes.isEmpty ? null : controller.notes.last;
    final tone = note == null ? NoteTone.plain : toneFor(note.text);
    final color = note == null ? Dsn.textFaint : toneColor(tone);
    return Semantics(
      liveRegion: true,
      label: note == null
          ? 'Waiting for a note'
          : '${note.name} says ${note.text}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Dsn.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: controller.pulse ? color : Dsn.hairline,
            width: controller.pulse ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'STAGE',
                style: TextStyle(
                  color: Dsn.copper,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                note == null
                    ? 'WAITING'
                    : '${note.name.toUpperCase()}   ${formatClock(note.at)}',
                key: const Key('stage-meta'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Dsn.textDim,
                  fontSize: 13,
                  fontFamily: 'monospace',
                  letterSpacing: 0.6,
                ),
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      note?.text ?? '—',
                      key: const Key('stage-glass'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color,
                        fontSize: 112,
                        height: 0.92,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const Text(
                'Last note on this device. Readable from the deck.',
                style: TextStyle(color: Dsn.textFaint, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dock extends StatelessWidget {
  const _Dock({
    required this.controller,
    required this.name,
    required this.nameFocus,
    required this.note,
    required this.noteFocus,
    required this.short,
    required this.onPickName,
    required this.onSendField,
    required this.onPreset,
    required this.onAbout,
  });

  final TalkController controller;
  final TextEditingController name;
  final FocusNode nameFocus;
  final TextEditingController note;
  final FocusNode noteFocus;
  final bool short;
  final ValueChanged<String> onPickName;
  final VoidCallback onSendField;
  final ValueChanged<String> onPreset;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final presetHeight = short ? 60.0 : 76.0;
    final canSend = note.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Dsn.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Dsn.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 680;
                  final chips = Row(
                    children: [
                      for (final value in TalkController.quickNames) ...[
                        _NameChip(
                          label: value,
                          selected: controller.name.trim() == value,
                          onTap: () => onPickName(value),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  );
                  final field = SizedBox(
                    height: 48,
                    width: stacked ? null : 160,
                    child: TextField(
                      key: const Key('name-field'),
                      controller: name,
                      focusNode: nameFocus,
                      maxLength: 24,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: Dsn.text, fontSize: 16),
                      decoration: _fieldDecoration('Name'),
                      onChanged: controller.setName,
                      onSubmitted: controller.setName,
                    ),
                  );
                  final type = _TypeToggle(
                    stage: controller.stageType,
                    onChanged: controller.setStageType,
                  );
                  if (stacked) {
                    return Column(
                      children: [
                        SizedBox(
                          height: 48,
                          child: Row(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: chips,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(child: field),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        type,
                      ],
                    );
                  }
                  return SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: chips,
                          ),
                        ),
                        field,
                        const SizedBox(width: 8),
                        type,
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: presetHeight,
                child: Row(
                  children: [
                    for (var i = 0; i < TalkController.presets.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _PresetButton(
                          label: TalkController.presets[i],
                          height: presetHeight,
                          onTap: () => onPreset(TalkController.presets[i]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: short ? 52 : 60,
                      child: TextField(
                        key: const Key('note-field'),
                        controller: note,
                        focusNode: noteFocus,
                        maxLength: TalkEnvelope.maxText,
                        textInputAction: TextInputAction.send,
                        style: const TextStyle(
                          color: Dsn.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: _fieldDecoration('Short note'),
                        onSubmitted: (_) => onSendField(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 96,
                    height: short ? 52 : 60,
                    child: FilledButton(
                      key: const Key('send'),
                      style: FilledButton.styleFrom(
                        backgroundColor: canSend ? Dsn.teal : Dsn.panelHigh,
                        foregroundColor: canSend ? Dsn.bg : Dsn.textFaint,
                        disabledBackgroundColor: Dsn.panelHigh,
                        disabledForegroundColor: Dsn.textFaint,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: canSend ? onSendField : null,
                      child: const Text(
                        'SEND',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (note.text.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, right: 104),
                    child: Text(
                      '${note.text.length}/${TalkEnvelope.maxText}',
                      style: const TextStyle(
                        color: Dsn.textFaint,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'LAN  ·  JSON UDP  ·  NO ACCOUNT',
                      style: TextStyle(
                        color: Dsn.textFaint,
                        fontSize: 10,
                        letterSpacing: 1.4,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('about'),
                    style: TextButton.styleFrom(
                      foregroundColor: Dsn.textDim,
                      minimumSize: const Size(72, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: onAbout,
                    child: const Text(
                      'ABOUT',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Dsn.textFaint, fontSize: 16),
    counterText: '',
    filled: true,
    fillColor: Dsn.panelRaised,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Dsn.hairline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Dsn.hairline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Dsn.teal, width: 1.4),
    ),
  );
}

class _NameChip extends StatelessWidget {
  const _NameChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Dsn.teal.withValues(alpha: 0.16) : Dsn.panelRaised,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? Dsn.teal : Dsn.hairline),
          ),
          child: Center(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: selected ? Dsn.teal : Dsn.textDim,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.stage, required this.onChanged});

  final bool stage;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('type-toggle'),
      height: 48,
      width: 176,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Dsn.panelRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Dsn.hairline),
        ),
        child: Row(
          children: [
            _TypeSide(
              label: 'DENSE',
              selected: !stage,
              onTap: () => onChanged(false),
            ),
            _TypeSide(
              label: 'STAGE',
              selected: stage,
              onTap: () => onChanged(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeSide extends StatelessWidget {
  const _TypeSide({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: selected ? Dsn.panelHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Dsn.text : Dsn.textFaint,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.label,
    required this.height,
    required this.onTap,
  });

  final String label;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = toneFor(label);
    final color = toneColor(tone);
    final slug = label.toLowerCase().replaceAll(' ', '-');
    return Tooltip(
      message: 'Send “$label”',
      child: Material(
        color: color.withValues(alpha: tone == NoteTone.plain ? 0.0 : 0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: Key('preset-$slug'),
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: tone == NoteTone.plain ? Dsn.hairline : color,
              ),
              color: tone == NoteTone.plain ? Dsn.panelRaised : null,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
