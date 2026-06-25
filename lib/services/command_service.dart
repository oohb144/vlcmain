import 'dart:convert';
import 'package:http/http.dart' as http;

/// 指令下发服务：HTTP POST JSON 到 K230 的 [commandUrl]。
class CommandService {
  final String commandUrl;

  CommandService(this.commandUrl);

  /// 下发指令。[payload] 会被 JSON 编码后作为请求体发送。
  /// 返回 true 表示 K230 返回 2xx。
  Future<({bool ok, String message})> send(Map<String, dynamic> payload) async {
    if (commandUrl.isEmpty) {
      return (ok: false, message: '下发接口 URL 未配置');
    }
    try {
      final resp = await http.post(
        Uri.parse(commandUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));
      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      return (
        ok: ok,
        message: ok ? '下发成功' : '返回 ${resp.statusCode}: ${resp.body}',
      );
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }
}