import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../services/config_service.dart';
import '../models/stream_config.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController? _rtsp;
  TextEditingController? _status;
  TextEditingController? _command;
  TextEditingController? _recordDir;
  TextEditingController? _ffmpegPath;
  TextEditingController? _pollMs;
  bool _saving = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initFields();
  }

  Future<void> _initFields() async {
    final c = await ConfigService.load();
    _rtsp = TextEditingController(text: c.rtspUrl);
    _status = TextEditingController(text: c.statusUrl);
    _command = TextEditingController(text: c.commandUrl);
    // 录像目录默认设为应用文档目录下的 records/
    final defaultDir = c.recordDir.isNotEmpty ? c.recordDir : null;
    _recordDir = TextEditingController(
      text: defaultDir ?? await _defaultRecordDir(),
    );
    _ffmpegPath =
        TextEditingController(text: c.ffmpegPath.isEmpty ? 'ffmpeg' : c.ffmpegPath);
    _pollMs = TextEditingController(text: c.pollIntervalMs.toString());
    if (mounted) setState(() => _ready = true);
  }

  Future<String> _defaultRecordDir() async {
    // Android：App 专属外部目录（无需权限，保证可写；文件管理器在
    // Android/data/<包名>/files/ 下可见）。DCIM 等共享目录需额外"所有文件访问"权限。
    if (Platform.isAndroid) {
      try {
        final dir = await getExternalStorageDirectory();
        if (dir != null) {
          return '${dir.path}${dir.path.endsWith('/') ? '' : '/'}records';
        }
      } catch (_) {}
      return '/storage/emulated/0/Android/data/com.example.vlc/files/records';
    }
    // 桌面端：用应用文档目录下的 records/
    try {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}${dir.path.endsWith('/') ? '' : '/'}records';
    } catch (_) {
      return 'records';
    }
  }

  @override
  void dispose() {
    _rtsp?.dispose();
    _status?.dispose();
    _command?.dispose();
    _recordDir?.dispose();
    _ffmpegPath?.dispose();
    _pollMs?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final poll = int.tryParse(_pollMs!.text) ?? 1000;
    final config = StreamConfig(
      rtspUrl: _rtsp!.text.trim(),
      statusUrl: _status!.text.trim(),
      commandUrl: _command!.text.trim(),
      recordDir: _recordDir!.text.trim(),
      ffmpegPath: _ffmpegPath!.text.trim().isEmpty
          ? 'ffmpeg'
          : _ffmpegPath!.text.trim(),
      pollIntervalMs: poll < 200 ? 200 : poll,
    );
    await ConfigService.save(config);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已保存')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ready;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ready
          ? Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _rtsp!,
                    decoration: const InputDecoration(
                      labelText: 'RTSP 地址',
                      hintText: 'rtsp://192.168.1.100:8554/stream',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _status!,
                    decoration: const InputDecoration(
                      labelText: '状态接口 URL (GET)',
                      hintText: 'http://192.168.1.100/status',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _command!,
                    decoration: const InputDecoration(
                      labelText: '下发接口 URL (POST)',
                      hintText: 'http://192.168.1.100/command',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _recordDir!,
                    decoration: const InputDecoration(
                      labelText: '录像保存目录',
                      hintText: '本地绝对路径',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ffmpegPath!,
                    decoration: const InputDecoration(
                      labelText: 'FFmpeg 路径',
                      hintText: 'ffmpeg  （填写绝对路径或留空用系统 ffmpeg）',
                      border: OutlineInputBorder(),
                      helperText: '录像用；下载 gyan.dev 的 release 解压后填 ffmpeg.exe 绝对路径',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pollMs!,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '状态轮询间隔 (ms)',
                      hintText: '1000',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 200) return '最小 200ms';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: const Text('保存'),
                  ),
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}