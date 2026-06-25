import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stream_config.dart';

/// 配置持久化服务：基于 SharedPreferences 保存 [StreamConfig]。
class ConfigService {
  static const _key = 'stream_config';

  static StreamConfig? _cache;

  /// 加载配置；若不存在则返回默认配置。
  static Future<StreamConfig> load() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      _cache = const StreamConfig();
      return _cache!;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _cache = StreamConfig.fromJson(json);
    } catch (_) {
      _cache = const StreamConfig();
    }
    return _cache!;
  }

  /// 保存配置。
  static Future<void> save(StreamConfig config) async {
    _cache = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(config.toJson()));
  }
}