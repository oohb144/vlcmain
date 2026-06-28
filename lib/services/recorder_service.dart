import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'rtsp_service.dart';
import 'ffmpeg_recorder_service.dart';
import 'ffmpeg_kit_recorder_service.dart';

/// 录像服务统一接口。
///
/// 两套实现，按平台分发（见 [createRecorder]）：
/// - 桌面端（Windows/Linux/macOS）：[FfmpegRecorderService]，spawn ffmpeg
///   子进程独立拉 RTSP 流，`-c copy` 不转码落盘 `.ts`。独立于播放器，
///   不影响推流播放，是桌面端最可靠的方式。
/// - 移动端（Android）：[FfmpegKitRecorderService]，用 FFmpegKit 库内调用
///   拉 RTSP 流落盘。media_kit 的 Android 预编译 libmpv 未编入输出 muxer，
///   mpv `stream-record` 在 Android 写不出文件，只能改走 FFmpegKit。
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
  if (Platform.isAndroid) {
    // Android：FFmpegKit 库内调用（自带 ffmpeg，无需外部二进制）。
    return FfmpegKitRecorderService();
  }
  if (Platform.isIOS) {
    // iOS：暂用 mpv stream-record（如需可靠录像可同样接 FFmpegKit，先不管）。
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
      // 先停掉当前流，保证 open 时 mpv 真正重建流并读取 stream-record
      // （对已在播的同 URL，open 可能不重建，导致 stream-record 不生效）
      await _rtsp.stop();
      // 顺序很重要：先切内存缓存参数，再设 stream-record，最后 open
      await _rtsp.applyRecordablePrefs();
      await _rtsp.setProperty('stream-record', path);
      await _rtsp.open(rtspUrl, recordPath: path);
      // 落盘校验：open 后等 1.5s，确认文件已出现且在增长，否则判定未生效
      final ok = await _verifyRecordingStarted(path);
      if (!ok) {
        // 回滚：清掉 stream-record，避免角标假亮
        try {
          await _rtsp.setProperty('stream-record', '');
        } catch (_) {}
        _currentFile = null;
        throw Exception('mpv 录像未生效（未生成文件），可能不兼容此流');
      }
    } catch (e) {
      _currentFile = null;
      throw Exception('开始录像失败: $e');
    }
    return path;
  }

  /// 校验录像文件是否真的开始写入：等 1.5s 后检查文件存在且 size>0。
  Future<bool> _verifyRecordingStarted(String path) async {
    try {
      final f = File(path);
      for (var i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await f.exists() && (await f.length()) > 0) {
          return true;
        }
      }
    } catch (_) {}
    return false;
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
