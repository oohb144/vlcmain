import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../models/device_status.dart';

/// 状态轮询服务：定时 HTTP GET [statusUrl]，解析为 [DeviceStatus]。
///
/// 通过 [status] / [error] 两个 [ValueNotifier] 暴露状态，供 UI 监听。
class StatusPollService {
  final String statusUrl;
  final int intervalMs;

  StatusPollService({
    required this.statusUrl,
    required this.intervalMs,
  });

  final ValueNotifier<DeviceStatus?> status = ValueNotifier<DeviceStatus?>(null);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  Timer? _timer;
  bool _running = false;

  bool get isRunning => _running;

  void start() {
    if (_running) return;
    if (statusUrl.isEmpty) {
      error.value = '状态接口 URL 未配置';
      return;
    }
    _running = true;
    // 立即触发一次，再周期触发
    _poll();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) => _poll());
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    try {
      final resp = await http
          .get(Uri.parse(statusUrl))
          .timeout(Duration(milliseconds: intervalMs * 3 + 2000));
      if (resp.statusCode != 200) {
        error.value = '状态接口返回 ${resp.statusCode}';
        return;
      }
      final body = resp.body.trim();
      if (body.isEmpty) {
        error.value = '状态接口返回空';
        return;
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      error.value = null;
      status.value = DeviceStatus.fromJson(json, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      error.value = e.toString();
    }
  }

  void dispose() {
    stop();
    status.dispose();
    error.dispose();
  }
}