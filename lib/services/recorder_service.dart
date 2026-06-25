import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'rtsp_service.dart';
import 'ffmpeg_recorder_service.dart';

/// 录像服务统一接口。
///
/// 两套实现，按平台分发（见 [createRecorder]）：
/// - 桌面端（Windows/Linux/macOS）：[FfmpegRecorderService]，spawn ffmpeg
///   子进程独立拉 RTSP 流，`-c copy` 不转码落盘 `.ts`。独立于播放器，
///   不影响推流播放，是桌面端最可靠的方式。
/// - 移动端（Android）：[MpvRecorderService]，借助 mpv 的 `stream-record`
///   属性，随播放器 open 一起把原始流复制到本地文件。Android 无系统 ffmpeg
///   二进制，只能走这条路。
abstract class RecorderService {
  bool get isRecording;
  String? get currentFile;

  /// 开始录像。成功返回输出文件绝对路径，失败抛异常（消息用于 UI 提示）。
  Future<String> start({
    required String rtspUrl,
    required String dir,
    String ffmpegPath,
  });

  /// 停止录像：写文件尾、清理状态。
  Future<void> stop();

  Future<void> dispose();
}

/// 按平台创建录像服务。
RecorderService createRecorder(RtspService rtsp) {
  if (Platform.isAndroid || Platform.isIOS) {
    return MpvRecorderService(rtsp);
  }
  // 桌面端用 ffmpeg 子进程
  return FfmpegRecorderService();
}

/// 生成录像文件路径（不实际创建文件，由录像器写入）。
/// [dir] 为录像目录；为空返回 null。
Future<String?> buildRecordPath(String dir) async {
  if (dir.isEmpty) return null;
  try {
    final d = Directory(dir);
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
  } catch (_) {
    // 目录创建失败也继续，写入时若失败会通过流表现
  }
  final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  var path = p.absolute(p.join(dir, 'rec_$now.ts'));
  // Windows 上 mpv/ffmpeg 接受正斜杠，统一归一化避免反斜杠转义问题
  path = path.replaceAll(r'\', '/');
  return path;
}

/// Android 端录像实现：基于 mpv `stream-record` 属性。
///
/// 关键约束：`stream-record` 必须在 **open 之前** 设置才生效（开播后再设无效）。
/// 因此开始/停止录像都通过"重新 open 流、带或不带录像路径"实现。
/// 录像时还必须切到 [RtspService.applyRecordablePrefs]（启用可寻址缓存），
/// 因为 low-latency profile 会禁用 cache 导致 stream-record 不可用。
class MpvRecorderService implements RecorderService {
  final RtspService _rtsp;
  String? _currentFile;
  String _url = '';

  MpvRecorderService(this._rtsp);

  @override
  bool get isRecording => _currentFile != null;
  @override
  String? get currentFile => _currentFile;

  @override
  Future<String> start({
    required String rtspUrl,
    required String dir,
    String ffmpegPath = 'ffmpeg',
  }) async {
    if (rtspUrl.isEmpty) throw Exception('RTSP 地址为空');
    final path = await buildRecordPath(dir);
    if (path == null) throw Exception('录像路径生成失败');
    _url = rtspUrl;
    _currentFile = path;
    try {
      // 顺序很重要：先切可寻址缓存参数，再设 stream-record，最后 open
      await _rtsp.applyRecordablePrefs();
      await _rtsp.setProperty('stream-record', path);
      await _rtsp.open(rtspUrl, recordPath: path);
    } catch (e) {
      _currentFile = null;
      throw Exception('开始录像失败: $e');
    }
    return path;
  }

  @override
  Future<void> stop() async {
    if (_currentFile == null) return;
    // 切回低延迟参数 + reopen 不带录像路径，让 mpv 关闭录制并写文件尾
    try {
      await _rtsp.applyRtspPrefs();
      await _rtsp.setProperty('stream-record', '');
      if (_url.isNotEmpty) {
        await _rtsp.open(_url, recordPath: null);
      }
    } catch (_) {}
    _currentFile = null;
  }

  @override
  Future<void> dispose() async {
    // 不释放 _rtsp（由 PlayerPage 持有并释放）
  }
}
