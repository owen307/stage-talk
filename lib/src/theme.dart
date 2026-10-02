import 'package:flutter/material.dart';

import 'talk_controller.dart';

/// Near-black panels, hairline borders, copper and teal accents.
class Dsn {
  static const bg = Color(0xFF0B0D10);
  static const bgTop = Color(0xFF15181D);
  static const panel = Color(0xFF14171C);
  static const panelRaised = Color(0xFF1B2027);
  static const panelHigh = Color(0xFF232932);
  static const hairline = Color(0xFF2A313B);
  static const text = Color(0xFFE6E9ED);
  static const textDim = Color(0xFF8A929C);
  static const textFaint = Color(0xFF5A626C);
  static const copper = Color(0xFFC17A3B);
  static const teal = Color(0xFF1FA6A6);
}

ThemeData buildStageTheme() {
  const scheme = ColorScheme.dark(
    surface: Dsn.panel,
    primary: Dsn.teal,
    secondary: Dsn.copper,
    onPrimary: Dsn.bg,
    onSurface: Dsn.text,
    error: Dsn.copper,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Dsn.bg,
    splashColor: const Color(0x221FA6A6),
    highlightColor: const Color(0x141FA6A6),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Dsn.teal,
      selectionColor: Color(0x5531C4C4),
    ),
  );
}

Color toneColor(NoteTone tone) {
  switch (tone) {
    case NoteTone.ready:
      return Dsn.teal;
    case NoteTone.hold:
      return Dsn.copper;
    case NoteTone.plain:
      return Dsn.text;
  }
}
