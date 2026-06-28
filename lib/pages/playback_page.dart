import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../services/config_service.dart';
import '../services/playback_service.dart';

/// 录像回放页：列出录像目录下的 .ts 文件，点选即在本页内嵌播放器播放。
class PlaybackPage extends StatefulWidget {
  const PlaybackPage({super.key});

  @override
  State<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends State<PlaybackPage> {
  final PlaybackService _service = PlaybackService();
  late final Player _player;
  late final VideoController _controller;

  List<Recording> _recordings = [];
  bool _loading = true;
  String? _error;
  String _dir = '';
  String? _currentPlaying;
  String? _playError; // 播放本地文件失败时的 mpv 错误，显示在播放器下方
  String? _initialPath; // 从路由 arguments 带入的「自动播放此录像」路径
  bool _didInit = false;
  final ScrollController _listController = ScrollController();
  // ListTile（含 leading/title/subtitle/trailing）估算行高，用于滚动定位
  static const double _estItemHeight = 72.0;
  StreamSubscription<String>? _errSub;
  StreamSubscription<PlayerLog>? _logSub;

  @override
  void initState() {
    super.initState();
    // 关键：VideoController 必须绑定到实际播放用的 _player，否则 Video 显示
    // 的是另一个空 Player，画面永远黑屏。
    _player = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.info),
    );
    _controller = VideoController(_player);
    // 监听播放错误，显示到界面便于排查黑屏原因
    _errSub = _player.stream.error.listen((e) {
      debugPrint('[playback] player error: $e');
      if (mounted) setState(() => _playError = e);
    });
    _logSub = _player.stream.log.listen((log) {
      final t = log.text.toLowerCase();
      if (t.contains('error') ||
          t.contains('fail') ||
          t.contains('cannot') ||
          t.contains('no such')) {
        debugPrint('[playback][mpv] ${log.prefix}/${log.level}: ${log.text}');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    // 监控页「识别录像日志」点条目跳转时会带 videoPath 作为 arguments
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String && arg.isNotEmpty) _initialPath = arg;
    _load();
  }

  @override
  void dispose() {
    _errSub?.cancel();
    _logSub?.cancel();
    _listController.dispose();
    _player.dispose();
    super.dispose();
  }

  /// 取路径 basename，兼容正反斜杠。
  String _basename(String path) {
    final i = path.lastIndexOf(RegExp(r'[/\\]'));
    return i >= 0 ? path.substring(i + 1) : path;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await ConfigService.load();
      _dir = c.recordDir;
      final list = await _service.listRecordings(c.recordDir);
      if (mounted) setState(() => _recordings = list);
      // 若带入了初始路径（从日志跳来），自动选中并播放对应录像
      final init = _initialPath;
      if (init != null && init.isNotEmpty) {
        _initialPath = null;
        // 录像路径正反斜杠不一致（recorder 归一化为 /，Windows 目录枚举为 \），
        // 统一比较 basename 避免匹配失败。
        final wantBasename = _basename(init);
        int matchIndex = -1;
        for (var i = 0; i < list.length; i++) {
          if (_basename(list[i].path) == wantBasename) {
            matchIndex = i;
            break;
          }
        }
        if (matchIndex >= 0 && mounted) {
          await _play(list[matchIndex]);
          // 滚动让选中项可见
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_listController.hasClients) {
              final target = (matchIndex * _estItemHeight)
                  .clamp(0.0, _listController.position.maxScrollExtent);
              _listController.animateTo(target,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 把本地路径转成 media_kit/mpv 能稳定识别的 file:// URI。
  /// Windows 下 Directory.list 返回的是反斜杠路径（C:\...\x.ts），
  /// 直接传给 Media() 会被当成普通字符串 URI 导致打不开 → 黑屏。
  String _toFileUri(String path) {
    var p = path.replaceAll('\\', '/');
    if (p.startsWith('/')) return 'file://$p'; // 已是绝对 unix 路径
    return 'file:///$p'; // Windows 盘符：C:/... → file:///C:/...
  }

  Future<void> _play(Recording r) async {
    setState(() {
      _currentPlaying = r.path;
      _playError = null;
    });
    try {
      await _player.open(Media(_toFileUri(r.path)));
    } catch (e) {
      if (mounted) setState(() => _playError = '打开失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('录像回放'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          // 16:9 播放器高度按宽度计算，但不超过总高度的一半，
          // 避免窗口扁平时播放器撑满导致下方列表 BOTTOM OVERFLOWED。
          final playerH = (c.maxWidth * 9 / 16).clamp(120.0, c.maxHeight * 0.5);
          return Column(
            children: [
              // 内嵌播放器（点列表项后显示视频）
              SizedBox(
                height: playerH,
                child: Container(
                  color: Colors.black,
                  child: Video(controller: _controller, fill: Colors.black),
                ),
              ),
              // 播放错误提示（黑屏时显示 mpv 报错，便于定位）
              if (_playError != null)
                Container(
                  width: double.infinity,
                  color: Colors.red.shade50,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    '播放错误: $_playError',
                    style: TextStyle(fontSize: 11, color: Colors.red.shade900),
                  ),
                ),
              // 播放控制条
              Material(
                color: Colors.black12,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () => _player.play(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.pause),
                      onPressed: () => _player.pause(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop),
                      onPressed: () => _player.stop(),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          _currentPlaying == null
                              ? '请从下方列表选择录像'
                              : '播放中: ${_currentPlaying!.split('/').last}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 录像列表
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('错误: $_error'),
                        ),
                      )
                    : _recordings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.video_library_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _dir.isEmpty ? '未配置录像目录' : '“$_dir” 下暂无 .ts 录像',
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: _load,
                              child: const Text('刷新'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: _listController,
                        itemCount: _recordings.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = _recordings[i];
                          final isCurrent = _currentPlaying == r.path;
                          return ListTile(
                            tileColor: isCurrent
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.12)
                                : null,
                            leading: Icon(
                              Icons.movie,
                              color: isCurrent
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            title: Text(r.name),
                            subtitle: Text(
                              '${r.sizeStr}  ·  ${r.modified.toLocal()}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: isCurrent
                                ? const Icon(
                                    Icons.equalizer,
                                    color: Colors.green,
                                  )
                                : const Icon(Icons.play_circle_outline),
                            onTap: () => _play(r),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
