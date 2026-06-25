import 'package:flutter/material.dart';

import '../services/config_service.dart';
import '../services/playback_service.dart';

class PlaybackPage extends StatefulWidget {
  const PlaybackPage({super.key});

  @override
  State<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends State<PlaybackPage> {
  final PlaybackService _service = PlaybackService();
  List<Recording> _recordings = [];
  bool _loading = true;
  String? _error;
  String _dir = '';

  @override
  void initState() {
    super.initState();
    _load();
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
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('错误: $_error')))
              : _recordings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.video_library_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(_dir.isEmpty ? '未配置录像目录' : '“$_dir” 下暂无 .ts 录像'),
                          const SizedBox(height: 16),
                          OutlinedButton(onPressed: _load, child: const Text('刷新')),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _recordings.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = _recordings[i];
                        return ListTile(
                          leading: const Icon(Icons.movie),
                          title: Text(r.name),
                          subtitle: Text(
                            '${r.sizeStr}  ·  ${r.modified.toLocal()}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.play_circle_outline),
                          onTap: () {
                            // 把录像路径作为结果回传，由主页/单独播放器播放。
                            // 这里简化：通过 SnackBar 提示，并在控制台可用 player.open(Media(path))。
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('已选择 ${r.name}（路径: ${r.path}）'),
                                action: SnackBarAction(
                                  label: '播放',
                                  onPressed: () => Navigator.pop(context, r.path),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
    );
  }
}