import 'package:flutter/material.dart';

/// 应用色板：天蓝 + 浅绿 + 白色清新浅色风。
///
/// 白底浅蓝背景 + 天蓝强调色 + 浅绿状态色，视频区仍用黑色。
/// 全应用只有一套浅色主题，故用静态常量而非 ThemeExtension。
class AppColors {
  AppColors._();

  // 背景（浅蓝白系）
  static const bgPrimary = Color(0xFFF0F6FA);
  static const bgSecondary = Color(0xFFFFFFFF);
  static const bgCard = Color(0xFFFFFFFF);
  static const bgHover = Color(0xFFE8F1F7);
  static const bgInput = Color(0xFFF5F9FC);

  // 边框 / 分隔
  static const border = Color(0xFFD1E0EC);

  // 文本（深蓝灰）
  static const textPrimary = Color(0xFF1B2A3A);
  static const textSecondary = Color(0xFF5C7488);
  static const textMuted = Color(0xFF94A8BA);

  // 强调色（天蓝）
  static const accent = Color(0xFF3B9AE0);
  static const accentDim = Color(0xFFE1F0FB);

  // 状态色（浅绿 + 暖警告）
  static const green = Color(0xFF4EC07A);
  static const greenDim = Color(0xFFE6F6EC);
  static const red = Color(0xFFE8727A);
  static const redDim = Color(0xFFFBE9EB);
  static const yellow = Color(0xFFE8A547);
  static const yellowDim = Color(0xFFFBF0DC);
  // 浅绿，用于渐变终点（logo 天蓝→浅绿）
  static const purple = Color(0xFF4EC07A);
  static const purpleDim = Color(0xFFE6F6EC);
}
