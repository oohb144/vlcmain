import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/log.dart';
import 'package:flutter/foundation.dart';

import 'recorder_service.dart';

/// Android 端录像实现：基于 FFmpegKit（库内调用，非子进程）。
///
/// media_kit 的 Android 预编译 libmpv 未编入 FFmpeg 输出 muxer，mpv
/// `stream-record` 在 Android 写不出文件（见 [MpvRecorderService] 的
/// 根因说明）。这里改用 `ffmpeg_kit_flutter_new`（full GPL，含 mpegts），
/// 让 FFmpegKit 自己拉 RTSP 流、`-c copy` 封装进 `.ts` 落盘，与桌面端
/// ffmpeg 子进程方案思路一致。
///
/// 关键差异（相对 [FfmpegRecorderService]）：
/// - FFmpegKit 是**库内调用**，不是子进程；停止用 `FFmpegKit.cancel(sessionId)`，
///   不能发 'q'。
/// - 输出选 mpegts：即使被 cancel 截断也不需要文件尾（trailer），
///   播放器仍可播放部分 `.ts`，适合"随时停"的录像场景。
class FfmpegKitRecorderService implements RecorderService {
  FFmpegSession? _session;
  String? _currentFile;
  String _lastLog = '';
  bool _completed = false;

  @override
  bool get isRecording =>
      _session != null && _currentFile != null && !_completed;

  @override
  String? get currentFile => _currentFile;

  /// 开始录像。
  /// [rtspUrl] RTSP 源；[dir] 输出目录；[ffmpegPath] 桌面端用，此处忽略
  /// （FFmpegKit 自带 ffmpeg，无需外部二进制）。
  @override
  Future<String> start({
    required String rtspUrl,
    required String dir,
    String ffmpegPath = '',
  }) async {
    if (isRecording) return _currentFile!;
    if (rtspUrl.isEmpty) throw Exception('RTSP 地址为空');
    if (dir.isEmpty) throw Exception('录像目录未配置');

    final path = await buildRecordPath(dir);
    if (path == null) throw Exception('录像路径生成失败');

    _currentFile = path;
    _completed = false;
    _lastLog = '';

    // -y 覆盖；-rtsp_transport tcp 用 TCP 拉流（比 UDP 稳，丢包少）；
    // -c copy 不转码，直接把 H.264/AAC 封进 mpegts。
    final cmd = '-y -rtsp_transport tcp -i $rtspUrl -c copy -f mpegts $path';

    try {
      _session = await FFmpegKit.executeAsync(
        cmd,
        // 完成回调：自然结束或被 cancel 都会触发，标记已结束
        (FFmpegSession session) async {
          _completed = true;
        },
        // 日志回调：保留最后一行，便于失败时给出原因
        (Log log) {
          _lastLog = log.getMessage();
        },
        null,
      );
    } catch (e) {
      _currentFile = null;
      _session = null;
      throw Exception('启动 FFmpegKit 失败: $e');
    }

    // 落盘校验：FFmpegKit 异步执行，需等文件真正开始写入才算成功，
    // 否则角标会假亮（连不上 RTSP 时 ffmpeg 立刻退出但 UI 仍显示录制中）。
    final ok = await _verifyRecordingStarted(path);
    if (!ok) {
      await _cancelAndClear();
      // 给出失败原因：优先用 ffmpeg 最后一条日志
      final reason = _lastLog.isNotEmpty ? _lastLog : '未生成录像文件';
      throw Exception('录像未生效：$reason（可能 RTSP 连不上或流不兼容）');
    }
    return path;
  }

  /// 校验录像文件是否真的开始写入：最多等 3s，检查文件存在且 size>0。
  /// 同时检测 session 是否已异常退出（连不上流会立刻 fail）。
  Future<bool> _verifyRecordingStarted(String path) async {
    final f = File(path);
    for (var i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      // session 已结束且非 cancel → 说明 ffmpeg 报错退出，直接判失败
      if (_completed) {
        final rc = await _session?.getReturnCode();
        if (rc != null && !ReturnCode.isSuccess(rc) && !ReturnCode.isCancel(rc)) {
          return false;
        }
      }
      if (await f.exists() && (await f.length()) > 0) {
        return true;
      }
    }
    return false;
  }

  /// 停止录像：cancel 该 session 让 ffmpeg 停止拉流。
  /// mpegts 无需文件尾，cancel 后文件即可直接播放。
  @override
  Future<void> stop() async {
    if (_session == null) {
      _currentFile = null;
      _completed = true;
      return;
    }
    await _cancelAndClear();
  }

  Future<void> _cancelAndClear() async {
    final session = _session;
    final sid = session?.getSessionId();
    if (sid != null) {
      try {
        await FFmpegKit.cancel(sid);
      } catch (e) {
        debugPrint('[ffmpeg_kit] cancel 失败: $e');
      }
    }
    // 给 ffmpeg 一点时间把已缓冲的数据落盘再清理引用
    await Future.delayed(const Duration(milliseconds: 300));
    _session = null;
    _currentFile = null;
    _completed = true;
  }

  @override
  Future<void> dispose() async {
    await stop();
  }
}
