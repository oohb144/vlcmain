import 'package:flutter/material.dart';

/// 应用色板：对齐 smart-door-ui.html 的 GitHub 深色风格。
///
/// 全应用只有一套深色主题，故用静态常量而非 ThemeExtension，
/// 既能在 ThemeData 构建时直接引用，也能在任意 widget 取色。
class AppColors {
  AppColors._();

  // 背景
  static const bgPrimary = Color(0xFF0D1117);
  static const bgSecondary = Color(0xFF161B22);
  static const bgCard = Color(0xFF1C2128);
  static const bgHover = Color(0xFF21262D);
  static const bgInput = Color(0xFF0D1117);

  // 边框 / 分隔
  static const border = Color(0xFF30363D);

  // 文本
  static const textPrimary = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B949E);
  static const textMuted = Color(0xFF6E7681);

  // 强调色
  static const accent = Color(0xFF58A6FF);
  static const accentDim = Color(0xFF1F3A5F);

  // 状态色
  static const green = Color(0xFF3FB950);
  static const greenDim = Color(0xFF1A3A2A);
  static const red = Color(0xFFF85149);
  static const redDim = Color(0xFF3D1A1A);
  static const yellow = Color(0xFFD29922);
  static const yellowDim = Color(0xFF3D2E0A);
  static const purple = Color(0xFFBC8CFF);
  static const purpleDim = Color(0xFF2A1A3D);

  /// 字体族：桌面/移动均回退到系统中文黑体。
  static const fontFamily = null;
}
