import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';

import '../models/device_status.dart';
import '../shell/app_services.dart';
import '../shell/cmd_constants.dart';
import '../services/recorder_service.dart';
import '../theme/app_colors.dart';
import 'status_dot.dart';

/// 视频区组件：RTSP 视频 + OSD 叠加 + 工具条。
///
/// 从原 [PlayerPage] 抽出，承载全部视频相关功能（接收推流 / 控制通道 /
/// 录像 / 暂停 / 音量 / 截图 / 全屏 / 语音对讲 / 手动报警 / 回放入口），
/// 服务经 [AppServices.of] 取，切页不重建播放器。
class VideoStage extends StatefulWidget {
  const VideoStage({super.key});

  @override
  State<VideoStage> createState() => _VideoStageState();
}

class _VideoStageState extends State<VideoStage> {
  AppServices? _svc;
  StreamSubscription<dynamic>? _mpvLogSub;

  bool _isPlaying = false;
  bool _isControlOn = false;
  bool _isRecording = false;
  bool _voiceOn = false;
  String _statusText = '未连接';
  String? _mpvLogHint;
  double _volume = 100;

  // OSD 叠加：本机时间戳
  late final ValueNotifier<String> _clock;

  @override
  void initState() {
    super.initState();
    _clock = ValueNotifier(_now());
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      _clock.value = _now();
      return true;
    });
  }

  String _now() {
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final svc = AppServices.of(context);
    if (!identical(svc, _svc)) {
      _svc = svc;
      // 配置刷新后 statusPoll 实例可能更换，重新按当前控制态恢复轮询
      if (_isControlOn && !svc.statusPoll.isRunning) {
        svc.statusPoll.start();
      }
    }
  }

  @override
  void dispose() {
    _mpvLogSub?.cancel();
    _clock.dispose();
    super.dispose();
  }

  AppServices get _s => _svc!;

  Future<void> _startStream() async {
    final url = _s.config.rtspUrl;
    if (url.isEmpty) {
      _toast('RTSP 地址未配置');
      return;
    }
    setState(() => _statusText = '推流连接中…');
    try {
      _s.rtsp.ensurePlayer();
      _subscribeMpvLog();
      if (_isRecording) {
        await _s.rtsp.applyRecordablePrefs();
      } else {
        await _s.rtsp.applyRtspPrefs();
      }
      final recordPath = (_isRecording && _s.recorder is MpvRecorderService)
          ? _s.recorder.currentFile
          : null;
      await _s.rtsp.open(url, recordPath: recordPath);
      setState(() {
        _isPlaying = true;
        _statusText = '已接收推流: $url';
      });
    } catch (e) {
      setState(() => _statusText = '接收失败: $e');
    }
  }

  Future<void> _stopStream() async {
    if (_isRecording) {
      try {
        await _s.recorder.stop();
      } catch (_) {}
      setState(() => _isRecording = false);
    }
    await _s.rtsp.stop();
    setState(() {
      _isPlaying = false;
      _statusText = _isControlOn ? '推流已停止，控制通道在线' : '已停止';
    });
  }

  Future<void> _toggleControl() async {
    if (_s.config.statusUrl.isEmpty) {
      _toast('状态接口 URL 未配置');
      return;
    }
    if (_isControlOn) {
      _s.statusPoll.stop();
      setState(() {
        _isControlOn = false;
        if (!_isPlaying) _statusText = '控制通道已关闭';
      });
    } else {
      _s.statusPoll.start();
      setState(() {
        _isControlOn = true;
        if (!_isPlaying) _statusText = '控制通道在线（未接收推流）';
      });
    }
  }

  Future<void> _toggleRecording() async {
    final c = _s.config;
    if (c.rtspUrl.isEmpty) {
      _toast('RTSP 地址未配置，无法录像');
      return;
    }
    if (c.recordDir.isEmpty) {
      _toast('录像目录未配置，请到设置中指定');
      return;
    }
    if (_isRecording) {
      try {
        await _s.recorder.stop();
      } catch (e) {
        if (mounted) _toast('停止录像异常: $e');
      }
      setState(() => _isRecording = false);
      if (mounted) _toast('已停止录像');
    } else {
      try {
        final path = await _s.recorder.start(
          rtspUrl: c.rtspUrl,
          dir: c.recordDir,
          ffmpegPath: c.ffmpegPath,
        );
        setState(() => _isRecording = true);
        if (mounted) _toast('开始录像: ${path.split('/').last}');
      } catch (e) {
        if (mounted) _toast('开始录像失败: $e');
      }
    }
  }

  Future<void> _snapshot() async {
    final dir = _s.config.recordDir;
    try {
      // media_kit 的 screenshot() 返回已编码的图片字节（Uint8List），直接落盘。
      final bytes = await _s.rtsp.player.screenshot();
      if (bytes == null || bytes.isEmpty) {
        _toast('截图失败：无画面（请先接收推流）');
        return;
      }
      final shotDir = dir.isEmpty
          ? (await getApplicationDocumentsDirectory()).path
          : dir;
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '$shotDir/shot_$now.png';
      final file = File(path);
      try {
        await file.parent.create(recursive: true);
      } catch (_) {}
      await file.writeAsBytes(bytes);
      _toast('已截图: ${path.split('/').last}');
    } catch (e) {
      _toast('截图失败: $e');
    }
  }

  void _fullscreen() {
    // media_kit 在该机器上纹理重建易崩（EGL surface 失败），全屏页改用
    // Texture 共享 textureId 仍有冲突风险，暂以提示代替，避免崩溃。
    _toast('全屏请使用窗口标题栏的最大化按钮');
  }

  void _voiceTalk() {
    // 语音识别与推流共用 K230 麦克风资源，推流中不可开启。
    if (_isPlaying) {
      _toast('麦克风口占用，请关闭推流');
      return;
    }
    _toggleVoice();
  }

  Future<void> _toggleVoice() async {
    final want = !_voiceOn;
    final res = await _s.command.send(want ? Cmd.voiceOn : Cmd.voiceOff);
    if (!mounted) return;
    if (res.ok) {
      setState(() => _voiceOn = want);
    }
    _toast('语音识别: ${res.message}');
  }

  void _manualAlarm() {
    // 当前协议无手动报警 cmd。
    _toast('手动报警需下位机扩展协议，暂未接入');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _subscribeMpvLog() {
    _mpvLogSub?.cancel();
    _mpvLogSub = _s.rtsp.logStream.listen((log) {
      final t = log.text.toLowerCase();
      if (t.contains('record') ||
          t.contains('stream') ||
          t.contains('error') ||
          t.contains('fail') ||
          t.contains('denied') ||
          t.contains('cannot')) {
        debugPrint('[mpv] ${log.prefix}/${log.level}: ${log.text}');
        if (mounted) {
          setState(() => _mpvLogHint = '${log.level}: ${log.text}');
        }
      }
    });
  }

  /// 录制角标：手动录制 [isRecording] 或自动录像（监听 faceRecord.recording）。
  Widget _maybeRecBadge() {
    final svc = _svc;
    if (svc == null) {
      return _isRecording ? _recBadge(false) : const SizedBox.shrink();
    }
    return ValueListenableBuilder<bool>(
      valueListenable: svc.faceRecord.recording,
      builder: (_, autoRec, _) {
        final show = _isRecording || autoRec;
        if (!show) return const SizedBox.shrink();
        return _recBadge(autoRec);
      },
    );
  }

  Widget _recBadge(bool auto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const StatusDot(state: StatusDotState.alarm, size: 8),
        const SizedBox(width: 4),
        Text(
          auto ? 'AUTO REC' : 'REC',
          style: const TextStyle(
              color: AppColors.red, fontSize: 11, fontFamily: 'Consolas'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _svc?.rtsp.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 视频区
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: const BoxDecoration(color: Colors.black),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (controller == null)
                  const _VideoPlaceholder()
                else
                  Positioned.fill(
                    // RepaintBoundary 隔离 Video，避免外部布局抖动触发纹理重建。
                    child: RepaintBoundary(
                      child: Video(controller: controller, fill: Colors.black),
                    ),
                  ),
                // OSD 左上：时间
                Positioned(
                  top: 10,
                  left: 12,
                  child: ValueListenableBuilder<String>(
                    valueListenable: _clock,
                    builder: (_, v, _) => _OsdText(v),
                  ),
                ),
                // OSD 右下：设备/分辨率
                const Positioned(
                  bottom: 10,
                  right: 12,
                  child: _OsdText('K230-CAM01', dim: true),
                ),
                // OSD 左下：识别情况 / 陌生人 / 自动录像（监听状态与自动录像服务）
                if (_svc != null)
                  Positioned(
                    bottom: 10,
                    left: 12,
                    child: _FaceOsd(svc: _svc!),
                  ),
                // 录制角标（手动 _isRecording 或 自动 faceRecord.recording）
                Positioned(
                  top: 10,
                  right: 12,
                  child: _maybeRecBadge(),
                ),
              ],
            ),
          ),
        ),
        // 工具条
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _ToolBtn(
                icon: Icons.photo_camera,
                label: '截图',
                onTap: _snapshot,
              ),
              _ToolBtn(
                icon: _isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
                label: _isRecording ? '停止录像' : '录制',
                tone: _isRecording ? _ToolTone.danger : _ToolTone.neutral,
                onTap: _toggleRecording,
              ),
              _ToolBtn(icon: Icons.fullscreen, label: '全屏', onTap: _fullscreen),
              _ToolBtn(
                icon: _voiceOn ? Icons.mic : Icons.mic_none,
                label: _voiceOn ? '关闭语音' : '语音识别',
                tone: _voiceOn ? _ToolTone.primary : _ToolTone.neutral,
                onTap: _voiceTalk,
              ),
              _ToolBtn(
                icon: Icons.warning,
                label: '手动报警',
                tone: _ToolTone.danger,
                onTap: _manualAlarm,
              ),
              _ToolBtn(
                icon: Icons.video_library,
                label: '回放',
                onTap: () => Navigator.pushNamed(context, '/playback'),
              ),
              _ToolBtn(
                icon: _isControlOn ? Icons.link_off : Icons.link,
                label: _isControlOn ? '断开控制' : '连接控制',
                tone: _isControlOn ? _ToolTone.primary : _ToolTone.neutral,
                onTap: _toggleControl,
              ),
              _isPlaying
                  ? _ToolBtn(
                      icon: Icons.stop,
                      label: '停止接收',
                      tone: _ToolTone.danger,
                      onTap: _stopStream,
                    )
                  : _ToolBtn(
                      icon: Icons.play_arrow,
                      label: '接收推流',
                      tone: _ToolTone.primary,
                      onTap: _startStream,
                    ),
            ],
          ),
        ),
        // 状态行
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              StatusDot(state: _isControlOn ? StatusDotState.online : StatusDotState.offline, size: 8),
              const SizedBox(width: 4),
              StatusDot(state: _isPlaying ? StatusDotState.online : StatusDotState.offline, size: 8),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_statusText,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ),
            ],
          ),
        ),
        if (_mpvLogHint != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('mpv: $_mpvLogHint',
              style: const TextStyle(fontSize: 10, color: AppColors.yellow),
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
          ),
        // 音量
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              const Icon(Icons.volume_down, size: 16, color: AppColors.textMuted),
              Expanded(
                child: Slider(
                  min: 0,
                  max: 100,
                  value: _volume,
                  onChanged: (v) => setState(() => _volume = v),
                  onChangeEnd: (v) {
                    if (_isPlaying) _s.rtsp.setVolume(v);
                  },
                ),
              ),
              const Icon(Icons.volume_up, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text('${_volume.toInt()}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                icon: const Icon(Icons.pause),
                tooltip: '暂停',
                onPressed: _isPlaying ? () => _s.rtsp.pause() : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.videocam, size: 48, color: AppColors.textMuted),
        const SizedBox(height: 8),
        Text(
          '点击「连接控制」打开状态/下发通道；「接收推流」开始播放 RTSP 视频',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }
}

class _OsdText extends StatelessWidget {
  final String text;
  final bool dim;
  const _OsdText(this.text, {this.dim = false});
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: dim ? const Color(0x88FFFFFF) : const Color(0xB3FFFFFF),
        fontSize: 11,
        fontFamily: 'Consolas',
        shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
      ),
    );
  }
}

/// 左下角 OSD：识别情况 / 人数 / 陌生人 / 自动录像时长。
///
/// 监听 [AppServices.statusPoll] 的状态与 [AppServices.faceRecord] 的自动录像
/// 事件；自带 1s 心跳刷新「自动录像中 Xs」时长。
class _FaceOsd extends StatefulWidget {
  final AppServices svc;
  const _FaceOsd({required this.svc});

  @override
  State<_FaceOsd> createState() => _FaceOsdState();
}

class _FaceOsdState extends State<_FaceOsd> {
  Timer? _t;
  DeviceStatus? _status;
  bool _autoRec = false;

  @override
  void initState() {
    super.initState();
    _status = widget.svc.statusPoll.status.value;
    _autoRec = widget.svc.faceRecord.recording.value;
    widget.svc.statusPoll.status.addListener(_onStatus);
    widget.svc.faceRecord.recording.addListener(_onRec);
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    widget.svc.statusPoll.status.removeListener(_onStatus);
    widget.svc.faceRecord.recording.removeListener(_onRec);
    super.dispose();
  }

  void _onStatus() {
    if (!mounted) return;
    setState(() => _status = widget.svc.statusPoll.status.value);
  }

  void _onRec() {
    if (!mounted) return;
    setState(() => _autoRec = widget.svc.faceRecord.recording.value);
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final cur = widget.svc.faceRecord.current.value;
    final known = s?.knownFaceCount ?? 0;
    final unknown = s?.unknownFaceCount ?? 0;
    final hasStranger = unknown > 0;
    final rows = <Widget>[
      _row('识别', s?.state ?? '等待状态…'),
      _row('人数', '已知 $known / 未知 $unknown'),
      _row(
        '陌生人',
        hasStranger ? '⚠ 有陌生人' : '无陌生人',
        color: hasStranger ? const Color(0xFFE8727A) : const Color(0xFF4EC07A),
      ),
    ];
    if (_autoRec && cur != null) {
      rows.add(_row('自动录像', '● 录制中 ${cur.durationSec}s',
          color: const Color(0xFFE8727A)));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        '$label  $value',
        style: TextStyle(
          color: color ?? const Color(0xB3FFFFFF),
          fontSize: 11,
          fontFamily: 'Consolas',
          shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
        ),
      ),
    );
  }
}


enum _ToolTone { neutral, primary, danger }

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final _ToolTone tone;
  final VoidCallback onTap;
  const _ToolBtn({
    required this.icon,
    required this.label,
    this.tone = _ToolTone.neutral,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (fg, bg, border) = switch (tone) {
      _ToolTone.primary => (AppColors.accent, AppColors.accentDim, AppColors.accent),
      _ToolTone.danger => (AppColors.red, AppColors.redDim, AppColors.red),
      _ToolTone.neutral => (AppColors.textPrimary, AppColors.bgHover, AppColors.border),
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(color: fg, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
