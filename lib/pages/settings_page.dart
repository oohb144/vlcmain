import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/device_status.dart';
import '../services/command_service.dart';
import '../services/config_service.dart';
import '../services/status_poll_service.dart';
import '../shell/cmd_constants.dart';
import '../theme/app_colors.dart';
import '../models/stream_config.dart';
import '../widgets/switch_row.dart';

/// 输入框文字样式：绿色，浅色背景下可读。
const _inputStyle = TextStyle(color: AppColors.green, fontSize: 14, fontWeight: FontWeight.w600);

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
  CommandService? _cmdService;
  StatusPollService? _statusPoll;
  String? _lastCmdLabel;
  String? _lastCmdMsg;
  bool _lastCmdOk = false;
  bool _saving = false;
  bool _ready = false;
  bool _autoFaceRecord = true;

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
    _autoFaceRecord = c.autoFaceRecord;
    _cmdService = CommandService(c.commandUrl);
    _statusPoll = StatusPollService(statusUrl: c.statusUrl, intervalMs: c.pollIntervalMs);
    _statusPoll!.start();
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
    _statusPoll?.dispose();
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
      autoFaceRecord: _autoFaceRecord,
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
                  _statusSection(),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _rtsp!,
                    style: _inputStyle,
                    decoration: const InputDecoration(
                      labelText: 'RTSP 地址',
                      hintText: 'rtsp://192.168.1.100:8554/stream',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _status!,
                    style: _inputStyle,
                    decoration: const InputDecoration(
                      labelText: '状态接口 URL (GET)',
                      hintText: 'http://192.168.1.100/status',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _command!,
                    style: _inputStyle,
                    decoration: const InputDecoration(
                      labelText: '下发接口 URL (POST)',
                      hintText: 'http://192.168.1.100/command',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _recordDir!,
                    style: _inputStyle,
                    decoration: const InputDecoration(
                      labelText: '录像保存目录',
                      hintText: '本地绝对路径',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ffmpegPath!,
                    style: _inputStyle,
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
                    style: _inputStyle,
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
                  const SizedBox(height: 12),
                  // 本机侧：识别到人脸自动录像开关（依据 /status 的 face_count）
                  SwitchListTile(
                    value: _autoFaceRecord,
                    onChanged: (v) => setState(() => _autoFaceRecord = v),
                    title: const Text('识别到人脸自动录像',
                        style: TextStyle(color: AppColors.green, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('画面出现人脸自动录像，无人脸 3s 后停止；录像写入识别日志'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),
                  // 调试功能：直接下发设备开关指令（无需推流即可调试下位机）
                  _debugSection(),
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

  /// 调试功能卡片：HTTP/RTSP 推流、音频、LED、自动录制开关。
  /// 指令经 [CommandService] 下发到 K230 的 /command。
  Widget _debugSection() {
    final cmd = _cmdService;
    if (cmd == null) return const SizedBox.shrink();
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: '调试功能（设备开关）',
        border: OutlineInputBorder(),
      ),
      child: Column(
        children: [
          SwitchRow(label: 'HTTP 推流', onCmd: Cmd.streamOn, offCmd: Cmd.streamOff, command: cmd),
          SwitchRow(label: 'RTSP 推流', onCmd: Cmd.rtspOn, offCmd: Cmd.rtspOff, command: cmd),
          SwitchRow(label: 'HTTP 推流', onCmd: Cmd.streamOn, offCmd: Cmd.streamOff, command: cmd, onResult: _onCmdResult),
          SwitchRow(label: 'RTSP 推流', onCmd: Cmd.rtspOn, offCmd: Cmd.rtspOff, command: cmd, onResult: _onCmdResult),
          SwitchRow(label: '音频提示', onCmd: Cmd.audioOn, offCmd: Cmd.audioOff, command: cmd, onResult: _onCmdResult),
          SwitchRow(label: 'LED 指示', onCmd: Cmd.ledOn, offCmd: Cmd.ledOff, command: cmd, onResult: _onCmdResult),
          SwitchRow(label: '自动录制', onCmd: Cmd.autoRecordOn, offCmd: Cmd.autoRecordOff, command: cmd, onResult: _onCmdResult),
        ],
      ),
    );
  }

  /// 命令下发回调：记录最近命令响应供状态卡片展示。
  void _onCmdResult(String label, bool ok, String message) {
    if (!mounted) return;
    setState(() {
      _lastCmdLabel = label;
      _lastCmdMsg = message;
      _lastCmdOk = ok;
    });
  }

  /// 下位机状态卡片：轮询 /status 展示当前状态 + 最近命令响应。
  Widget _statusSection() {
    final poll = _statusPoll;
    if (poll == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.graphic_eq, color: AppColors.accent, size: 16),
              const SizedBox(width: 8),
              const Text('下位机状态',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              _pollDot(poll),
            ],
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<DeviceStatus?>(
            valueListenable: poll.status,
            builder: (_, s, _) {
              if (s == null) {
                return ValueListenableBuilder<String?>(
                  valueListenable: poll.error,
                  builder: (_, err, _) => Text(
                    err == null ? '等待数据…' : '错误: $err',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                );
              }
              return Wrap(
                runSpacing: 6,
                spacing: 16,
                children: [
                  _kv('状态', s.state ?? '未知', tone: s.state == null ? null : AppColors.accent),
                  _kv('检测到人脸', (s.hasFace ?? false) ? '是' : '否',
                      tone: (s.hasFace ?? false) ? AppColors.green : AppColors.textMuted),
                  _kv('人数总计', '${s.faceCount ?? 0}'),
                  _kv('已知人数', '${s.knownFaceCount ?? 0}', tone: AppColors.green),
                  _kv('未知人数', '${s.unknownFaceCount ?? 0}', tone: (s.unknownFaceCount ?? 0) > 0 ? AppColors.red : null),
                  if (s.faceLabels.isNotEmpty)
                    _kv('人脸标签', s.faceLabels.join(', ')),
                  if (s.recording == true) _kv('录制', '进行中', tone: AppColors.red),
                  if (s.recordDuration != null && s.recordDuration! > 0)
                    _kv('录制时长', '${s.recordDuration}s'),
                ],
              );
            },
          ),
          const Divider(height: 20, color: AppColors.border),
          // 最近命令响应
          Row(
            children: [
              const Icon(Icons.history, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              const Text('最近命令', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(width: 8),
              if (_lastCmdLabel == null)
                const Text('无', style: TextStyle(color: AppColors.textMuted, fontSize: 12))
              else
                Expanded(
                  child: Text(
                    '$_lastCmdLabel → ${_lastCmdOk ? "成功" : "失败"}: $_lastCmdMsg',
                    style: TextStyle(
                      color: _lastCmdOk ? AppColors.green : AppColors.red,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pollDot(StatusPollService poll) {
    return ValueListenableBuilder<DeviceStatus?>(
      valueListenable: poll.status,
      builder: (_, s, _) => ValueListenableBuilder<String?>(
        valueListenable: poll.error,
        builder: (_, err, _) {
          final online = err == null && s != null;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: online ? AppColors.green : AppColors.textMuted,
                  shape: BoxShape.circle,
                  boxShadow: online
                      ? [BoxShadow(color: AppColors.green.withValues(alpha: 0.5), blurRadius: 4)]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(online ? '在线' : '离线',
                  style: TextStyle(color: online ? AppColors.green : AppColors.textMuted, fontSize: 12)),
            ],
          );
        },
      ),
    );
  }

  Widget _kv(String label, String value, {Color? tone}) {
    final c = tone ?? AppColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label  ', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        Text(value, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}