import 'package:flutter/material.dart';

/// 主题配色方案
enum AppThemePreset {
  green('墨绿', [Color(0xFF2E7D32), Color(0xFF4CAF50)]),
  mono('黑白', [Color(0xFF212121), Color(0xFF9E9E9E)]),
  tomato('番茄红', [Color(0xFFE53935), Color(0xFFFF8A65)]);

  final String label;
  final List<Color> swatches;
  const AppThemePreset(this.label, this.swatches);
}

class AppTheme {
  static const Color seedColor = Color(0xFF2E7D32);

  /// 构建主题
  ///
  /// [background] 为 true 时（使用自定义背景图），
  /// Scaffold 背景改为半透明，让背景图透出，同时卡片保持不透明保证可读性。
  static ThemeData build({
    required Brightness brightness,
    AppThemePreset preset = AppThemePreset.green,
    bool background = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = _schemeFor(preset, brightness);
    final cardColor = _cardColorFor(preset, isDark);

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: _scaffoldBgFor(preset, isDark, background),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        thickness: 0.6,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.025),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: border(colorScheme.outlineVariant.withValues(alpha: 0.5)),
        enabledBorder:
            border(colorScheme.outlineVariant.withValues(alpha: 0.5)),
        focusedBorder: border(colorScheme.primary, 1.5),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardColor,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(
          fontSize: 12.5,
          color: colorScheme.onSurface,
        ),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        shape: const StadiumBorder(),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(88, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(88, 46),
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 3,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: const CircleBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? const Color(0xFF2C322C) : const Color(0xFF252A25),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : null,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
      ),
    );
  }

  static ColorScheme _schemeFor(AppThemePreset preset, Brightness brightness) {
    switch (preset) {
      case AppThemePreset.green:
        return ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: brightness,
        );
      case AppThemePreset.tomato:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935),
          brightness: brightness,
        );
      case AppThemePreset.mono:
        // 灰色种子生成去饱和的黑白配色
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF757575),
          brightness: brightness,
        );
    }
  }

  static Color _cardColorFor(AppThemePreset preset, bool isDark) {
    if (!isDark) return Colors.white;
    switch (preset) {
      case AppThemePreset.green:
        return const Color(0xFF171B17);
      case AppThemePreset.mono:
        return const Color(0xFF1A1A1A);
      case AppThemePreset.tomato:
        return const Color(0xFF1E1514);
    }
  }

  static Color _scaffoldBgFor(
      AppThemePreset preset, bool isDark, bool background) {
    if (background) {
      return isDark
          ? Colors.black.withValues(alpha: 0.72)
          : Colors.white.withValues(alpha: 0.8);
    }
    switch (preset) {
      case AppThemePreset.green:
        return isDark ? const Color(0xFF0E110E) : const Color(0xFFF5F6F3);
      case AppThemePreset.mono:
        return isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF7F7F7);
      case AppThemePreset.tomato:
        return isDark ? const Color(0xFF150F0E) : const Color(0xFFFAF5F4);
    }
  }

  /// 兼容旧调用
  static ThemeData get lightTheme => build(brightness: Brightness.light);
  static ThemeData get darkTheme => build(brightness: Brightness.dark);
}
