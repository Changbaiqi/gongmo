// ============================================================
// 主题构建（app/theme）
// 职责：定义 8 套配色预设，并基于 Material 3 生成亮/暗两套 ThemeData
// 关联：ThemeController（保存当前预设/模式）、main.dart（构建 GetMaterialApp 主题）
// ============================================================

import 'package:flutter/material.dart';

/// 主题配色方案：label 为设置页展示名，swatches 为预览色板
enum AppThemePreset {
  sakura('粉白', [Color(0xFFEC5F92), Color(0xFFF9C5DA)]),
  green('墨绿', [Color(0xFF2E7D32), Color(0xFF4CAF50)]),
  mono('黑白', [Color(0xFF212121), Color(0xFF9E9E9E)]),
  tomato('番茄红', [Color(0xFFE53935), Color(0xFFFF8A65)]),
  ocean('海洋蓝', [Color(0xFF1565C0), Color(0xFF42A5F5)]),
  starry('星夜', [Color(0xFF3B4A8F), Color(0xFF7C89CF), Color(0xFFF0B954)]),
  morandi('莫兰迪', [Color(0xFF8FA397), Color(0xFFC9B7A6), Color(0xFFA79BB0)]),
  grape('葡萄紫', [Color(0xFF7B1FA2), Color(0xFFBA68C8)]);

  final String label;
  final List<Color> swatches;
  const AppThemePreset(this.label, this.swatches);
}

/// 全局主题工厂：所有 ThemeData 均由此构建，
/// 保证按钮/卡片/输入框/弹窗等组件在各配色下风格一致
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

  /// 生成配色：多数预设用单色种子；starry/morandi 用三色种子；
  /// sakura 浅色额外覆写主色，避免 fromSeed 生成的粉色偏暗沉
  static ColorScheme _schemeFor(AppThemePreset preset, Brightness brightness) {
    switch (preset) {
      case AppThemePreset.sakura:
        final base = ColorScheme.fromSeed(
          seedColor: const Color(0xFFF06292),
          brightness: brightness,
        );
        if (brightness == Brightness.dark) return base;
        // 浅色：覆写为更鲜艳的樱花少女粉（fromSeed 默认 primary 偏暗沉）
        return base.copyWith(
          primary: const Color(0xFFEC5F92),
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFFFD9E7),
          onPrimaryContainer: const Color(0xFF701A45),
          secondary: const Color(0xFFF28BB4),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFFDE4EF),
          onSecondaryContainer: const Color(0xFF5D2A40),
          tertiary: const Color(0xFFF6A589),
          tertiaryContainer: const Color(0xFFFFE0D4),
          onTertiaryContainer: const Color(0xFF5C2E1D),
          surface: const Color(0xFFFFF4F8),
        );
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
      case AppThemePreset.ocean:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: brightness,
        );
      case AppThemePreset.starry:
        return _triColorScheme(
          const Color(0xFF3B4A8F),
          const Color(0xFF7C89CF),
          const Color(0xFFD99A2B),
          brightness,
        );
      case AppThemePreset.morandi:
        return _triColorScheme(
          const Color(0xFF8FA397),
          const Color(0xFFC9B7A6),
          const Color(0xFFA79BB0),
          brightness,
        );
      case AppThemePreset.grape:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B1FA2),
          brightness: brightness,
        );
    }
  }

  /// 三色主题：主色/次色/第三色分别作为 primary/secondary/tertiary 的种子，
  /// 三种颜色都会真实影响界面的不同部分
  static ColorScheme _triColorScheme(
    Color primarySeed,
    Color secondarySeed,
    Color tertiarySeed,
    Brightness brightness,
  ) {
    final base =
        ColorScheme.fromSeed(seedColor: primarySeed, brightness: brightness);
    final sec =
        ColorScheme.fromSeed(seedColor: secondarySeed, brightness: brightness);
    final ter =
        ColorScheme.fromSeed(seedColor: tertiarySeed, brightness: brightness);
    return base.copyWith(
      secondary: sec.secondary,
      onSecondary: sec.onSecondary,
      secondaryContainer: sec.secondaryContainer,
      onSecondaryContainer: sec.onSecondaryContainer,
      tertiary: ter.tertiary,
      onTertiary: ter.onTertiary,
      tertiaryContainer: ter.tertiaryContainer,
      onTertiaryContainer: ter.onTertiaryContainer,
    );
  }

  /// 卡片底色：亮色统一白色；暗色为每套预设单独调校的深色，避免纯黑发闷
  static Color _cardColorFor(AppThemePreset preset, bool isDark) {
    if (!isDark) return Colors.white;
    switch (preset) {
      case AppThemePreset.sakura:
        return const Color(0xFF32262C);
      case AppThemePreset.green:
        return const Color(0xFF171B17);
      case AppThemePreset.mono:
        return const Color(0xFF1A1A1A);
      case AppThemePreset.tomato:
        return const Color(0xFF1E1514);
      case AppThemePreset.ocean:
        return const Color(0xFF14181D);
      case AppThemePreset.starry:
        return const Color(0xFF161826);
      case AppThemePreset.morandi:
        return const Color(0xFF1A1917);
      case AppThemePreset.grape:
        return const Color(0xFF171319);
    }
  }

  /// 页面底色：使用背景图时改为半透明让图片透出；
  /// 否则按预设取值（sakura 与 Android 原生开屏色对齐，避免启动闪色差）
  static Color _scaffoldBgFor(
      AppThemePreset preset, bool isDark, bool background) {
    if (background) {
      return isDark
          ? Colors.black.withValues(alpha: 0.72)
          : Colors.white.withValues(alpha: 0.8);
    }
    switch (preset) {
      case AppThemePreset.sakura:
        // 与原生侧 values/colors.xml 的 gm_background 对齐，开屏过渡无色差
        return isDark ? const Color(0xFF251B21) : const Color(0xFFFFF2F7);
      case AppThemePreset.green:
        return isDark ? const Color(0xFF0E110E) : const Color(0xFFF5F6F3);
      case AppThemePreset.mono:
        return isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF7F7F7);
      case AppThemePreset.tomato:
        return isDark ? const Color(0xFF150F0E) : const Color(0xFFFAF5F4);
      case AppThemePreset.ocean:
        return isDark ? const Color(0xFF0D1114) : const Color(0xFFF4F6F8);
      case AppThemePreset.starry:
        return isDark ? const Color(0xFF0F1020) : const Color(0xFFF5F5F9);
      case AppThemePreset.morandi:
        return isDark ? const Color(0xFF121110) : const Color(0xFFF6F5F2);
      case AppThemePreset.grape:
        return isDark ? const Color(0xFF100D12) : const Color(0xFFF8F5F9);
    }
  }

  /// 兼容旧调用
  static ThemeData get lightTheme => build(brightness: Brightness.light);
  static ThemeData get darkTheme => build(brightness: Brightness.dark);
}
