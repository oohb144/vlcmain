import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

/// FFmpeg 子进程录像服务。
///
/// 原理：点开始录像时，后台 spawn 一个 ffmpeg 进程直接连 RTSP 源，
/// `-c copy` 不转码将原始流（H.264+AAC）封装进 `.ts` 文件；
/// 点停止时优雅结束进程以正常写文件尾部。
///
/// 优点：独立于播放器/解码器，比 mpv 运行时 stream-record 属性可靠；
///       断流可由 ffmpeg 自己重连或被检测。
///
/// ffmpeg.exe 路径优先来自配置（[ffmpegPath]），其次尝试系统 PATH。
class FfmpegRecorderService {
  Process? _process;
  String? _currentFile;
  IOSink? _stdin;

  /// 解析录像结果。
  String? get currentFile => _currentFile;
  bool get isRecording => _process != null && _currentFile != null;

  /// 开始录像。
  /// [rtspUrl] RTSP 源；[dir] 输出目录；[ffmpegPath] 可执行文件路径（空则用 PATH）。
  Future<({bool ok, String? file, String? error})> start({
    required String rtspUrl,
    required String dir,
    String ffmpegPath = 'ffmpeg',
  }) async {
    if (isRecording) return (ok: true, file: _currentFile, error: null);
    if (rtspUrl.isEmpty) return (ok: false, file: null, error: 'RTSP 地址为空');
    if (dir.isEmpty) return (ok: false, file: null, error: '录像目录未配置');

    try {
      final d = Directory(dir);
      if (!await d.exists()) await d.create(recursive: true);
    } catch (e) {
      return (ok: false, file: null, error: '创建目录失败: $e');
    }

    final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final out = '$dir${dir.endsWith('/') || dir.endsWith(r'\') ? '' : '/'}rec_$now.ts';

    final args = <String>[
      '-y',
      '-rtsp_transport', 'tcp',
      '-i', rtspUrl,
      '-c', 'copy',
      '-f', 'mpegts',
      out,
    ];

    // 解析可用的 ffmpeg 可执行路径：优先配置值，其次常见安装位置
    final exe = await _resolveFfmpeg(ffmpegPath);
    if (exe == null) {
      return (
        ok: false,
        file: null,
        error: '找不到 ffmpeg。请在设置页填写 ffmpeg.exe 绝对路径，'
            '或安装后重启程序（winget install Gyan.FFmpeg）'
      );
    }

    try {
      _process = await Process.start(
        exe,
        args,
        mode: ProcessStartMode.normal,
      );
    } catch (e) {
      return (ok: false, file: null, error: '启动 ffmpeg 失败: $e');
    }

    _currentFile = out;
    _stdin = _process!.stdin;

    // 吸收 stderr 防止管道缓冲填满导致 ffmpeg 阻塞（只在 debug 打印尾部）
    _process!.stderr.transform(const SystemEncoding().decoder).listen((line) {
      // ffmpeg 日志走 stderr，吞掉即可，必要时可调试查看
    }, onError: (_) {});
    _process!.stdout.listen((_) {}, onError: (_) {});

    // 监听退出，记录错误码便于排查（非阻塞）
    unawaited(_process!.exitCode.then((code) {
      debugPrint('[ffmpeg] exited code=$code, file=$out');
    }));

    return (ok: true, file: out, error: null);
  }

  /// 停止录像：向 ffmpeg stdin 发送 'q' 让其优雅退出以正常写文件尾部。
  Future<void> stop() async {
    final p = _process;
    if (p == null) {
      _currentFile = null;
      return;
    }
    try {
      _stdin?.writeln('q');
      // 给 ffmpeg 最多 3 秒优雅退出
      await p.exitCode.timeout(const Duration(seconds: 3));
    } catch (_) {
      // 超时则强杀
      p.kill(ProcessSignal.sigkill);
    } finally {
      _process = null;
      _stdin = null;
      _currentFile = null;
    }
  }

  /// 释放。
  Future<void> dispose() async {
    await stop();
  }

  /// 解析 ffmpeg 可执行文件路径。
  /// 1) 配置给出的是绝对路径且存在 → 直接用
  /// 2) 配置是裸名 'ffmpeg' → 先试 PATH（直接 spawn 验证），失败再探测常见安装位置
  Future<String?> _resolveFfmpeg(String configured) async {
    // 绝对路径直接校验
    if (configured.isNotEmpty &&
        configured != 'ffmpeg' &&
        await File(configured).exists()) {
      return configured;
    }

    // 试 PATH 中的 ffmpeg
    if (await _canRun(configured.isEmpty ? 'ffmpeg' : configured)) {
      return configured.isEmpty ? 'ffmpeg' : configured;
    }

    // 探测常见安装位置（winget / 手动解压）
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    final candidates = <String>[
      if (home.isNotEmpty)
        '$home\\AppData\\Local\\Microsoft\\WinGet\\Links\\ffmpeg.exe',
      if (home.isNotEmpty)
        '$home\\AppData\\Local\\Microsoft\\WinGet\\Packages\\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\\ffmpeg-8.1.1-full_build\\bin\\ffmpeg.exe',
      r'C:\ffmpeg\bin\ffmpeg.exe',
      r'C:\Program Files\ffmpeg\bin\ffmpeg.exe',
    ];
    for (final c in candidates) {
      if (await File(c).exists()) return c;
    }
    return null;
  }

  /// 试运行 `<exe> -version` 判断可否调用。
  Future<bool> _canRun(String exe) async {
    try {
      final r = await Process.run(exe, ['-version']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}