import 'package:flutter/material.dart';

// 포인트 색은 이 값 하나만 바꾸면 된다.
const accent = Color(0xFFC6F24E);

const _bg = Color(0xFF0A0A0B);
const _card = Color(0xFF151517);
const _raised = Color(0xFF1D1D20);
const _field = Color(0xFF232327);
const _line = Color(0xFF2A2A2F);
const _muted = Color(0xFF8E8E95);

ThemeData buildTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: accent,
    onPrimary: Colors.black,
    primaryContainer: Color(0xFF2B3510),
    onPrimaryContainer: accent,
    secondary: accent,
    onSecondary: Colors.black,
    secondaryContainer: Color(0xFF2B3510),
    onSecondaryContainer: accent,
    error: Color(0xFFFF5C5C),
    onError: Colors.white,
    surface: _bg,
    onSurface: Color(0xFFF4F4F5),
    onSurfaceVariant: _muted,
    surfaceContainerLowest: Color(0xFF060607),
    surfaceContainerLow: Color(0xFF111113),
    surfaceContainer: _card,
    surfaceContainerHigh: _raised,
    surfaceContainerHighest: _field,
    outline: Color(0xFF3C3C42),
    outlineVariant: _line,
  );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final t = base.textTheme;
  final text = t.copyWith(
    titleLarge: t.titleLarge!.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: t.titleMedium!.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: t.bodyLarge!.copyWith(fontSize: 17),
    bodyMedium: t.bodyMedium!.copyWith(fontSize: 15),
  );
  final rounded14 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  const bigButton = Size(64, 56);
  const buttonText = TextStyle(fontSize: 17, fontWeight: FontWeight.w700);

  return base.copyWith(
    scaffoldBackgroundColor: _bg,
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: _bg,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: Color(0xFFF4F4F5),
        letterSpacing: -0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: _card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: bigButton,
        textStyle: buttonText,
        shape: rounded14,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: bigButton,
        textStyle: buttonText,
        foregroundColor: scheme.onSurface,
        side: const BorderSide(color: _line),
        backgroundColor: _raised,
        shape: rounded14,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: rounded14,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        iconSize: 24,
        foregroundColor: _muted,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      minTileHeight: 64,
      iconColor: _muted,
      subtitleTextStyle: TextStyle(fontSize: 14, color: _muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _field,
      labelStyle: const TextStyle(color: _muted),
      hintStyle: const TextStyle(color: Color(0xFF5E5E66)),
      suffixStyle: const TextStyle(color: _muted, fontSize: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accent, width: 1.5),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: _raised,
      selectedColor: accent,
      side: const BorderSide(color: _line),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: const TextStyle(color: Color(0xFFF4F4F5)),
      secondaryLabelStyle: const TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.w700,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: _raised,
        selectedBackgroundColor: accent,
        selectedForegroundColor: Colors.black,
        foregroundColor: _muted,
        side: const BorderSide(color: _line),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0E0E10),
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? accent : _muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 26,
          color: states.contains(WidgetState.selected) ? accent : _muted,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: _raised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF131315),
      surfaceTintColor: Colors.transparent,
      dragHandleColor: Color(0xFF45454C),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: _raised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF2A2A2F),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: const DividerThemeData(color: _line, space: 1),
    checkboxTheme: CheckboxThemeData(
      checkColor: const WidgetStatePropertyAll(Colors.black),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.black : _muted,
      ),
    ),
  );
}
