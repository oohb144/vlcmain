import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../services/config_service.dart';
import '../services/rtsp_service.dart';
import '../services/ffmpeg_recorder_service.dart';
import '../services/status_poll_service.dart';
import '../services/command_service.dart';
import '../models/stream_config.dart';
import 'status_panel.dart';

/// 主页：RTSP 视频播放 + 控制条 + 状态栏（侧边抽屉）。
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final RtspService _rtsp = RtspService();
  final FfmpegRecorderService _recorder = FfmpegRecorderService();

  StreamConfig? _config;
  late StatusPollService _statusPoll;
  late CommandService _command;
  bool _servicesReady = false;

  bool _isPlaying = false;       // RTSP 推流接收状态
  bool _isControlOn = false;     // 控制通道（状态轮询 + 下发）是否开启，独立于推流
  bool _isRecording = false;
  String _statusText = '未连接';

  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  Future<void> _initAsync() async {
    final c = await ConfigService.load();
    _statusPoll = StatusPollService(
      statusUrl: c.statusUrl,
      intervalMs: c.pollIntervalMs,
    );
    _command = CommandService(c.commandUrl);
    if (mounted) {
      setState(() {
        _config = c;
        _servicesReady = true;
      });
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    if (_servicesReady) _statusPoll.dispose();
    _rtsp.dispose();
    super.dispose();
  }

  Future<void> _startStream() async {
    // 仅启停 RTSP 视频接收，不再绑定状态轮询/下发
    final url = _config?.rtspUrl ?? '';
    if (url.isEmpty) {
      _toast('RTSP 地址未配置');
      return;
    }
    setState(() => _statusText = '推流连接中…');
    try {
      _rtsp.ensurePlayer();
      await _rtsp.applyRtspPrefs();
      await _rtsp.open(url);
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
      await _recorder.stop();
      setState(() => _isRecording = false);
    }
    await _rtsp.stop();
    setState(() {
      _isPlaying = false;
      _statusText = _isControlOn ? '推流已停止，控制通道在线' : '已停止';
    });
  }

  /// 切换"控制通道"：开启/关闭 状态轮询 + 下发。独立于 RTSP 推流。
  Future<void> _toggleControl() async {
    final c = _config;
    if (c == null) return;
    if (c.statusUrl.isEmpty) {
      _toast('状态接口 URL 未配置');
      return;
    }
    if (_isControlOn) {
      _statusPoll.stop();
      setState(() {
        _isControlOn = false;
        if (!_isPlaying) _statusText = '控制通道已关闭';
      });
    } else {
      _refreshServices(); // 用最新配置重建轮询/下发服务
      _statusPoll.start();
      setState(() {
        _isControlOn = true;
        if (!_isPlaying) _statusText = '控制通道在线（未接收推流）';
      });
    }
  }

  /// 用当前配置重建状态/下发服务（设置返回或首次加载后调用）。
  void _refreshServices() {
    final c = _config;
    if (c == null) return;
    final wasRunning = _statusPoll.isRunning;
    _statusPoll.dispose();
    _statusPoll = StatusPollService(
      statusUrl: c.statusUrl,
      intervalMs: c.pollIntervalMs,
    );
    _command = CommandService(c.commandUrl);
    if (wasRunning) _statusPoll.start();
  }

  Future<void> _toggleRecording() async {
    final c = _config;
    if (c == null) return;
    if (c.rtspUrl.isEmpty) {
      _toast('RTSP 地址未配置，无法录像');
      return;
    }
    if (c.recordDir.isEmpty) {
      _toast('录像目录未配置，请到设置中指定');
      return;
    }
    if (_isRecording) {
      await _recorder.stop();
      setState(() => _isRecording = false);
      if (mounted) _toast('已停止录像');
    } else {
      final res = await _recorder.start(
        rtspUrl: c.rtspUrl,
        dir: c.recordDir,
        ffmpegPath: c.ffmpegPath.isEmpty ? 'ffmpeg' : c.ffmpegPath,
      );
      if (res.ok && res.file != null) {
        setState(() => _isRecording = true);
        if (mounted) _toast('开始录像: ${res.file!.split('/').last.split(r'\').last}');
      } else {
        if (mounted) _toast('录像失败: ${res.error ?? "未知错误"}');
      }
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _rtsp.controller;
    final c = _config;
    final configLoaded = c != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('K230 RTSP 播放器'),
        actions: [
          IconButton(
            tooltip: _isRecording ? '停止录像' : '开始录像',
            icon: Icon(
              _isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
              color: _isRecording ? Colors.red : null,
            ),
            onPressed: _toggleRecording,
          ),
          IconButton(
            tooltip: '录像回放',
            icon: const Icon(Icons.video_library),
            onPressed: () => Navigator.pushNamed(context, '/playback'),
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.pushNamed(context, '/settings');
              if (!mounted) return;
              final newConfig = await ConfigService.load();
              setState(() => _config = newConfig);
              _refreshServices();
            },
          ),
          Builder(
            builder: (ctx) => IconButton(
              tooltip: 'K230 状态',
              icon: const Icon(Icons.dvr),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        width: 340,
        child: SafeArea(
          child: configLoaded
              ? StatusPanel(statusPoll: _statusPoll, command: _command)
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: controller == null
                ? Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: const Text(
                      '可先点下方「连接控制」打开状态/下发通道；'
                      '点「接收推流」开始播放 RTSP 视频',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : Video(controller: controller, fill: Colors.black),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Tooltip(
                  message: '控制通道',
                  child: Icon(
                    _isControlOn ? Icons.circle : Icons.circle_outlined,
                    size: 10,
                    color: _isControlOn ? Colors.blue : Colors.grey,
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: '推流接收',
                  child: Icon(
                    _isPlaying ? Icons.circle : Icons.circle_outlined,
                    size: 10,
                    color: _isPlaying ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_statusText, overflow: TextOverflow.ellipsis),
                ),
                if (_isRecording)
                  const Text('●REC', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
          ControlBar(
            rtsp: _rtsp,
            isPlaying: _isPlaying,
            isControlOn: _isControlOn,
            onPlay: _startStream,
            onStop: _stopStream,
            onToggleControl: _toggleControl,
          ),
        ],
      ),
    );
  }
}

/// 底部控制条：两个独立操作区——控制通道开关、推流接收开始/停止；加暂停与音量。
class ControlBar extends StatefulWidget {
  final RtspService rtsp;
  final bool isPlaying;
  final bool isControlOn;
  final VoidCallback onPlay;
  final VoidCallback onStop;
  final VoidCallback onToggleControl;

  const ControlBar({
    super.key,
    required this.rtsp,
    required this.isPlaying,
    required this.isControlOn,
    required this.onPlay,
    required this.onStop,
    required this.onToggleControl,
  });

  @override
  State<ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends State<ControlBar> {
  double _volume = 100;

  @override
  Widget build(BuildContext context) {
    final controlColor =
        widget.isControlOn ? Colors.blue.shade700 : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black12,
      child: Column(
        children: [
          // 第一行：两个独立主操作按钮
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: controlColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: widget.onToggleControl,
                  icon: Icon(widget.isControlOn
                      ? Icons.link_off
                      : Icons.link),
                  label: Text(widget.isControlOn ? '断开控制' : '连接控制'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: widget.isPlaying
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade300),
                        ),
                        onPressed: widget.onStop,
                        icon: const Icon(Icons.stop),
                        label: const Text('停止接收'),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: widget.onPlay,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('接收推流'),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 第二行：暂停 + 音量
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.pause),
                tooltip: '暂停',
                onPressed: widget.isPlaying ? widget.rtsp.pause : null,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.volume_down, size: 18),
              Expanded(
                child: Slider(
                  min: 0,
                  max: 100,
                  value: _volume,
                  onChanged: (v) {
                    setState(() => _volume = v);
                    if (widget.isPlaying) widget.rtsp.setVolume(v);
                  },
                ),
              ),
              const Icon(Icons.volume_up, size: 18),
              const SizedBox(width: 8),
              Text('${_volume.toInt()}'),
            ],
          ),
        ],
      ),
    );
  }
}