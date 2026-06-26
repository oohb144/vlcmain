import 'package:flutter/material.dart';

import '../services/command_service.dart';
import '../services/status_poll_service.dart';
import '../shell/cmd_constants.dart';
import '../theme/app_colors.dart';
import 'switch_row.dart';

/// 人脸识别控制仪表盘：悬浮按钮点开后弹出的操控面板。
///
/// 分组对应下位机 dostudy 工程的实际操作（见状态机/指令映射表）：
/// - 状态控制：识别/录入/录制 三组开关，按钮文案随下位机当前状态翻转
/// - 页面跳转：设置/录入/融合/录像页
/// - 阈值调节：检测阈值(conf)/识别阈值(recognize)，默认 0.25 / 0.72（同 config.py）
/// - 设备开关：HTTP推流/RTSP推流/音频/LED/语音识别/自动录制
/// - 危险操作：清空人脸库/清空录像/退出程序（二次确认）
///
/// 通过 [command] / [statusPoll] 参数注入服务（Dialog 不在 AppServicesScope
/// 子树下，不能用 AppServices.of）。
class FaceDashboard extends StatefulWidget {
  final CommandService command;
  final StatusPollService statusPoll;

  const FaceDashboard({
    super.key,
    required this.command,
    required this.statusPoll,
  });

  @override
  State<FaceDashboard> createState() => _FaceDashboardState();
}

class _FaceDashboardState extends State<FaceDashboard> {
  double _conf = 0.25;
  double _recognize = 0.72;

  Future<void> _send(Map<String, dynamic> payload, String label) async {
    final res = await widget.command.send(payload);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label: ${res.message}'),
        backgroundColor: res.ok ? AppColors.green : AppColors.red,
        duration: const Duration(seconds: 2),
      ),
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () { Navigator.pop(ctx); doIt(); },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ValueListenableBuilder(
                  valueListenable: widget.statusPoll.status,
                  builder: (_, status, _) {
                    final state = status?.state ?? '';
                    final recognizing = state.contains('识别');
                    final enrolling = state.contains('录入');
                    final recording = state.contains('录制') || (status?.recording == true);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _section('状态控制', Icons.play_circle_outline, [
                          _stateBtn(
                            active: recognizing,
                            activeLabel: '停止识别',
                            idleLabel: '开始识别',
                            onCmd: Cmd.startRecognize,
                            offCmd: Cmd.stopRecognize,
                          ),
                          _stateBtn(
                            active: enrolling,
                            activeLabel: '停止录入',
                            idleLabel: '开始录入',
                            onCmd: Cmd.startEnroll,
                            offCmd: Cmd.stopEnroll,
                          ),
                          _stateBtn(
                            active: recording,
                            activeLabel: '停止录制',
                            idleLabel: '开始录制',
                            onCmd: Cmd.startRecord,
                            offCmd: Cmd.stopRecord,
                          ),
                        ]),
                        _section('即时动作', Icons.flash_on, [
                          _miniBtn('录入人脸', Icons.face, () => _send(Cmd.enrollFace, '录入人脸')),
                          _miniBtn('回主页', Icons.home, () => _send(Cmd.goHome, '回主页')),
                        ]),
                        _section('页面跳转', Icons.layers_outlined, [
                          _miniBtn('设置页', Icons.settings, () => _send(Cmd.goSettings, '去设置页')),
                          _miniBtn('录入页', Icons.person_add, () => _send(Cmd.goEnrollPage, '去录入页')),
                          _miniBtn('融合播放', Icons.video_call, () => _send(Cmd.fusionPage, '融合播放页')),
                          _miniBtn('录像列表', Icons.video_library, () => _send(Cmd.recordingsPage, '录像列表页')),
                        ]),
                        _thresholdSection(),
                        _switchesSection(),
                        _dangerSection(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.dashboard, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          const Text('人脸识别控制台',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(icon, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(title,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 0.5)),
              ],
            ),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }

  /// 状态切换按钮：active 时显示"停止"+危险色，下发 offCmd；否则显示"开始"+主色，下发 onCmd。
  Widget _stateBtn({
    required bool active,
    required String activeLabel,
    required String idleLabel,
    required Map<String, dynamic> onCmd,
    required Map<String, dynamic> offCmd,
  }) {
    final fg = active ? AppColors.red : AppColors.accent;
    final bg = active ? AppColors.redDim : AppColors.accentDim;
    return _Btn(
      label: active ? activeLabel : idleLabel,
      icon: active ? Icons.stop : Icons.play_arrow,
      fg: fg,
      bg: bg,
      onTap: () => _send(active ? offCmd : onCmd, active ? activeLabel : idleLabel),
    );
  }

  Widget _miniBtn(String label, IconData icon, VoidCallback onTap) {
    return _Btn(
      label: label,
      icon: icon,
      fg: AppColors.textPrimary,
      bg: AppColors.bgHover,
      onTap: onTap,
    );
  }

  Widget _thresholdSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              const Icon(Icons.tune, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              const Text('阈值调节',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 0.5)),
              const Spacer(),
              Text('下位机默认 0.25 / 0.72',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ]),
          ),
          _thresholdRow('检测阈值 conf', _conf, (v) => setState(() => _conf = v),
              (v) => _send(Cmd.confThreshold(v), '检测阈值=$v')),
          _thresholdRow('识别阈值 recognize', _recognize, (v) => setState(() => _recognize = v),
              (v) => _send(Cmd.recognizeThreshold(v), '识别阈值=$v')),
        ],
      ),
    );
  }

  Widget _thresholdRow(String label, double value, ValueChanged<double> onChanged, ValueChanged<double> onChangeEnd) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          Expanded(
            child: Slider(
              min: 0.10,
              max: 0.90,
              divisions: 80,
              value: value,
              label: value.toStringAsFixed(2),
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(value.toStringAsFixed(2),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontFamily: 'Consolas')),
          ),
        ],
      ),
    );
  }

  Widget _switchesSection() {
    final cmd = widget.command;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              const Icon(Icons.toggle_on, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              const Text('设备开关',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 0.5)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                SwitchRow(label: 'HTTP 推流', onCmd: Cmd.streamOn, offCmd: Cmd.streamOff, command: cmd),
                SwitchRow(label: 'RTSP 推流', onCmd: Cmd.rtspOn, offCmd: Cmd.rtspOff, command: cmd),
                SwitchRow(label: '音频提示', onCmd: Cmd.audioOn, offCmd: Cmd.audioOff, command: cmd),
                SwitchRow(label: 'LED 指示', onCmd: Cmd.ledOn, offCmd: Cmd.ledOff, command: cmd),
                SwitchRow(label: '语音识别', onCmd: Cmd.voiceOn, offCmd: Cmd.voiceOff, command: cmd),
                SwitchRow(label: '自动录制', onCmd: Cmd.autoRecordOn, offCmd: Cmd.autoRecordOff, command: cmd),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dangerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            const Icon(Icons.warning_amber, size: 14, color: AppColors.red),
            const SizedBox(width: 6),
            const Text('危险操作',
                style: TextStyle(color: AppColors.red, fontSize: 12, letterSpacing: 0.5)),
          ]),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Btn(
            label: '清空人脸库',
            icon: Icons.delete_forever,
            fg: AppColors.red,
            bg: AppColors.redDim,
            onTap: () => _confirm('清空人脸库', () => _send(Cmd.clearFaces, '清空人脸库')),
          ),
          _Btn(
            label: '清空录像',
            icon: Icons.delete_sweep,
            fg: AppColors.red,
            bg: AppColors.redDim,
            onTap: () => _confirm('清空录像', () => _send(Cmd.clearRecordings, '清空录像')),
          ),
          _Btn(
            label: '退出下位程序',
            icon: Icons.power_settings_new,
            fg: AppColors.red,
            bg: AppColors.redDim,
            onTap: () => _confirm('退出下位程序', () => _send(Cmd.exitApp, '退出下位程序')),
          ),
        ]),
      ],
    );
  }
}

/// 仪表盘内的小按钮：图标+文字，主色/危险色变体。
class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.icon, required this.fg, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: fg),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
