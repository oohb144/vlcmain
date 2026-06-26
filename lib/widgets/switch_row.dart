import 'package:flutter/material.dart';

import '../services/command_service.dart';
import '../theme/app_colors.dart';

/// 设备开关行：左侧标签 + 右侧 Switch，切换即下发对应 on/off 指令。
///
/// 指令 payload 与 K230 端 POST /command 协议对齐（见 Cmd 常量）。
/// 供设备管理页、设置页调试区复用。
class SwitchRow extends StatefulWidget {
  final String label;
  final Map<String, dynamic> onCmd;
  final Map<String, dynamic> offCmd;
  final CommandService command;
  /// 命令下发后回调（label + ok + message），供上层展示当前状态指示。
  final void Function(String label, bool ok, String message)? onResult;

  const SwitchRow({
    super.key,
    required this.label,
    required this.onCmd,
    required this.offCmd,
    required this.command,
    this.onResult,
  });

  @override
  State<SwitchRow> createState() => _SwitchRowState();
}

class _SwitchRowState extends State<SwitchRow> {
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
    widget.onResult?.call(widget.label, res.ok, res.message);
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
          Expanded(
            child: Text(widget.label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          Switch(value: _on, onChanged: _busy ? null : (_) => _toggle()),
        ],
      ),
    );
  }
}
