import 'package:flutter/material.dart';

import 'pages/playback_page.dart';
import 'pages/settings_page.dart';
import 'shell/app_shell.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode.dart';

class VlcApp extends StatefulWidget {
  const VlcApp({super.key});

  @override
  State<VlcApp> createState() => _VlcAppState();
}

class _VlcAppState extends State<VlcApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDark,
      builder: (_, dark, _) => MaterialApp(
        title: '智能门禁管理系统',
        debugShowCheckedModeBanner: false,
        theme: appTheme.copyWith(
          // 切换背景：深色模式用近黑深蓝，浅色模式用浅蓝白
          scaffoldBackgroundColor: dark ? const Color(0xFF0E1620) : AppColors.bgPrimary,
          canvasColor: dark ? const Color(0xFF0E1620) : AppColors.bgSecondary,
        ),
        home: const AppShell(),
        routes: {
          '/settings': (context) => const SettingsPage(),
          '/playback': (context) => const PlaybackPage(),
        },
      ),
    );
  }
}
