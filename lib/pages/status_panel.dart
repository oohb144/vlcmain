import 'package:flutter/material.dart';

import '../services/status_poll_service.dart';
import '../services/command_service.dart';
import '../models/device_status.dart';

/// 下发指令的协议常量（与 K230 端 HTTP POST /command 对齐）。
///
/// 每条指令的 JSON 结构与字段名见根目录《K230 下发协议文档》；K230 端按 cmd 字段分发。
class _Cmd {
  static const startRecognize = {'cmd': 'start_recognize'};
  static const stopRecognize = {'cmd': 'stop_recognize'};
  static const startEnroll = {'cmd': 'start_enroll'};
  static const stopEnroll = {'cmd': 'stop_enroll'};
  static const startRecord = {'cmd': 'start_record'};
  static const stopRecord = {'cmd': 'stop_record'};
  static const goHome = {'cmd': 'go_home'};
  static const goSettings = {'cmd': 'go_settings'};
  static const goEnrollPage = {'cmd': 'go_enroll_page'};
  static const enrollFace = {'cmd': 'enroll_face'};
  static const clearFaces = {'cmd': 'clear_faces'};
  static const clearRecordings = {'cmd': 'clear_recordings'};
  static const exitApp = {'cmd': 'exit_app'};
  static const voiceOn = {'cmd': 'voice', 'value': true};
  static const voiceOff = {'cmd': 'voice', 'value': false};
  static const autoRecordOn = {'cmd': 'auto_record', 'value': true};
  static const autoRecordOff = {'cmd': 'auto_record', 'value': false};
  static const streamOn = {'cmd': 'http_stream', 'value': true};
  static const streamOff = {'cmd': 'http_stream', 'value': false};
  static const rtspOn = {'cmd': 'rtsp', 'value': true};
  static const rtspOff = {'cmd': 'rtsp', 'value': false};
  static const audioOn = {'cmd': 'audio', 'value': true};
  static const audioOff = {'cmd': 'audio', 'value': false};
  static const ledOn = {'cmd': 'led', 'value': true};
  static const ledOff = {'cmd': 'led', 'value': false};
  static const fusionPage = {'cmd': 'fusion_page'};
  static const recordingsPage = {'cmd': 'recordings_page'};

  /// 阈值类指令，value 由滑块传入
  static Map<String, dynamic> confThreshold(double v) =>
      {'cmd': 'set_threshold', 'key': 'conf_threshold', 'value': v};
  static Map<String, dynamic> recognizeThreshold(double v) =>
      {'cmd': 'set_threshold', 'key': 'recognize_threshold', 'value': v};
}

/// 状态栏：展示 K230 轮询状态 + 全套下发指令分区。
class StatusPanel extends StatefulWidget {
  final StatusPollService statusPoll;
  final CommandService command;

  const StatusPanel({
    super.key,
    required this.statusPoll,
    required this.command,
  });

  @override
  State<StatusPanel> createState() => _StatusPanelState();
}

class _StatusPanelState extends State<StatusPanel> {
  // 三组主操作的本地视觉态（由 K230 上报的 state 推断并校正）
  bool _recognizing = false;
  bool _enrolling = false;
  bool _recording = false;

  double _confThreshold = 0.25;
  double _recognizeThreshold = 0.72;

  @override
  void initState() {
    super.initState();
    widget.statusPoll.status.addListener(_onChange);
    widget.statusPoll.error.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.statusPoll.status.removeListener(_onChange);
    widget.statusPoll.error.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final s = widget.statusPoll.status.value;
    if (!mounted) return;
    setState(() {
      if (s != null && s.state != null) {
        _recognizing = s.state!.contains('识别');
        _enrolling = s.state!.contains('录入');
        _recording = s.state!.contains('录制') || (s.recording == true);
      }
    });
  }

  Future<void> _send(Map<String, dynamic> payload, String label, {String? toggle}) async {
    final res = await widget.command.send(payload);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label: ${res.message}'),
        backgroundColor: res.ok ? Colors.green.shade700 : Colors.red.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
    // 成功时即时翻转本地视觉态（真值由轮询校正）
    if (res.ok && toggle != null) {
      setState(() {
        if (toggle == 'recognize') {
          _recognizing = !_recognizing;
        } else if (toggle == 'enroll') {
          _enrolling = !_enrolling;
        } else if (toggle == 'record') {
          _recording = !_recording;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.statusPoll.status.value;
    final err = widget.statusPoll.error.value;
    final cs = Theme.of(context).textTheme.titleMedium;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('K230 状态', style: cs),
        const SizedBox(height: 8),
        if (err != null)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.red.shade50,
            child: Text('错误: $err',
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          )
        else if (status == null)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('等待数据…（请先开始播放以启动轮询）'),
          )
        else
          _StatusGrid(status: status),
        const Divider(height: 32),

        Text('主操作', style: cs),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          _toggleChip('识别', _recognizing, _Cmd.startRecognize, _Cmd.stopRecognize, 'recognize'),
          _toggleChip('录入', _enrolling, _Cmd.startEnroll, _Cmd.stopEnroll, 'enroll'),
          _toggleChip('录制', _recording, _Cmd.startRecord, _Cmd.stopRecord, 'record'),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          ActionChip(label: const Text('执行人脸录入'), onPressed: () => _send(_Cmd.enrollFace, '执行人脸录入')),
          ActionChip(label: const Text('回主页'), onPressed: () => _send(_Cmd.goHome, '回主页')),
        ]),
        const Divider(height: 32),

        Text('页面跳转', style: cs),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          ActionChip(label: const Text('设置页'), onPressed: () => _send(_Cmd.goSettings, '去设置页')),
          ActionChip(label: const Text('录入页'), onPressed: () => _send(_Cmd.goEnrollPage, '去录入页')),
          ActionChip(label: const Text('融合播放'), onPressed: () => _send(_Cmd.fusionPage, '融合播放页')),
          ActionChip(label: const Text('录像列表'), onPressed: () => _send(_Cmd.recordingsPage, '录像列表页')),
        ]),
        const Divider(height: 32),

        Text('设备开关', style: cs),
        const SizedBox(height: 8),
        _SwitchRow(label: 'HTTP 推流', onCmd: _Cmd.streamOn, offCmd: _Cmd.streamOff, command: widget.command),
        _SwitchRow(label: 'RTSP 推流', onCmd: _Cmd.rtspOn, offCmd: _Cmd.rtspOff, command: widget.command),
        _SwitchRow(label: '音频提示', onCmd: _Cmd.audioOn, offCmd: _Cmd.audioOff, command: widget.command),
        _SwitchRow(label: 'LED 指示', onCmd: _Cmd.ledOn, offCmd: _Cmd.ledOff, command: widget.command),
        _SwitchRow(label: '语音识别', onCmd: _Cmd.voiceOn, offCmd: _Cmd.voiceOff, command: widget.command),
        _SwitchRow(label: '自动录制', onCmd: _Cmd.autoRecordOn, offCmd: _Cmd.autoRecordOff, command: widget.command),
        const Divider(height: 32),

        Text('阈值调节', style: cs),
        const SizedBox(height: 8),
        Text('检测阈值: ${_confThreshold.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
        Slider(
          min: 0.10, max: 0.90, divisions: 80, value: _confThreshold,
          label: _confThreshold.toStringAsFixed(2),
          onChanged: (v) => setState(() => _confThreshold = v),
          onChangeEnd: (v) => _send(_Cmd.confThreshold(v), '检测阈值=$v'),
        ),
        Text('识别阈值: ${_recognizeThreshold.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
        Slider(
          min: 0.10, max: 0.90, divisions: 80, value: _recognizeThreshold,
          label: _recognizeThreshold.toStringAsFixed(2),
          onChanged: (v) => setState(() => _recognizeThreshold = v),
          onChangeEnd: (v) => _send(_Cmd.recognizeThreshold(v), '识别阈值=$v'),
        ),
        const Divider(height: 32),

        Text('危险操作', style: cs!.copyWith(color: Colors.red)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          ActionChip(
            label: const Text('清空人脸库', style: TextStyle(color: Colors.red)),
            onPressed: () => _confirm('清空人脸库', () => _send(_Cmd.clearFaces, '清空人脸库')),
          ),
          ActionChip(
            label: const Text('清空录像', style: TextStyle(color: Colors.red)),
            onPressed: () => _confirm('清空录像', () => _send(_Cmd.clearRecordings, '清空录像')),
          ),
          ActionChip(
            label: const Text('退出下位程序', style: TextStyle(color: Colors.red)),
            onPressed: () => _confirm('退出下位程序', () => _send(_Cmd.exitApp, '退出下位程序')),
          ),
        ]),
        const SizedBox(height: 12),
        const Text(
          '指令经 HTTP POST 发往 K230 的 /command，协议见根目录《K230下发协议文档.md》。'
          'K230 端需自行实现该 POST 路由。',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _toggleChip(String label, bool on, Map<String, dynamic> onCmd, Map<String, dynamic> offCmd, String toggleKey) {
    return ActionChip(
      label: Text(on ? '停止$label' : '开始$label'),
      avatar: Icon(on ? Icons.pause_circle : Icons.play_circle, size: 18),
      backgroundColor: on ? Colors.indigo.shade50 : null,
      onPressed: () => _send(on ? offCmd : onCmd, on ? '停止$label' : '开始$label', toggle: toggleKey),
    );
  }

  void _confirm(String action, VoidCallback doIt) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('确认$action？'),
        content: Text('该操作不可撤销，确定要$action吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () { Navigator.pop(ctx); doIt(); },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

/// 设备开关行：左侧标签 + 右侧 Switch，切换即下发对应 on/off 指令。
class _SwitchRow extends StatefulWidget {
  final String label;
  final Map<String, dynamic> onCmd;
  final Map<String, dynamic> offCmd;
  final CommandService command;
  const _SwitchRow({
    required this.label,
    required this.onCmd,
    required this.offCmd,
    required this.command,
  });

  @override
  State<_SwitchRow> createState() => _SwitchRowState();
}

class _SwitchRowState extends State<_SwitchRow> {
  bool _on = false;
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    final want = !_on;
    final res = await widget.command.send(want ? widget.onCmd : widget.offCmd);
    if (!mounted) return;
    setState(() {
      if (res.ok) _on = want;
      _busy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.label}: ${res.message}'),
        backgroundColor: res.ok ? Colors.green.shade700 : Colors.red.shade700,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(widget.label)),
          Switch(
            value: _on,
            onChanged: _busy ? null : (_) => _toggle(),
          ),
        ],
      ),
    );
  }
}

/// 把 DeviceStatus 分项渲染成键值列表（对齐 K230 /status 字段）。
class _StatusGrid extends StatelessWidget {
  final DeviceStatus status;
  const _StatusGrid({required this.status});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status.state == null ? Colors.grey : Colors.indigo.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(status.state ?? '未知', style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          if (status.recording == true) ...[
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            const Text('录制中', style: TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ]),
      ),
      _kv('检测到人脸', status.hasFace == null ? null : (status.hasFace! ? '是' : '否')),
      _kv('人数总计', status.faceCount?.toString()),
      _kv('已知人数', status.knownFaceCount?.toString()),
      _kv('未知人数', status.unknownFaceCount?.toString()),
      if (status.faceLabels.isNotEmpty) _kv('人脸标签', status.faceLabels.join(', ')),
      if (status.recordDuration != null && status.recordDuration! > 0)
        _kv('录制时长', '${status.recordDuration}s'),
    ];

    // 兜底：raw 中未展示的字段
    const shown = <String>{
      'state', 'has_face', 'face_count', 'known_face_count', 'unknown_face_count',
      'face_labels', 'recording', 'record_duration',
    };
    status.raw.forEach((k, v) {
      if (shown.contains(k)) return;
      final sv = v?.toString();
      if (sv != null && sv.isNotEmpty) children.add(_kv(k, sv));
    });

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _kv(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}