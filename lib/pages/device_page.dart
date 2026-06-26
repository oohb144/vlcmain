import 'package:flutter/material.dart';

import '../shell/app_services.dart';
import '../shell/cmd_constants.dart';
import '../theme/app_colors.dart';
import '../widgets/collapse_panel.dart';
import '../widgets/device_topology.dart';
import '../widgets/status_dot.dart';

/// 设备管理页：设备拓扑 + K230/STM32/网络折叠面板。
///
/// K230 面板里能下发的项（阈值、推流/音频/LED/语音/自动录制开关）复用
/// [Cmd] + [CommandService]；其余静态展示。
class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  double _confThreshold = 0.65;
  double _recognizeThreshold = 0.72;
  String _resolution = '640 x 480';
  String _frameRate = '30 fps';
  bool _mirrorH = false;
  bool _mirrorV = false;

  @override
  Widget build(BuildContext context) {
    final svc = AppServices.of(context);
    final rtspUrl = svc.config.rtspUrl;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 拓扑图
            _Card(
              title: '设备拓扑',
              icon: Icons.hub_outlined,
              trailing: _Tag('全部在线', AppColors.greenDim, AppColors.green),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DeviceTopology(nodes: [
                    const TopoNode(icon: Icons.camera_alt, name: 'K230 摄像头'),
                    const TopoNode(icon: Icons.mic, name: 'K230 麦克风'),
                    const TopoNode(icon: Icons.memory, name: 'STM32 主控', isCenter: true),
                    const TopoNode(icon: Icons.sensor_door, name: '门锁'),
                    const TopoNode(icon: Icons.fingerprint, name: '指纹', compact: true),
                    const TopoNode(icon: Icons.nfc, name: 'NFC', compact: true),
                    const TopoNode(icon: Icons.dialpad, name: '键盘', compact: true),
                    const TopoNode(icon: Icons.screen_share, name: '显示屏', compact: true),
                  ]),
                  const SizedBox(height: 12),
                  const _LinkageRules(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // K230 配置
            CollapsePanel(
              header: Row(children: [
                _SectionIcon(Icons.camera_alt),
                const SizedBox(width: 8),
                const Text('K230 视觉模块'),
              ]),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const StatusDot(state: StatusDotState.online, size: 6),
                  const SizedBox(width: 4),
                  _Tag('在线', AppColors.greenDim, AppColors.green),
                  const SizedBox(width: 8),
                  Text(_hostOf(rtspUrl),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _formRow(
                    '分辨率',
                    DropdownButton<String>(
                      value: _resolution,
                      underline: const SizedBox(),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                      dropdownColor: AppColors.bgCard,
                      items: const ['640 x 480', '320 x 240'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _resolution = v ?? _resolution),
                    ),
                  ),
                  _formRow(
                    '帧率',
                    DropdownButton<String>(
                      value: _frameRate,
                      underline: const SizedBox(),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                      dropdownColor: AppColors.bgCard,
                      items: const ['30 fps', '15 fps'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _frameRate = v ?? _frameRate),
                    ),
                  ),
                  _formRow(
                    '人脸检测阈值',
                    _ThresholdSlider(
                      value: _confThreshold,
                      onChanged: (v) => setState(() => _confThreshold = v),
                      onChangeEnd: (v) => _send(svc, Cmd.confThreshold(v), '检测阈值=$v'),
                    ),
                  ),
                  _formRow(
                    '识别阈值',
                    _ThresholdSlider(
                      value: _recognizeThreshold,
                      onChanged: (v) => setState(() => _recognizeThreshold = v),
                      onChangeEnd: (v) => _send(svc, Cmd.recognizeThreshold(v), '识别阈值=$v'),
                    ),
                  ),
                  _formRow('RTSP 地址',
                      Text(rtspUrl, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontFamily: 'Consolas'))),
                  _formRow(
                    '镜像 / 翻转',
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MiniToggle(label: '水平', value: _mirrorH, onChanged: (v) => setState(() => _mirrorH = v)),
                        const SizedBox(width: 12),
                        _MiniToggle(label: '垂直', value: _mirrorV, onChanged: (v) => setState(() => _mirrorV = v)),
                      ],
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 16),
                  _SwitchRow(label: 'HTTP 推流', onCmd: Cmd.streamOn, offCmd: Cmd.streamOff),
                  _SwitchRow(label: 'RTSP 推流', onCmd: Cmd.rtspOn, offCmd: Cmd.rtspOff),
                  _SwitchRow(label: '音频提示', onCmd: Cmd.audioOn, offCmd: Cmd.audioOff),
                  _SwitchRow(label: 'LED 指示', onCmd: Cmd.ledOn, offCmd: Cmd.ledOff),
                  _SwitchRow(label: '语音识别', onCmd: Cmd.voiceOn, offCmd: Cmd.voiceOff),
                  _SwitchRow(label: '自动录制', onCmd: Cmd.autoRecordOn, offCmd: Cmd.autoRecordOff),
                ],
              ),
            ),
            // STM32 配置
            CollapsePanel(
              header: Row(children: [
                _SectionIcon(Icons.memory),
                const SizedBox(width: 8),
                const Text('STM32 主控'),
              ]),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const StatusDot(state: StatusDotState.online, size: 6),
                  const SizedBox(width: 4),
                  _Tag('在线', AppColors.greenDim, AppColors.green),
                  const SizedBox(width: 8),
                  const Text('UART1 115200', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _formRow('固件版本', const Text('v2.1.3')),
                  _formRow('串口波特率', const Text('115200')),
                  _formRow('通信协议', const Text('0x55 0xAA ... 0xFA (二进制)')),
                  _formRow('外设端口', const Text('GPIO x12 | UART x3 | SPI x1 | I2C x1')),
                  _formRow(
                    '操作',
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MiniBtn('测试通信', () {}),
                        const SizedBox(width: 8),
                        _MiniBtn.danger('重启 STM32', () {}),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 网络配置
            CollapsePanel(
              header: Row(children: [
                _SectionIcon(Icons.wifi, color: AppColors.green),
                const SizedBox(width: 8),
                const Text('网络通信'),
              ]),
              trailing: _Tag('WiFi 已连接', AppColors.greenDim, AppColors.green),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _formRow('WiFi SSID', const Text('Lab-5G')),
                  _formRow('IP 地址', Text(_hostOf(rtspUrl),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontFamily: 'Consolas'))),
                  _formRow('信号强度', const Text('-42 dBm (强)')),
                  _formRow('MQTT 服务器', Text('${_hostOf(rtspUrl)}:1883',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontFamily: 'Consolas'))),
                  _formRow('MQTT 状态', _Tag('已连接', AppColors.greenDim, AppColors.green)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _hostOf(String url) {
    final m = RegExp(r'://([^/]+)').firstMatch(url);
    return m?.group(1) ?? url;
  }

  Future<void> _send(AppServices svc, Map<String, dynamic> payload, String label) async {
    final res = await svc.command.send(payload);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label: ${res.message}'),
        backgroundColor: res.ok ? AppColors.green : AppColors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _formRow(String label, Widget value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Flexible(child: value),
        ],
      ),
    );
  }
}

/// 阈值滑块：0.10–0.90，拖动结束下发。
class _ThresholdSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  const _ThresholdSlider({required this.value, required this.onChanged, required this.onChangeEnd});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 150,
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
        Text(value.toStringAsFixed(2),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontFamily: 'Consolas')),
      ],
    );
  }
}

/// 设备开关行：左侧标签 + 右侧 Switch，切换即下发对应 on/off 指令。
class _SwitchRow extends StatefulWidget {
  final String label;
  final Map<String, dynamic> onCmd;
  final Map<String, dynamic> offCmd;
  const _SwitchRow({required this.label, required this.onCmd, required this.offCmd});

  @override
  State<_SwitchRow> createState() => _SwitchRowState();
}

class _SwitchRowState extends State<_SwitchRow> {
  bool _on = false;
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    final svc = AppServices.of(context);
    final want = !_on;
    final res = await svc.command.send(want ? widget.onCmd : widget.offCmd);
    if (!mounted) return;
    setState(() {
      if (res.ok) _on = want;
      _busy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.label}: ${res.message}'),
        backgroundColor: res.ok ? AppColors.green : AppColors.red,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(widget.label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          Switch(value: _on, onChanged: _busy ? null : (_) => _toggle()),
        ],
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _MiniToggle({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(width: 6),
        SizedBox(
          width: 36,
          height: 20,
          child: Switch(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final Widget child;
  const _Card({required this.title, required this.icon, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _SectionIcon(icon),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// 分区标题色块图标（仿控制台风格）。
class _SectionIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  const _SectionIcon(this.icon, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 14, color: c),
    );
  }
}

/// 联动规则可视化：开门组（人脸/指纹/NFC/密码 → 门锁）+ 报警组（陌生人 → 报警+录像）。
class _LinkageRules extends StatelessWidget {
  const _LinkageRules();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgHover,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _SectionIcon(Icons.account_tree_outlined, color: AppColors.accent),
              const SizedBox(width: 8),
              const Text('联动规则',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          // 开门组
          _ruleRow(
            inputs: const [
              (Icons.face, '人脸'),
              (Icons.fingerprint, '指纹'),
              (Icons.nfc, 'NFC'),
              (Icons.dialpad, '密码'),
            ],
            outputIcon: Icons.lock_open,
            outputLabel: '开门',
            color: AppColors.green,
          ),
          const SizedBox(height: 8),
          // 报警组
          _ruleRow(
            inputs: const [(Icons.person_off, '陌生人')],
            outputIcon: Icons.warning,
            outputLabel: '报警 + 录像',
            color: AppColors.red,
          ),
        ],
      ),
    );
  }

  Widget _ruleRow({
    required List<(IconData, String)> inputs,
    required IconData outputIcon,
    required String outputLabel,
    required Color color,
  }) {
    return Row(
      children: [
        ...inputs.map((e) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _chip(e.$1, e.$2, AppColors.textSecondary),
            )),
        Icon(Icons.arrow_right_alt, size: 18, color: color),
        const SizedBox(width: 6),
        _chip(outputIcon, outputLabel, color, filled: true),
      ],
    );
  }

  Widget _chip(IconData icon, String label, Color color, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.18) : AppColors.bgCard,
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Tag(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _MiniBtn(this.label, this.onTap, {this.danger = false});

  factory _MiniBtn.danger(String label, VoidCallback onTap) => _MiniBtn(label, onTap, danger: true);

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.red : AppColors.textPrimary;
    final bg = danger ? AppColors.redDim : AppColors.bgHover;
    final border = danger ? AppColors.red : AppColors.border;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border),
          ),
          child: Text(label, style: TextStyle(color: fg, fontSize: 11)),
        ),
      ),
    );
  }
}
