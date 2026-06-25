import 'package:flutter/material.dart';
import 'pages/player_page.dart';
import 'pages/settings_page.dart';
import 'pages/playback_page.dart';

class VlcApp extends StatelessWidget {
  const VlcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K230 RTSP 接收播放器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const PlayerPage(),
        '/settings': (context) => const SettingsPage(),
        '/playback': (context) => const PlaybackPage(),
      },
    );
  }
}