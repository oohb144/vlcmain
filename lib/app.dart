import 'package:flutter/material.dart';

import 'pages/playback_page.dart';
import 'pages/settings_page.dart';
import 'shell/app_shell.dart';
import 'theme/app_theme.dart';

class VlcApp extends StatelessWidget {
  const VlcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智能门禁管理系统',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const AppShell(),
      routes: {
        '/settings': (context) => const SettingsPage(),
        '/playback': (context) => const PlaybackPage(),
      },
    );
  }
}
