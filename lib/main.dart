import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'app.dart';
import 'services/config_service.dart';

Future<void> main() async {
  // 入口：先初始化 media_kit，再加载配置，最后启动 App
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await ConfigService.load();
  runApp(const VlcApp());
}