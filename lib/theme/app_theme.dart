import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 应用深色主题：基于 [AppColors] 的 GitHub 风暗色调。
///
/// Material 3 的默认 dark 用 #1C1C1C 系灰，这里整体替换为 #0D1117/​#161B22，
/// 让 Scaffold/卡片/导航栏与参考 HTML 一致。
ThemeData get appTheme {
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bgPrimary,
    canvasColor: AppColors.bgSecondary,
    colorScheme: const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.purple,
      onSecondary: Colors.black,
      error: AppColors.red,
      onError: Colors.white,
      surface: AppColors.bgCard,
      onSurface: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgSecondary,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.bgCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textSecondary,
      textColor: AppColors.textPrimary,
    ),
    iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 20),
    textTheme: _textTheme,
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgInput,
      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      floatingLabelStyle: TextStyle(color: AppColors.accent, fontSize: 13),
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        borderSide: BorderSide(color: AppColors.accent),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: AppColors.border,
      thumbColor: AppColors.accent,
      overlayColor: AppColors.accent.withValues(alpha: 0.2),
      trackHeight: 3,
    ),
    switchTheme: const SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStatePropertyAll(AppColors.border),
      trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.bgSecondary,
      indicatorColor: AppColors.accentDim,
      selectedIconTheme: const IconThemeData(color: AppColors.accent, size: 22),
      unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary, size: 20),
      selectedLabelTextStyle: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelTextStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      labelType: NavigationRailLabelType.all,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bgSecondary,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 11),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.bgHover,
      side: BorderSide(color: AppColors.border),
      labelStyle: TextStyle(color: AppColors.textPrimary, fontSize: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accentDim,
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.accent),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        textStyle: const TextStyle(fontSize: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        textStyle: const TextStyle(fontSize: 12),
      ),
    ),
  );
}

const _textTheme = TextTheme(
  // 顶栏标题 / 面包屑
  titleMedium: TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  ),
  // 分区标题（卡片标题）
  titleSmall: TextStyle(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  ),
  bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 13),
  bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 12),
  labelLarge: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
  labelSmall: TextStyle(color: AppColors.textMuted, fontSize: 11),
);
